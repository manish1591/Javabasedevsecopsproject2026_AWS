echo 'terraform {' > versions.tf
echo '  required_version = ">= 1.5.0"' >> versions.tf
echo '  required_providers {' >> versions.tf
echo '    aws = {' >> versions.tf
echo '      source  = "hashicorp/aws"' >> versions.tf
echo '      version = "~> 5.0"' >> versions.tf
echo '    }' >> versions.tf
echo '  }' >> versions.tf
echo '}' >> versions.tf
echo '' >> versions.tf
echo 'provider "aws" {' >> versions.tf
echo '  region = var.aws_region' >> versions.tf
echo '}' >> versions.tf
