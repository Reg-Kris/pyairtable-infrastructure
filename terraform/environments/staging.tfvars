# Staging Environment Configuration
# Production-like but smaller scale for testing

project_name = "pyairtable"
environment  = "staging"
aws_region   = "us-west-2"

# Networking
vpc_cidr           = "10.1.0.0/16"
enable_nat_gateway = true
single_nat_gateway = false  # Multi-AZ for production-like setup

# EKS Configuration
eks_cluster_version = "1.28"

# Go services node group (compute-optimized)
go_services_node_config = {
  instance_types = ["t3.medium", "t3.large"]
  min_size       = 1
  max_size       = 4
  desired_size   = 2
  capacity_type  = "SPOT"
}

# Python AI services node group (memory-optimized)
python_ai_node_config = {
  instance_types = ["r5.large", "r5.xlarge"]
  min_size       = 1
  max_size       = 3
  desired_size   = 1
  capacity_type  = "SPOT"
}

# General services node group (balanced)
general_services_node_config = {
  instance_types = ["t3.medium", "t3.large"]
  min_size       = 1
  max_size       = 3
  desired_size   = 2
  capacity_type  = "ON_DEMAND"
}

# Aurora Configuration
aurora_engine_version = "15.4"
aurora_master_username = "postgres"
aurora_database_name = "pyairtable_staging"

aurora_serverless_config = {
  min_capacity = 0.5
  max_capacity = 4
}

aurora_backup_retention = 14
aurora_monitoring_interval = 60
aurora_performance_insights = true

# ElastiCache Configuration
elasticache_node_type = "cache.t3.micro"
elasticache_num_nodes = 2
elasticache_parameter_group = "default.redis7"
elasticache_engine_version = "7.0"
elasticache_encryption_at_rest = true
elasticache_encryption_in_transit = true

# Istio Configuration
istio_version = "1.19.0"
istio_enable_tracing = true
istio_enable_kiali = true

# Monitoring Configuration
prometheus_retention = "15d"
prometheus_storage_size = "40Gi"
grafana_storage_size = "8Gi"
enable_jaeger_tracing = true

# Cost Optimization
monthly_budget_limit = 500
cost_alert_threshold = 80
log_retention_days = 14

# Additional tags
additional_tags = {
  Owner       = "qa-team"
  Purpose     = "staging"
  AutoShutdown = "true"
}