cat > /d/Devsecopsrepos/devsecops-eks-project/terraform/environments/dev/outputs.tf << 'EOF'
# ============================================
# NETWORK OUTPUTS
# ============================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

# ============================================
# EKS OUTPUTS
# ============================================
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster API server"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "cluster_certificate_authority" {
  description = "Certificate authority data for EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_group_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.main.node_group_name
}

# ============================================
# ECR OUTPUTS
# ============================================
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

# ============================================
# IAM OUTPUTS
# ============================================
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node IAM role"
  value       = aws_iam_role.eks_nodes.arn
}
EOF
