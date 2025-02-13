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