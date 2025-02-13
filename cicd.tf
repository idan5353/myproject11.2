# S3 bucket for artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = "my-web-artifacts-bucket"
}

resource "aws_s3_bucket_versioning" "artifacts_versioning" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# IAM role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodeBuild
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Resource = ["*"]
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage"
        ]
      }
    ]
  })
}

# CodeBuild project
resource "aws_codebuild_project" "web_build" {
  name          = "web-build"
  description   = "Build web application"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  environment {
  compute_type                = "BUILD_GENERAL1_SMALL"
  image                       = "aws/codebuild/amazonlinux2-x86_64-standard:3.0" # Supports Node.js 18
  type                        = "LINUX_CONTAINER"
  image_pull_credentials_type = "CODEBUILD"
}



  source {
    type            = "GITHUB"
    location        = "https://github.com/idan5353/myproject11.2.git"
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }
}

# IAM role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for CodePipeline
resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject",
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
          "codedeploy:CreateDeployment",
          "codedeploy:GetDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:RegisterApplicationRevision",
          "codedeploy:GetDeploymentConfig",
          "codestar-connections:UseConnection" # Added permission
        ]
        Resource = "*"
      }
    ]
  })
}

# CodePipeline
resource "aws_codepipeline" "web_pipeline" {
  name     = "web-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = "arn:aws:codeconnections:us-west-2:851725642392:connection/99806b32-77b9-4b63-996b-47d44756dab1"
        FullRepositoryId = "idan5353/myproject11.2"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.web_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeploy"
      input_artifacts = ["source_output"]
      version         = "1"

      configuration = {
        ApplicationName     = "myapp"
        DeploymentGroupName = "your-deployment-group"
      }
    }
  }
}
