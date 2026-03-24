variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "snowflake_role_arn" {
  description = "ARN of the Snowflake role in the partner's AWS account that needs cross-account S3 access"
  type        = string
  default     = "arn:aws:iam::517025778241:role/Snowflake-S3Role"
}

variable "exports_bucket_name" {
  description = "S3 bucket name for Snowflake CSV exports"
  type        = string
  default     = "scout-snowflake-exports"
}
