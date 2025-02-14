provider "aws" {
  region = "us-west-2"  # Update with your region
}

# Add provider for us-east-1 (required for WAF with CloudFront)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# Create an EC2 security group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = "vpc-052392afe48c5a6ac"  # Added VPC ID

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template for EC2 instances
resource "aws_launch_template" "web_template" {
  name = "web-template"
  instance_type = "t2.micro"
  image_id = "ami-0005ee01bca55ab66"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }
  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd python3 python3-pip
              pip3 install boto3
              systemctl start httpd
              systemctl enable httpd

              # Create a Python script to handle analytics
              cat > /var/www/html/analytics.py << 'END'
              import boto3
              import json
              import time
              from datetime import datetime, timedelta

              dynamodb = boto3.resource('dynamodb')
              table = dynamodb.Table('visitor-analytics')

              def record_visit(visitor_ip, path, user_agent):
                  timestamp = datetime.utcnow().isoformat()
                  expiration_time = int((datetime.utcnow() + timedelta(days=90)).timestamp())
                  
                  table.put_item(
                      Item={
                          'visitor_ip': visitor_ip,
                          'timestamp': timestamp,
                          'path': path,
                          'user_agent': user_agent,
                          'expiration_time': expiration_time
                      }
                  )
              END

              # Create basic index page
              echo "Welcome to Apache on EC2! idan king!!" > /var/www/html/index.html
              EOF
  )

  
  monitoring {
    enabled = true
  }
}

# Create an Auto Scaling Group with the Launch Template
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2
  max_size           = 3
  min_size           = 1
  target_group_arns  = [aws_lb_target_group.web_target_group.arn]
  vpc_zone_identifier = ["subnet-096a7c55adcfb1322"]

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }
}

# Create an Application Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = ["subnet-096a7c55adcfb1322", "subnet-03cc4e1accf07603e"]
  enable_deletion_protection = false
}

# Create a Target Group for the Load Balancer
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-052392afe48c5a6ac"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
  }
}

# Create a listener for the Load Balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# Create WAF Web ACL
resource "aws_wafv2_web_acl" "main" {
  provider    = aws.us-east-1
  name        = "main-web-acl"
  description = "WAF Web ACL with basic security rules"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "RateLimit"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRule"
      sampled_requests_enabled  = true
    }
  }

  rule {
    name     = "SQLInjectionRule"
    priority = 2

    statement {
      sqli_match_statement {
        field_to_match {
          query_string {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name               = "SQLInjectionRule"
      sampled_requests_enabled  = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name               = "MainWebACL"
    sampled_requests_enabled  = true
  }
}

# Create CloudFront distribution
resource "aws_cloudfront_distribution" "web_distribution" {
  enabled = true
  
  origin {
    domain_name = aws_lb.web_lb.dns_name
    origin_id   = "ALB"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "ALB"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin"]
      
      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  web_acl_id = aws_wafv2_web_acl.main.arn

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_100"
}

# Outputs
output "elb_url" {
  value = aws_lb.web_lb.dns_name
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.web_distribution.domain_name
}