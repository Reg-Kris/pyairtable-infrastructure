# Production Environment Configuration
# Full-scale production deployment with high availability

project_name = "pyairtable"
environment  = "prod"
aws_region   = "us-west-2"

# Networking
vpc_cidr           = "10.2.0.0/16"
enable_nat_gateway = true
single_nat_gateway = false  # Multi-AZ for high availability

# EKS Configuration
eks_cluster_version = "1.28"

# Go services node group (compute-optimized)
go_services_node_config = {
  instance_types = ["t3.medium", "t3.large", "c5.large"]
  min_size       = 2
  max_size       = 8
  desired_size   = 3
  capacity_type  = "SPOT"
}

# Python AI services node group (memory-optimized)
python_ai_node_config = {
  instance_types = ["r5.large", "r5.xlarge", "r5.2xlarge"]
  min_size       = 2
  max_size       = 6
  desired_size   = 2
  capacity_type  = "SPOT"
}

# General services node group (balanced)
general_services_node_config = {
  instance_types = ["t3.medium", "t3.large"]
  min_size       = 2
  max_size       = 6
  desired_size   = 3
  capacity_type  = "ON_DEMAND"  # More stable for production
}

# Aurora Configuration
aurora_engine_version = "15.4"
aurora_master_username = "postgres"
aurora_database_name = "pyairtable_prod"

aurora_serverless_config = {
  min_capacity = 1
  max_capacity = 8
}

aurora_backup_retention = 30
aurora_monitoring_interval = 15  # Enhanced monitoring
aurora_performance_insights = true

# ElastiCache Configuration
elasticache_node_type = "cache.r6g.large"  # Larger instance for production
elasticache_num_nodes = 3  # Higher availability
elasticache_parameter_group = "default.redis7"
elasticache_engine_version = "7.0"
elasticache_encryption_at_rest = true
elasticache_encryption_in_transit = true

# Istio Configuration
istio_version = "1.19.0"
istio_enable_tracing = true
istio_enable_kiali = true

# Monitoring Configuration
prometheus_retention = "30d"
prometheus_storage_size = "100Gi"
grafana_storage_size = "20Gi"
enable_jaeger_tracing = true

# Cost Optimization
monthly_budget_limit = 800
cost_alert_threshold = 75
log_retention_days = 30

# Additional tags
additional_tags = {
  Owner        = "platform-team"
  Purpose      = "production"
  CriticalData = "true"
  BackupPolicy = "daily"
  AutoShutdown = "false"
}