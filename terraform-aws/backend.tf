# Backend configuration
# Values are passed via -backend-config flags or backend.hcl file
# Example: terraform init -backend-config=backend.hcl
#
# Create backend.hcl with:
#   bucket         = "amby-ai-terraform-state-bucket"
#   key            = "walt-ui/terraform.tfstate"
#   region         = "us-east-1"
#   encrypt        = true
#   dynamodb_table = "amby-ai-terraform-locks"

terraform {
  backend "s3" {}
}
