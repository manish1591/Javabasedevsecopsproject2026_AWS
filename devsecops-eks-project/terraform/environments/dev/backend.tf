echo 'terraform {' > backend.tf
echo '  backend "s3" {' >> backend.tf
echo '    bucket         = "devsecops-tfstate-438950222856"' >> backend.tf
echo '    key            = "dev/terraform.tfstate"' >> backend.tf
echo '    region         = "us-east-1"' >> backend.tf
echo '    encrypt        = true' >> backend.tf
echo '    dynamodb_table = "terraform-locks"' >> backend.tf
echo '  }' >> backend.tf
echo '}' >> backend.tf
