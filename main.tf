terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }

  backend "s3" {
    bucket  = "max-terraform-state-kinesis-project"
    key     = "kinesis-project/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.region
}

# 1. Kinesis Data Stream (On-Demand)
resource "aws_kinesis_stream" "iot_stream" {
  name             = var.stream_name
  retention_period = var.retention_hours
  encryption_type  = "KMS"
  kms_key_id       = "alias/aws/kinesis" # Uses the default AWS-managed key for Kinesis

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  tags = {
    Project = var.project_tag
  }
}

resource "aws_kms_key" "sns_kms" {
  description         = "KMS key for SNS topic encryption"
  enable_key_rotation = true
}


# 2. SNS Topic & Email Subscription
resource "aws_sns_topic" "alert_topic" {
  name              = var.sns_topic_name
  display_name      = "IoT Sensor Temperature Alert"
  kms_master_key_id = aws_kms_key.sns_kms.arn
}


# 3. IAM Role for EventBridge Pipe
resource "aws_iam_role" "pipe_role" {
  name = "kds-to-sns-alert-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "pipes.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "pipe_policy" {
  role = aws_iam_role.pipe_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:ListShards"
        ]
        Effect   = "Allow"
        Resource = aws_kinesis_stream.iot_stream.arn
      },
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = aws_sns_topic.alert_topic.arn
      }
    ]
  })
}

# 4. EventBridge Pipe (Filter + Transform)
resource "aws_pipes_pipe" "iot_pipe" {
  name     = "kds-to-sns-alert"
  role_arn = aws_iam_role.pipe_role.arn
  source   = aws_kinesis_stream.iot_stream.arn
  target   = aws_sns_topic.alert_topic.arn

  source_parameters {
    kinesis_stream_parameters {
      starting_position = "LATEST"
      batch_size        = 1
    }

    filter_criteria {
      filter {
        pattern = jsonencode({
          data = {
            currentTemperature = [{ numeric = [">", 100] }]
            alert              = [{ "equals-ignore-case" = "ON" }]
          }
        })
      }
    }
  }

  target_parameters {
    input_template = <<EOT
WARNING:
Temperature threshold exceeded for IoT Sensor ID: <$.data.sensorId>
Current Device Temperature: <$.data.currentTemperature>
EOT
  }
}







