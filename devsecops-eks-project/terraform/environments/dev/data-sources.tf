cat > /d/Devsecopsrepos/devsecops-eks-project/terraform/environments/dev/data-sources.tf << 'EOF'
# Get AWS account ID
data "aws_caller_identity" "current" {}

# Get AWS region
data "aws_region" "current" {}

# Get available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Get EKS cluster authentication (for kubectl)
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
  depends_on = [aws_eks_cluster.main]
}

# Output account info
output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  value = data.aws_caller_identity.current.arn
}
EOF
