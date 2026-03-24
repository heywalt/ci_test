# Bootstrap Configuration
# Creates the S3 bucket and DynamoDB table that store Terraform state for all
# Amby AI applications.
#
# First-time setup (bucket doesn't exist yet):
#   cd terraform-aws/bootstrap
#   terraform init
#   terraform apply
#
# Then migrate local state into the bucket it just created:
#   terraform init -backend-config=backend.hcl -migrate-state
#
# All subsequent runs use the remote backend automatically.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "amby-ai-terraform-state-bucket"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "amby-ai-terraform-locks"
}

# =============================================================================
# Terraform State Management
# =============================================================================

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = false
  }

  tags = {
    Name      = var.state_bucket_name
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = var.lock_table_name
    ManagedBy = "terraform-bootstrap"
  }
}

# Outputs
output "state_bucket_name" {
  description = "S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}
