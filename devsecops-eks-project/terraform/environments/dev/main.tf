terraform {
  required_version = ">= 1.5.0"
  
  backend "s3" {
    bucket         = "devsecops-tfstate-${var.aws_account_id}"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
    kms_key_id     = "alias/terraform-state-key"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = var.environment
      Project       = "DevSecOps-EKS"
      ManagedBy     = "Terraform"
      SecurityLevel = "High"
      BackupEnabled = "true"
    }
  }
}

# VPC Module with Private/Public Subnets
module "vpc" {
  source = "../../modules/vpc"
  
  name_prefix = "${var.project_name}-${var.environment}"
  vpc_cidr    = var.vpc_cidr
  azs         = var.availability_zones
  
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  
  enable_nat_gateway     = true
  single_nat_gateway     = false  # HA across AZs
  enable_vpn_gateway     = false
  enable_flow_logs       = true
  
  # VPC Flow Logs for security monitoring
  flow_logs_retention_days = 90
  flow_logs_destination_arn = module.s3_bucket.flow_logs_bucket_arn
  
  # Security tags for EKS
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
  
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "shared"
  }
}

# ECR Module with Image Scanning
module "ecr" {
  source = "../../modules/ecr"
  
  repository_name = "${var.project_name}-backend"
  
  image_scanning_configuration = {
    scan_on_push = true
  }
  
  # Lifecycle policy for image retention
  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 30 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 30
      }
      action = {
        type = "expire"
      }
    }]
  })
  
  encryption_configuration = {
    encryption_type = "KMS"
    kms_key         = module.kms.ecr_key_arn
  }
}

# EKS Cluster Module
module "eks" {
  source = "../../modules/eks"
  
  cluster_name    = "${var.project_name}-${var.environment}"
  cluster_version = var.kubernetes_version
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Security configuration
  cluster_endpoint_public_access  = false  # Private endpoint only
  cluster_endpoint_private_access = true
  
  # Enable KMS encryption for secrets
  cluster_encryption_config = {
    provider_key_arn = module.kms.eks_key_arn
    resources        = ["secrets"]
  }
  
  # Enable all CloudWatch logs
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  
  # Managed Node Groups
  node_groups = {
    # On-demand nodes for critical workloads
    critical = {
      name           = "critical-workloads"
      instance_types = ["t3.medium", "t3.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 5
      capacity_type  = "ON_DEMAND"
      
      # Security configuration
      disk_size       = 50
      disk_encryption = true
      
      labels = {
        workload-type = "critical"
        backup-enabled = "true"
      }
      
      taints = []  # No taints for critical workloads
      
      tags = {
        "k8s.io/cluster-autoscaler/enabled" = "true"
        "k8s.io/cluster-autoscaler/${var.project_name}-${var.environment}" = "owned"
      }
    }
    
    # Spot nodes for fault-tolerant workloads
    spot = {
      name           = "spot-workloads"
      instance_types = ["t3.medium", "t3a.medium", "t4g.medium"]
      desired_size   = 1
      min_size       = 1
      max_size       = 4
      capacity_type  = "SPOT"
      
      disk_size       = 50
      disk_encryption = true
      
      labels = {
        workload-type = "spot-tolerant"
        backup-enabled = "false"
      }
      
      taints = [{
        key    = "spot"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }
  
  # Add-ons with security configurations
  cluster_addons = {
    coredns = {
      addon_version = "v1.11.1-eksbuild.2"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version = "v1.28.3-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version = "v1.18.1-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_IP_TARGET           = "5"
        }
      })
    }
    ebs-csi-driver = {
      addon_version = "v1.29.0-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
      service_account_role_arn = module.iam.ebs_csi_role_arn
    }
  }
  
  tags = {
    Environment = var.environment
    Terraform   = "true"
  }
  
  depends_on = [module.iam]
}

# Security Module - IAM, KMS, Secrets Manager
module "security" {
  source = "../../modules/security"
  
  cluster_name     = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  # Enable pod identity for IRSA
  enable_pod_identity = true
  
  # KMS keys for different services
  kms_config = {
    eks_key_description   = "KMS key for EKS secrets encryption"
    ecr_key_description   = "KMS key for ECR image encryption"
    s3_key_description    = "KMS key for S3 bucket encryption"
    backup_key_description = "KMS key for backup encryption"
  }
  
  # Secrets Manager configuration
  secrets_config = {
    database = {
      create = true
      username = var.db_username
      password = var.db_password
      engine   = "postgresql"
      host     = module.rds.endpoint
      port     = 5432
    }
    api_keys = {
      create = true
      keys   = var.api_keys
    }
  }
}

# Backup Module - Velero configuration
module "backup" {
  source = "../../modules/backup"
  
  cluster_name       = module.eks.cluster_name
  eks_oidc_provider  = module.eks.oidc_provider_arn
  
  backup_bucket_name = "${var.project_name}-backups-${var.environment}"
  
  # Backup schedule configurations
  schedules = {
    daily = {
      schedule     = "0 1 * * *"  # 1 AM daily
      ttl          = "720h"        # 30 days
      included_namespaces = ["production", "staging"]
      excluded_resources = ["events", "events.events.k8s.io"]
    }
    weekly = {
      schedule     = "0 2 * * 0"   # 2 AM Sunday
      ttl          = "2160h"       # 90 days
      included_namespaces = ["production"]
    }
  }
  
  # Enable scheduled backups
  enable_backup_schedules = true
  backup_retention_days   = 90
  
  # Encryption for backups
  backup_encryption_key_arn = module.kms.backup_key_arn
}

# S3 Buckets for various purposes
module "s3_buckets" {
  source = "../../modules/s3"
  
  buckets = {
    tfstate = {
      name          = "${var.project_name}-tfstate-${var.environment}"
      versioning    = true
      encryption    = true
      lifecycle_rules = [{
        enabled = true
        transitions = [
          { days = 30, storage_class = "STANDARD_IA" },
          { days = 90, storage_class = "GLACIER" }
        ]
        expiration_days = 365
      }]
    }
    backups = {
      name          = "${var.project_name}-backups-${var.environment}"
      versioning    = true
      encryption    = true
      replication   = true
      replication_region = "us-west-2"
    }
    logs = {
      name          = "${var.project_name}-logs-${var.environment}"
      versioning    = true
      encryption    = true
      lifecycle_rules = [{
        transitions = [
          { days = 30, storage_class = "GLACIER" }
        ]
        expiration_days = 90
      }]
    }
  }
}
