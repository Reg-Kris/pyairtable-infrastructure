# Terraform Outputs
# Expose important infrastructure details for other systems

# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

# Node Group Outputs
output "go_services_node_group_arn" {
  description = "ARN of the Go services node group"
  value       = module.eks.go_services_node_group_arn
}

output "python_ai_node_group_arn" {
  description = "ARN of the Python AI services node group"
  value       = module.eks.python_ai_node_group_arn
}

output "general_services_node_group_arn" {
  description = "ARN of the general services node group"
  value       = module.eks.general_services_node_group_arn
}

# VPC and Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "database_subnet_ids" {
  description = "List of IDs of the database subnets"
  value       = module.networking.database_subnet_ids
}

# Aurora Database Outputs
output "aurora_cluster_id" {
  description = "Aurora cluster identifier"
  value       = module.aurora.cluster_id
}

output "aurora_cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = module.aurora.cluster_endpoint
  sensitive   = true
}

output "aurora_reader_endpoint" {
  description = "Aurora reader endpoint"
  value       = module.aurora.reader_endpoint
  sensitive   = true
}

output "aurora_cluster_port" {
  description = "Aurora cluster port"
  value       = module.aurora.cluster_port
}

output "aurora_cluster_database_name" {
  description = "Aurora cluster database name"
  value       = module.aurora.cluster_database_name
}

output "aurora_cluster_master_username" {
  description = "Aurora cluster master username"
  value       = module.aurora.cluster_master_username
  sensitive   = true
}

# ElastiCache Outputs
output "elasticache_cluster_id" {
  description = "ElastiCache cluster identifier"
  value       = module.elasticache.cluster_id
}

output "elasticache_primary_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = module.elasticache.primary_endpoint
  sensitive   = true
}

output "elasticache_reader_endpoint" {
  description = "ElastiCache reader endpoint (if applicable)"
  value       = module.elasticache.reader_endpoint
  sensitive   = true
}

# Security Group Outputs
output "eks_cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = module.security.eks_cluster_security_group_id
}

output "eks_node_security_group_id" {
  description = "Security group ID for EKS worker nodes"
  value       = module.security.eks_node_security_group_id
}

output "aurora_security_group_id" {
  description = "Security group ID for Aurora database"
  value       = module.security.aurora_security_group_id
}

output "elasticache_security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = module.security.elasticache_security_group_id
}

# IAM Role Outputs
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = module.iam.eks_cluster_role_arn
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = module.iam.eks_node_group_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "ARN of the cluster autoscaler IAM role"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = module.iam.ebs_csi_driver_role_arn
}

# Monitoring Outputs
output "prometheus_endpoint" {
  description = "Prometheus server endpoint"
  value       = module.monitoring.prometheus_endpoint
}

output "grafana_endpoint" {
  description = "Grafana dashboard endpoint"
  value       = module.monitoring.grafana_endpoint
}

output "jaeger_endpoint" {
  description = "Jaeger tracing endpoint"
  value       = module.monitoring.jaeger_endpoint
}

# Cost and Environment Information
output "environment_info" {
  description = "Environment configuration summary"
  value = {
    project_name    = var.project_name
    environment     = var.environment
    aws_region      = var.aws_region
    cluster_version = var.eks_cluster_version
    created_at      = timestamp()
  }
}

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

# Connection Strings (for applications)
output "database_connection_info" {
  description = "Database connection information"
  value = {
    host     = module.aurora.cluster_endpoint
    port     = module.aurora.cluster_port
    database = module.aurora.cluster_database_name
    username = module.aurora.cluster_master_username
  }
  sensitive = true
}

output "redis_connection_info" {
  description = "Redis connection information"
  value = {
    primary_endpoint = module.elasticache.primary_endpoint
    reader_endpoint  = module.elasticache.reader_endpoint
    port            = 6379
  }
  sensitive = true
}

# Deployment Configuration Summary
output "deployment_summary" {
  description = "Summary of deployed resources for documentation"
  value = {
    cluster_name           = module.eks.cluster_name
    node_groups           = 3
    total_max_nodes       = var.go_services_node_config.max_size + var.python_ai_node_config.max_size + var.general_services_node_config.max_size
    database_engine       = "aurora-postgresql"
    cache_engine          = "redis"
    service_mesh         = "istio"
    monitoring_stack     = "prometheus-grafana-jaeger"
    estimated_monthly_cost = "$${var.monthly_budget_limit}"
  }
}