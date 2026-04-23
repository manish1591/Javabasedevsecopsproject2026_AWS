cat > backend.tf << 'EOF'
terraform {
  backend "s3" {
    bucket         = "devsecops-tfstate-438950222856"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
EOF
