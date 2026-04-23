cat > /d/Devsecopsrepos/devsecops-eks-project/terraform/environments/dev/main.tf << 'EOF'
# ============================================
# VPC & NETWORKING
# ============================================

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc-${var.environment}"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw-${var.environment}"
  }
}

# Create Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                           = "${var.project_name}-public-${var.environment}-${count.index + 1}"
    "kubernetes.io/role/elb"       = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# Create Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                                 = "${var.project_name}-private-${var.environment}-${count.index + 1}"
    "kubernetes.io/role/internal-elb"    = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${var.environment}"
  }
}

# NAT Gateway (for private subnets to access internet)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat-${var.environment}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt-${var.environment}"
  }
}

# Private Route Table (with NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${var.environment}"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================
# ECR REPOSITORY
# ============================================

# Create ECR Repository for Docker images
resource "aws_ecr_repository" "app" {
  name = "${var.project_name}-backend-${var.environment}"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-ecr-${var.environment}"
  }
}

# ECR Repository Policy (allow EKS to pull images)
resource "aws_ecr_repository_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSImagePull"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}

# ============================================
# IAM ROLES FOR EKS
# ============================================

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-cluster-role-${var.environment}"
  }
}

# Attach Cluster Policy
resource "aws_iam_role_policy_attachment" "eks_cluster" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Attach VPC Controller Policy (for load balancers)
resource "aws_iam_role_policy_attachment" "eks_cluster_vpc" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# IAM Role for EKS Worker Nodes
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-node-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eks-node-role-${var.environment}"
  }
}

# Attach Node Policies
resource "aws_iam_role_policy_attachment" "eks_nodes_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_cni" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ecr" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "eks_nodes_ssm" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for EKS Nodes
resource "aws_iam_instance_profile" "eks_nodes" {
  name = "${var.project_name}-eks-node-profile-${var.environment}"
  role = aws_iam_role.eks_nodes.name
}

# ============================================
# EKS CLUSTER
# ============================================

# Create EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    endpoint_public_access  = var.cluster_endpoint_public_access
    endpoint_private_access = var.cluster_endpoint_private_access
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  tags = {
    Name = "${var.project_name}-eks-${var.environment}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_cluster_vpc
  ]
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-sg-${var.environment}"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-eks-sg-${var.environment}"
  }
}

# Allow all outbound traffic
resource "aws_security_group_rule" "eks_cluster_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
}

# Allow nodes to communicate with cluster
resource "aws_security_group_rule" "eks_cluster_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_nodes.id
  security_group_id        = aws_security_group.eks_cluster.id
}

# Security Group for EKS Worker Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg-${var.environment}"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-eks-nodes-sg-${var.environment}"
  }
}

# Allow all outbound from nodes
resource "aws_security_group_rule" "eks_nodes_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_nodes.id
}

# Allow cluster to communicate with nodes
resource "aws_security_group_rule" "eks_nodes_ingress" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.eks_cluster.id
  security_group_id        = aws_security_group.eks_nodes.id
}

# Allow SSH from bastion (optional - restrict for security)
resource "aws_security_group_rule" "eks_nodes_ssh" {
  count             = var.enable_bastion ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]
  security_group_id = aws_security_group.eks_nodes.id
}

# ============================================
# EKS NODE GROUP
# ============================================

# Create EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes-${var.environment}"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = var.node_instance_types
  capacity_type  = "ON_DEMAND"

  update_config {
    max_unavailable = 1
  }

  tags = {
    Name = "${var.project_name}-nodegroup-${var.environment}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_nodes_worker,
    aws_iam_role_policy_attachment.eks_nodes_cni,
    aws_iam_role_policy_attachment.eks_nodes_ecr
  ]
}

# ============================================
# OUTPUTS (displayed after apply)
# ============================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = aws_eks_cluster.main.endpoint
  sensitive   = true
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "node_group_name" {
  description = "Name of the node group"
  value       = aws_eks_node_group.main.node_group_name
}
EOF