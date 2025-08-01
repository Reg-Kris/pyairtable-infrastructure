# PyAirtable Infrastructure - Main Configuration
# Production-ready EKS cluster with hybrid node pools, Aurora Serverless, ElastiCache, and Istio

terraform {
  required_version = ">= 1.5"
  
  backend "s3" {
    # Backend configuration will be provided via backend config file
    # Run: terraform init -backend-config=backend.hcl
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Local values for common tagging and naming
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "reg-kris"
    CostCenter  = "pyairtable"
  }
  
  name_prefix = "${var.project_name}-${var.environment}"
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC and Networking
module "networking" {
  source = "./modules/networking"
  
  project_name          = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  
  tags = local.common_tags
}

# Security Groups and IAM
module "security" {
  source = "./modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  vpc_cidr     = var.vpc_cidr
  
  tags = local.common_tags
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"
  
  project_name     = var.project_name
  environment      = var.environment
  cluster_name     = "${local.name_prefix}-eks"
  oidc_provider_arn = module.eks.oidc_provider_arn
  
  tags = local.common_tags
}

# EKS Cluster with Hybrid Node Groups
module "eks" {
  source = "./modules/eks"
  
  project_name           = var.project_name
  environment           = var.environment
  cluster_version       = var.eks_cluster_version
  
  vpc_id                = module.networking.vpc_id
  subnet_ids            = module.networking.private_subnet_ids
  public_subnet_ids     = module.networking.public_subnet_ids
  
  cluster_security_group_id = module.security.eks_cluster_security_group_id
  node_security_group_id    = module.security.eks_node_security_group_id
  
  cluster_role_arn      = module.iam.eks_cluster_role_arn
  node_group_role_arn   = module.iam.eks_node_group_role_arn
  
  # Node group configurations
  go_services_config    = var.go_services_node_config
  python_ai_config      = var.python_ai_node_config
  general_services_config = var.general_services_node_config
  
  log_retention_days    = var.log_retention_days
  
  tags = local.common_tags
}

# Aurora Serverless v2 PostgreSQL
module "aurora" {
  source = "./modules/aurora"
  
  project_name          = var.project_name
  environment          = var.environment
  
  vpc_id               = module.networking.vpc_id
  subnet_ids           = module.networking.private_subnet_ids
  security_group_ids   = [module.security.aurora_security_group_id]
  
  engine_version       = var.aurora_engine_version
  master_username      = var.aurora_master_username
  database_name        = var.aurora_database_name
  
  serverlessv2_scaling_configuration = var.aurora_serverless_config
  backup_retention_period = var.aurora_backup_retention
  
  monitoring_interval  = var.aurora_monitoring_interval
  performance_insights_enabled = var.aurora_performance_insights
  
  tags = local.common_tags
}

# ElastiCache Redis Cluster
module "elasticache" {
  source = "./modules/elasticache"
  
  project_name       = var.project_name
  environment       = var.environment
  
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.private_subnet_ids
  security_group_ids = [module.security.elasticache_security_group_id]
  
  node_type         = var.elasticache_node_type
  num_cache_nodes   = var.elasticache_num_nodes
  parameter_group_name = var.elasticache_parameter_group
  engine_version    = var.elasticache_engine_version
  
  at_rest_encryption_enabled = var.elasticache_encryption_at_rest
  transit_encryption_enabled = var.elasticache_encryption_in_transit
  
  tags = local.common_tags
}

# Istio Service Mesh
module "istio" {
  source = "./modules/istio"
  
  project_name    = var.project_name
  environment    = var.environment
  cluster_name   = module.eks.cluster_name
  
  istio_version  = var.istio_version
  enable_tracing = var.istio_enable_tracing
  enable_kiali   = var.istio_enable_kiali
  
  depends_on = [module.eks]
  
  tags = local.common_tags
}

# Monitoring Stack (Prometheus, Grafana, Jaeger)
module "monitoring" {
  source = "./modules/monitoring"
  
  project_name   = var.project_name
  environment   = var.environment
  cluster_name  = module.eks.cluster_name
  
  prometheus_retention        = var.prometheus_retention
  grafana_admin_password     = var.grafana_admin_password
  enable_jaeger_tracing      = var.enable_jaeger_tracing
  
  # Storage configuration
  prometheus_storage_size    = var.prometheus_storage_size
  grafana_storage_size      = var.grafana_storage_size
  
  depends_on = [module.eks, module.istio]
  
  tags = local.common_tags
}