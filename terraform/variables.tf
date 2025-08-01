# Variables for PyAirtable Infrastructure
# Production-ready configuration with cost optimization

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "pyairtable"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for cost optimization"
  type        = bool
  default     = true
}

# EKS Configuration
variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.28"
}

variable "go_services_node_config" {
  description = "Configuration for Go services node group"
  type = object({
    instance_types = list(string)
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = string
  })
  default = {
    instance_types = ["t3.medium", "t3.large"]
    min_size       = 1
    max_size       = 6
    desired_size   = 2
    capacity_type  = "SPOT"
  }
}

variable "python_ai_node_config" {
  description = "Configuration for Python AI services node group"
  type = object({
    instance_types = list(string)
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = string
  })
  default = {
    instance_types = ["r5.large", "r5.xlarge"]
    min_size       = 1
    max_size       = 4
    desired_size   = 2
    capacity_type  = "SPOT"
  }
}

variable "general_services_node_config" {
  description = "Configuration for general services node group"
  type = object({
    instance_types = list(string)
    min_size      = number
    max_size      = number
    desired_size  = number
    capacity_type = string
  })
  default = {
    instance_types = ["t3.medium", "t3.large"]
    min_size       = 1
    max_size       = 4
    desired_size   = 2
    capacity_type  = "ON_DEMAND"
  }
}

# Aurora Configuration
variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "aurora_master_username" {
  description = "Aurora master username"
  type        = string
  default     = "postgres"
}

variable "aurora_database_name" {
  description = "Aurora database name"
  type        = string
  default     = "pyairtable"
}

variable "aurora_serverless_config" {
  description = "Aurora Serverless v2 scaling configuration"
  type = object({
    min_capacity = number
    max_capacity = number
  })
  default = {
    min_capacity = 0.5
    max_capacity = 4
  }
}

variable "aurora_backup_retention" {
  description = "Aurora backup retention period in days"
  type        = number
  default     = 7
}

variable "aurora_monitoring_interval" {
  description = "Aurora enhanced monitoring interval in seconds"
  type        = number
  default     = 60
}

variable "aurora_performance_insights" {
  description = "Enable Aurora Performance Insights"
  type        = bool
  default     = true
}

# ElastiCache Configuration
variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "elasticache_num_nodes" {
  description = "Number of ElastiCache nodes"
  type        = number
  default     = 2
}

variable "elasticache_parameter_group" {
  description = "ElastiCache parameter group"
  type        = string
  default     = "default.redis7"
}

variable "elasticache_engine_version" {
  description = "ElastiCache Redis engine version"
  type        = string
  default     = "7.0"
}

variable "elasticache_encryption_at_rest" {
  description = "Enable encryption at rest for ElastiCache"
  type        = bool
  default     = true
}

variable "elasticache_encryption_in_transit" {
  description = "Enable encryption in transit for ElastiCache"
  type        = bool
  default     = true
}

# Istio Configuration
variable "istio_version" {
  description = "Istio version to install"
  type        = string
  default     = "1.19.0"
}

variable "istio_enable_tracing" {
  description = "Enable Istio distributed tracing"
  type        = bool
  default     = true
}

variable "istio_enable_kiali" {
  description = "Enable Kiali service mesh dashboard"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "prometheus_retention" {
  description = "Prometheus data retention period"
  type        = string
  default     = "15d"
}

variable "prometheus_storage_size" {
  description = "Prometheus storage size"
  type        = string
  default     = "50Gi"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_storage_size" {
  description = "Grafana storage size"
  type        = string
  default     = "10Gi"
}

variable "enable_jaeger_tracing" {
  description = "Enable Jaeger distributed tracing"
  type        = bool
  default     = true
}

# General Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 14
}

# Cost Optimization
variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number
  default     = 600
}

variable "cost_alert_threshold" {
  description = "Cost alert threshold as percentage of budget"
  type        = number
  default     = 80
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}