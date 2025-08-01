# Aurora Serverless v2 PostgreSQL Module
# Cost-effective database with intelligent scaling

# KMS Key for Aurora encryption
resource "aws_kms_key" "aurora" {
  description             = "KMS key for Aurora encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-encryption"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.project_name}-${var.environment}-aurora-encryption"
  target_key_id = aws_kms_key.aurora.key_id
}

# DB Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-subnet-group"
  })
}

# Random password for Aurora master user
resource "random_password" "master_password" {
  length  = 32
  special = true
}

# Aurora Serverless v2 Cluster
resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${var.project_name}-${var.environment}-aurora"
  engine                 = "aurora-postgresql"
  engine_version         = var.engine_version
  engine_mode           = "provisioned"
  database_name         = var.database_name
  master_username       = var.master_username
  master_password       = random_password.master_password.result
  
  # Serverless v2 scaling configuration
  serverlessv2_scaling_configuration {
    max_capacity = var.serverlessv2_scaling_configuration.max_capacity
    min_capacity = var.serverlessv2_scaling_configuration.min_capacity
  }

  db_subnet_group_name   = aws_db_subnet_group.aurora.name
  vpc_security_group_ids = var.security_group_ids

  # Backup configuration
  backup_retention_period   = var.backup_retention_period
  preferred_backup_window   = "03:00-04:00"
  copy_tags_to_snapshot    = true

  # Maintenance
  preferred_maintenance_window = "sun:04:00-sun:05:00"

  # Encryption
  storage_encrypted = true
  kms_key_id       = aws_kms_key.aurora.arn

  # Performance monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval            = var.monitoring_interval
  monitoring_role_arn           = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_kms_key_id      = aws_kms_key.aurora.arn
  performance_insights_retention_period = 7

  # Deletion protection based on environment
  deletion_protection = var.environment == "prod"
  skip_final_snapshot = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  # Apply changes immediately in non-prod
  apply_immediately = var.environment != "prod"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-cluster"
  })
}

# Aurora Serverless v2 Writer Instance
resource "aws_rds_cluster_instance" "aurora_writer" {
  identifier          = "${var.project_name}-${var.environment}-aurora-writer"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class      = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-writer"
    Role = "writer"
  })
}

# Aurora Serverless v2 Reader Instance (only in production)
resource "aws_rds_cluster_instance" "aurora_reader" {
  count = var.environment == "prod" ? 1 : 0
  
  identifier          = "${var.project_name}-${var.environment}-aurora-reader"
  cluster_identifier  = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  engine_version     = aws_rds_cluster.aurora.engine_version

  performance_insights_enabled = var.performance_insights_enabled
  monitoring_interval          = var.monitoring_interval
  monitoring_role_arn         = aws_iam_role.rds_monitoring.arn

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-reader"
    Role = "reader"
  })
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Store database credentials in AWS Secrets Manager
resource "aws_secretsmanager_secret" "aurora_credentials" {
  name        = "${var.project_name}/${var.environment}/aurora/credentials"
  description = "Aurora database credentials"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-credentials"
  })
}

resource "aws_secretsmanager_secret_version" "aurora_credentials" {
  secret_id = aws_secretsmanager_secret.aurora_credentials.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master_password.result
    endpoint = aws_rds_cluster.aurora.endpoint
    reader_endpoint = aws_rds_cluster.aurora.reader_endpoint
    port     = aws_rds_cluster.aurora.port
    database = var.database_name
    connection_string = "postgresql://${var.master_username}:${random_password.master_password.result}@${aws_rds_cluster.aurora.endpoint}:${aws_rds_cluster.aurora.port}/${var.database_name}?sslmode=require"
  })
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "aurora_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora CPU utilization is too high"
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-cpu-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "aurora_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "100"
  alarm_description   = "Aurora connection count is too high"
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-connections-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "aurora_aurora_capacity" {
  alarm_name          = "${var.project_name}-${var.environment}-aurora-capacity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.serverlessv2_scaling_configuration.max_capacity * 0.8
  alarm_description   = "Aurora capacity is approaching maximum"
  
  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.aurora.cluster_identifier
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-aurora-capacity-alarm"
  })
}