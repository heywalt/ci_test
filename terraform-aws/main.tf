# =============================================================================
# Scout AWS Infrastructure
# =============================================================================
#
# Prerequisites:
# 1. Run bootstrap/main.tf to create S3 bucket and DynamoDB table for state
# 2. Run github-oidc/main.tf to create GitHub Actions OIDC provider and IAM role
# 3. Then this config can be run via GitHub Actions
#
# This configuration manages an S3 bucket that receives CSV exports from a
# partner company via their Snowflake instance. The partner's Snowflake role
# is granted cross-account access to write and verify files in the bucket.

# =============================================================================
# S3 Bucket: Snowflake CSV Exports
# =============================================================================

# =============================================================================
# If you need to trigger this without making any changes, change this line: 001
# =============================================================================

resource "aws_s3_bucket" "snowflake_exports" {
  bucket = var.exports_bucket_name

  tags = {
    Name = var.exports_bucket_name
  }
}

resource "aws_s3_bucket_versioning" "snowflake_exports" {
  bucket = aws_s3_bucket.snowflake_exports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "snowflake_exports" {
  bucket = aws_s3_bucket.snowflake_exports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "snowflake_exports" {
  bucket = aws_s3_bucket.snowflake_exports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "snowflake_exports" {
  bucket = aws_s3_bucket.snowflake_exports.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# =============================================================================
# Cross-Account Bucket Policy: Snowflake Access
# =============================================================================
#
# Grants the partner's Snowflake role the permissions needed for a Snowflake
# external stage:
#   - GetBucketLocation: Required by Snowflake storage integration setup
#   - ListBucket: Required for Snowflake's LIST @stage and file verification
#   - GetObject/GetObjectVersion: Read files and specific versions
#   - PutObject: Write CSV exports to the bucket
#   - AbortMultipartUpload/ListMultipartUploadParts: Clean up failed uploads

resource "aws_s3_bucket_policy" "snowflake_cross_account" {
  bucket = aws_s3_bucket.snowflake_exports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SnowflakeBucketAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.snowflake_role_arn
        }
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.snowflake_exports.arn
      },
      {
        Sid    = "SnowflakeObjectAccess"
        Effect = "Allow"
        Principal = {
          AWS = var.snowflake_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.snowflake_exports.arn}/*"
      }
    ]
  })
}
