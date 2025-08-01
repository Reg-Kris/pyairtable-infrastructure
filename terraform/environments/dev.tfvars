# Development Environment Configuration
# Cost-optimized settings for development and testing

project_name = "pyairtable"
environment  = "dev"
aws_region   = "us-west-2"

# Networking
vpc_cidr           = "10.0.0.0/16"
enable_nat_gateway = true
single_nat_gateway = true  # Cost optimization

# EKS Configuration
eks_cluster_version = "1.28"

# Go services node group (compute-optimized)
go_services_node_config = {
  instance_types = ["t3.medium"]
  min_size       = 1
  max_size       = 3
  desired_size   = 1
  capacity_type  = "SPOT"
}

# Python AI services node group (memory-optimized)
python_ai_node_config = {
  instance_types = ["r5.large"]
  min_size       = 1
  max_size       = 2
  desired_size   = 1
  capacity_type  = "SPOT"
}

# General services node group (balanced)
general_services_node_config = {
  instance_types = ["t3.medium"]
  min_size       = 1
  max_size       = 2
  desired_size   = 1
  capacity_type  = "ON_DEMAND"
}

# Aurora Configuration
aurora_engine_version = "15.4"
aurora_master_username = "postgres"
aurora_database_name = "pyairtable_dev"

aurora_serverless_config = {
  min_capacity = 0.5
  max_capacity = 2
}

aurora_backup_retention = 7
aurora_monitoring_interval = 60
aurora_performance_insights = true

# ElastiCache Configuration
elasticache_node_type = "cache.t3.micro"
elasticache_num_nodes = 1  # Single node for dev
elasticache_parameter_group = "default.redis7"
elasticache_engine_version = "7.0"
elasticache_encryption_at_rest = true
elasticache_encryption_in_transit = true

# Istio Configuration
istio_version = "1.19.0"
istio_enable_tracing = true
istio_enable_kiali = true

# Monitoring Configuration
prometheus_retention = "7d"  # Shorter retention for dev
prometheus_storage_size = "20Gi"
grafana_storage_size = "5Gi"
enable_jaeger_tracing = true

# Cost Optimization
monthly_budget_limit = 300
cost_alert_threshold = 80
log_retention_days = 7  # Shorter retention for cost savings

# Additional tags
additional_tags = {
  Owner       = "dev-team"
  Purpose     = "development"
  AutoShutdown = "true"
}