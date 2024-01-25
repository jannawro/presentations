# Input variable definitions
variable "dynamodb_table" {
  description = "name of the ddb table"
  type        = string
  default     = "Movies"
}

variable "lambda_log_retention" {
  description = "lambda log retention in days"
  type        = number
  default     = 7
}

variable "region" {
  type        = string
  description = "AWS Region where deploying resources"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for Batch VPC"
  default     = "10.0.0.0/16"
}
