cat > /d/Devsecopsrepos/devsecops-eks-project/terraform/environments/dev/variables.tf << 'EOF'
# ============================================
# AWS & ENVIRONMENT VARIABLES
# ============================================

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "devsecops-demo"
}

# ============================================
# NETWORK VARIABLES (VPC, SUBNETS)
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets"
  type        = bool
  default     = true
}

# ============================================
# EKS CLUSTER VARIABLES
# ============================================

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "cluster_endpoint_public_access" {
  description = "Enable public endpoint for EKS cluster (Set to false for security)"
  type        = bool
  default     = false
}

variable "cluster_endpoint_private_access" {
  description = "Enable private endpoint for EKS cluster"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks for public endpoint access (if enabled)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ============================================
# EKS NODE GROUP VARIABLES
# ============================================

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 4
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS worker nodes (t3.micro is free tier eligible)"
  type        = list(string)
  default     = ["t3.micro"]
}

variable "node_disk_size" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 20
}

variable "node_capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "ON_DEMAND"
}

# ============================================
# ECR VARIABLES
# ============================================

variable "ecr_repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = null
}

variable "ecr_image_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

variable "ecr_image_retention_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 30
}

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

# ============================================
# SECURITY VARIABLES
# ============================================

variable "enable_kms_encryption" {
  description = "Enable KMS encryption for EKS secrets and ECR images"
  type        = bool
  default     = true
}

variable "enable_secrets_manager" {
  description = "Enable AWS Secrets Manager (Use false for Vault in production)"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty for threat detection"
  type        = bool
  default     = false
}

variable "enable_bastion" {
  description = "Enable bastion host for secure access"
  type        = bool
  default     = false
}

variable "bastion_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_aws_waf" {
  description = "Enable AWS WAF for load balancer protection"
  type        = bool
  default     = false
}

variable "enable_aws_shield" {
  description = "Enable AWS Shield Advanced for DDoS protection"
  type        = bool
  default     = false
}

# ============================================
# MONITORING & LOGGING VARIABLES
# ============================================

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for EKS control plane"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention days for CloudWatch logs"
  type        = number
  default     = 90
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs for network monitoring"
  type        = bool
  default     = true
}

variable "vpc_flow_logs_retention_days" {
  description = "Retention days for VPC Flow Logs"
  type        = number
  default     = 30
}

# ============================================
# BACKUP VARIABLES
# ============================================

variable "enable_backup" {
  description = "Enable automated backups for EKS and volumes"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "backup_schedule" {
  description = "Cron schedule for backups (default: daily at 1 AM UTC)"
  type        = string
  default     = "0 1 * * *"
}

# ============================================
# TAGGING VARIABLES
# ============================================

variable "additional_tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default = {
    Owner          = "DevSecOps-Team"
    Project        = "DevSecOps-EKS-Demo"
    Environment    = "Development"
    CostCenter     = "Engineering"
    Compliance     = "CIS-Benchmark"
    Backup         = "Enabled"
    Monitoring     = "Prometheus-Grafana"
    SecurityLevel  = "High"
    DataClassification = "Internal"
  }
}

# ============================================
# COST OPTIMIZATION VARIABLES
# ============================================

variable "enable_auto_scaling" {
  description = "Enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "enable_karpenter" {
  description = "Enable Karpenter for intelligent node provisioning"
  type        = bool
  default     = false
}

variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "spot_instance_types" {
  description = "Instance types for spot nodes"
  type        = list(string)
  default     = ["t3.micro", "t3a.micro", "t4g.micro"]
}

# ============================================
# ADD-ONS & FEATURES VARIABLES
# ============================================

variable "enable_metrics_server" {
  description = "Enable Kubernetes metrics server"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable cluster autoscaler addon"
  type        = bool
  default     = true
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_cert_manager" {
  description = "Enable cert-manager for TLS certificates"
  type        = bool
  default     = true
}

variable "enable_ingress_nginx" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "enable_prometheus" {
  description = "Enable Prometheus for monitoring"
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Enable Grafana dashboards"
  type        = bool
  default     = true
}

# ============================================
# NOTIFICATION VARIABLES
# ============================================

variable "enable_sns_alerts" {
  description = "Enable SNS notifications for alerts"
  type        = bool
  default     = false
}

variable "sns_alert_email" {
  description = "Email address for SNS alerts"
  type        = string
  default     = ""
}

variable "enable_slack_notifications" {
  description = "Enable Slack notifications for deployments"
  type        = bool
  default     = false
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================
# KMS VARIABLES
# ============================================

variable "kms_key_deletion_window" {
  description = "Days until KMS key deletion"
  type        = number
  default     = 7
}

variable "enable_kms_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}
EOF