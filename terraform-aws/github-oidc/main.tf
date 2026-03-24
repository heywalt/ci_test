# GitHub Actions OIDC Configuration
# Creates OIDC provider and IAM role for GitHub Actions to deploy infrastructure
#
# Run this ONCE manually after bootstrap to set up GitHub Actions authentication.
# State is stored in the S3 bucket created by bootstrap.
#
# Prerequisites:
# 1. Run bootstrap/main.tf first to create S3 bucket and DynamoDB table
#
# Usage:
#   cd terraform-aws/github-oidc
#
#   terraform init \
#     -backend-config="bucket=amby-ai-terraform-state-bucket" \
#     -backend-config="key=walt-ui/github-oidc/terraform.tfstate" \
#     -backend-config="region=us-east-1" \
#     -backend-config="encrypt=true" \
#     -backend-config="dynamodb_table=amby-ai-terraform-locks"
#
#   terraform apply \
#     -var="github_org=heywalt" \
#     -var="aws_account_id=YOUR_ACCOUNT_ID"

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "scout"
      ManagedBy = "terraform"
      Component = "github-oidc"
    }
  }
}

provider "github" {
  owner = var.github_org
}

# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "walt_ui"
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
# GitHub Actions OIDC Provider
# =============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    Name = "github-actions"
  }
}

# =============================================================================
# IAM Role for GitHub Actions
# =============================================================================

resource "aws_iam_role" "github_actions" {
  name = "scout-github-actions-terraform"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
              "repo:${var.github_org}/${var.github_repo}:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "scout-github-actions-terraform"
  }
}

# =============================================================================
# IAM Policy for Terraform Operations
# Scoped to S3 and IAM — this project only manages S3 buckets and bucket
# policies in AWS. No EC2, RDS, ALB, etc.
# =============================================================================

resource "aws_iam_role_policy" "terraform_permissions" {
  name = "terraform-permissions"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # S3 Permissions (Terraform State)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*"
        ]
      },
      # DynamoDB Permissions (Terraform Lock)
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.lock_table_name}"
      },
      # S3 Permissions (Bucket management for scout-* buckets)
      {
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:GetBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketNotification",
          "s3:GetBucketNotification",
          "s3:PutBucketCORS",
          "s3:GetBucketCORS",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketAcl",
          "s3:PutBucketAcl",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetBucketOwnershipControls",
          "s3:PutBucketOwnershipControls",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutBucketTagging",
          "s3:GetBucketTagging",
          "s3:GetBucketWebsite",
          "s3:PutBucketWebsite",
          "s3:DeleteBucketWebsite",
          "s3:GetBucketLogging",
          "s3:PutBucketLogging",
          "s3:GetLifecycleConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:GetAccelerateConfiguration",
          "s3:PutAccelerateConfiguration",
          "s3:GetReplicationConfiguration",
          "s3:PutReplicationConfiguration",
          "s3:GetBucketRequestPayment",
          "s3:PutBucketRequestPayment",
          "s3:GetObjectLockConfiguration",
          "s3:PutObjectLockConfiguration",
          "s3:GetBucketObjectLockConfiguration",
          "s3:PutBucketObjectLockConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::scout-*",
          "arn:aws:s3:::scout-*/*"
        ]
      },
      # IAM Permissions (for managing bucket policies and any IAM resources)
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole"
        ]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/scout-*"
      }
    ]
  })
}

# =============================================================================
# GitHub Repository Secrets
# =============================================================================

resource "github_actions_secret" "aws_account_id" {
  repository      = var.github_repo
  secret_name     = "AWS_ACCOUNT_ID"
  plaintext_value = var.aws_account_id
}

# =============================================================================
# Outputs
# =============================================================================

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions - use this in your workflow"
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "GitHub OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}
