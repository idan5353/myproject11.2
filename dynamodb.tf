# DynamoDB table for visitor analytics
resource "aws_dynamodb_table" "visitor_analytics" {
  name           = "visitor-analytics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "visitor_ip"
  range_key      = "timestamp"

  attribute {
    name = "visitor_ip"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Environment = "production"
    Project     = "web-analytics"
  }
}

# Add DynamoDB permissions to the EC2 instance role
resource "aws_iam_role" "ec2_role" {
  name = "ec2-dynamodb-role"

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
}

resource "aws_iam_role_policy" "dynamodb_policy" {
  name = "dynamodb-access-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.visitor_analytics.arn
        ]
      }
    ]
  })
}

# Create an instance profile for the EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-dynamodb-profile"
  role = aws_iam_role.ec2_role.name
}

# Update the launch template to use the IAM instance profile
resource "aws_launch_template" "web_template" {
  # ... (keep your existing configuration)

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
              echo "Welcome to Apache on EC2!" > /var/www/html/index.html
              EOF
  )
}