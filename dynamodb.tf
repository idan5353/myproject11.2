# DynamoDB Table for Visitor Analytics
resource "aws_dynamodb_table" "visitor_analytics" {
  name         = "visitor-analytics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "visitor_ip"
  range_key    = "timestamp"

  attribute {
    name = "visitor_ip"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "path"
    type = "S"
  }

  global_secondary_index {
    name               = "PathTimeIndex"
    hash_key           = "path"
    range_key          = "timestamp"
    projection_type    = "ALL"
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

# Kinesis Stream for CloudFront Logs
resource "aws_kinesis_stream" "cloudfront_logs" {
  name             = "cloudfront-logs"
  shard_count      = 1
  retention_period = 24

  tags = {
    Environment = "production"
    Project     = "web-analytics"
  }
}

# IAM Role for CloudFront to Kinesis
resource "aws_iam_role" "cloudfront_kinesis_role" {
  name = "cloudfront-kinesis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for CloudFront to Write to Kinesis
resource "aws_iam_role_policy" "cloudfront_kinesis_policy" {
  name = "cloudfront-kinesis-policy"
  role = aws_iam_role.cloudfront_kinesis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = [aws_kinesis_stream.cloudfront_logs.arn]
      }
    ]
  })
}

# Lambda Function for Processing Logs
resource "aws_lambda_function" "process_logs" {
  filename      = "process_logs.zip"  # Ensure you have the ZIP file created
  function_name = "process-cloudfront-logs"
  role          = aws_iam_role.lambda_role.arn
  handler       = "process_logs.handler"
  runtime       = "nodejs18.x"
  timeout       = 60
  source_code_hash = filebase64sha256("process_logs.zip")

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.visitor_analytics.name
    }
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-cloudfront-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to Access DynamoDB and Kinesis
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-cloudfront-logs-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:UpdateItem" # ADDED
        ]
        Resource = [aws_dynamodb_table.visitor_analytics.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListShards"
        ]
        Resource = [aws_kinesis_stream.cloudfront_logs.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      }
    ]
  })
}

# CloudFront Real-Time Log Configuration
resource "aws_cloudfront_realtime_log_config" "analytics" {
  name          = "web-analytics"
  sampling_rate = 100
  fields        = ["timestamp", "c-ip", "cs-method", "cs-uri-stem", "sc-status", "cs-user-agent", "cs-referer"]

  endpoint {
    stream_type = "Kinesis"
    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_kinesis_role.arn
      stream_arn = aws_kinesis_stream.cloudfront_logs.arn
    }
  }
}

# Lambda Event Source Mapping for Kinesis
resource "aws_lambda_event_source_mapping" "kinesis_mapping" {
  event_source_arn  = aws_kinesis_stream.cloudfront_logs.arn
  function_name     = aws_lambda_function.process_logs.arn
  starting_position = "LATEST"
  batch_size        = 100
}