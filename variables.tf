variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "stream_name" {
  description = "Name of the Kinesis Data Stream"
  type        = string
  default     = "iot-sensor-stream"
}

variable "retention_hours" {
  description = "Data retention period in hours"
  type        = number
  default     = 24
}

variable "project_tag" {
  description = "Project tag for resources"
  type        = string
  default     = "IoT-Kinesis-Project"
}

variable "sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = "iot-temperature-alerts"
}