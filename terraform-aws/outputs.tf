output "exports_bucket_name" {
  description = "S3 bucket name for Snowflake CSV exports"
  value       = aws_s3_bucket.snowflake_exports.id
}

output "exports_bucket_arn" {
  description = "S3 bucket ARN for Snowflake CSV exports"
  value       = aws_s3_bucket.snowflake_exports.arn
}

output "exports_bucket_region" {
  description = "S3 bucket region"
  value       = aws_s3_bucket.snowflake_exports.region
}
