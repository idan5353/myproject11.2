terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.56.0" # Minimum version with the resource
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

# EC2 IAM Role and policies remain the same...
# (Keep your existing IAM configuration unchanged)

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH traffic"
  vpc_id      = "vpc-052392afe48c5a6ac"

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

  tags = {
    Name = "web-sg"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = "production"
  }
}


resource "aws_iam_policy" "ec2_codedeploy_policy" {
  name        = "ec2-codedeploy-policy"
  description = "Policy that allows EC2 instances to interact with CodeDeploy and S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetApplicationRevision",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the Custom Policy to the EC2 Role
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_codedeploy_policy.arn
}

# Attach the AmazonEC2RoleforAWSCodeDeploy Policy to the EC2 Role
resource "aws_iam_role_policy_attachment" "ec2_codedeploy_service_role" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_codedeploy_profile" {
  name = "ec2-codedeploy-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}


# Launch Template
resource "aws_launch_template" "web_template" {
  name                   = "web-template"
  description           = "Version ${timestamp()}"
  instance_type          = "t2.micro"
  image_id               = "ami-0005ee01bca55ab66"
  vpc_security_group_ids = [aws_security_group.web_sg.id]


  tags = {
    Name = "web-server"
  }
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_codedeploy_profile.name
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Update the system and install Apache
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd

              # Create the index page from file content
              cat > /var/www/html/index.html << 'END'
              ${file("${path.module}/index.html")}
              END

              # Create a health check page
              cat > /var/www/html/health.html << 'END'
              OK
              END

              # Install the CodeDeploy agent
              sudo yum install -y ruby
              sudo yum install -y wget
              cd /home/ec2-user
              wget https://aws-codedeploy-us-west-2.s3.us-west-2.amazonaws.com/latest/install
              chmod +x ./install
              sudo ./install auto
              sudo service codedeploy-agent start
              
              # Install Node Exporter for Prometheus monitoring
              cd /tmp
              wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
              tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
              sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
              
              # Create Node Exporter systemd service
              cat > /etc/systemd/system/node_exporter.service << 'END'
              [Unit]
              Description=Node Exporter
              Wants=network-online.target
              After=network-online.target
              
              [Service]
              User=root
              Group=root
              Type=simple
              ExecStart=/usr/local/bin/node_exporter
              
              [Install]
              WantedBy=multi-user.target
              END
              
              # Start Node Exporter
              systemctl daemon-reload
              systemctl start node_exporter
              systemctl enable node_exporter
              EOF
)
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-server"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

# Target Group
resource "aws_lb_target_group" "web_target_group" {
  name                 = "web-target-group"
  port                 = 80
  protocol            = "HTTP"
  vpc_id              = "vpc-052392afe48c5a6ac"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    timeout             = 5
    path                = "/health.html"
    port                = "traffic-port"
    protocol            = "HTTP"
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity    = 2
  max_size           = 3
  min_size           = 1
  target_group_arns  = [aws_lb_target_group.web_target_group.arn]
  vpc_zone_identifier = ["subnet-096a7c55adcfb1322"]
  health_check_type  = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web_template.id
    version = "$Latest"
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup       = 300
    }

  }

  tag {
    key                 = "Name"
    value              = "web-server"
    propagate_at_launch = true
  }

  # If you're using CodeDeploy, add this tag
  tag {
    key                 = "Environment"
    value              = "Production"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
  # Auto Scaling Group attachment to ALB
resource "aws_autoscaling_attachment" "web_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  lb_target_group_arn   = aws_lb_target_group.web_target_group.arn
}


# Application Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = ["subnet-096a7c55adcfb1322", "subnet-03cc4e1accf07603e"]
  
  enable_deletion_protection = false
  idle_timeout       = 60

  tags = {
    Name = "web-lb"
  }
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

  



# Outputs
output "alb_dns_name" {
  value = aws_lb.web_lb.dns_name
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.web_distribution.domain_name
}