# EKS Module - Hybrid Node Groups for Go and Python Services
# Production-ready configuration with cost optimization

locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-eks-secrets"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-${var.environment}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# CloudWatch Log Group for EKS
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-logs"
  })
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(var.subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [var.cluster_security_group_id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_cloudwatch_log_group.eks_cluster,
  ]

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}

# OIDC Identity Provider
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-irsa"
  })
}

# Go Services Node Group - High Performance, Low Memory
resource "aws_eks_node_group" "go_services" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "go-services"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.go_services_config.instance_types
  capacity_type  = var.go_services_config.capacity_type
  
  scaling_config {
    desired_size = var.go_services_config.desired_size
    max_size     = var.go_services_config.max_size
    min_size     = var.go_services_config.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.go_services.id
    version = aws_launch_template.go_services.latest_version
  }

  # Taints to ensure only Go services run here
  taint {
    key    = "workload"
    value  = "go-services"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "go-services"
    type     = "compute-optimized"
  }

  tags = merge(var.tags, {
    Name     = "${local.cluster_name}-go-services"
    Workload = "go-services"
  })

  depends_on = [aws_eks_cluster.main]
}

# Python AI Services Node Group - High Memory, GPU Optional
resource "aws_eks_node_group" "python_ai_services" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "python-ai-services"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.python_ai_config.instance_types
  capacity_type  = var.python_ai_config.capacity_type
  
  scaling_config {
    desired_size = var.python_ai_config.desired_size
    max_size     = var.python_ai_config.max_size
    min_size     = var.python_ai_config.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.python_ai_services.id
    version = aws_launch_template.python_ai_services.latest_version
  }

  # Taints for Python AI services
  taint {
    key    = "workload"
    value  = "python-ai"
    effect = "NO_SCHEDULE"
  }

  labels = {
    workload = "python-ai"
    type     = "memory-optimized"
  }

  tags = merge(var.tags, {
    Name     = "${local.cluster_name}-python-ai"
    Workload = "python-ai"
  })

  depends_on = [aws_eks_cluster.main]
}

# General Services Node Group - Balanced for databases and general workloads
resource "aws_eks_node_group" "general_services" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "general-services"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids

  instance_types = var.general_services_config.instance_types
  capacity_type  = var.general_services_config.capacity_type
  
  scaling_config {
    desired_size = var.general_services_config.desired_size
    max_size     = var.general_services_config.max_size
    min_size     = var.general_services_config.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Launch template for advanced configuration
  launch_template {
    id      = aws_launch_template.general_services.id
    version = aws_launch_template.general_services.latest_version
  }

  labels = {
    workload = "general"
    type     = "balanced"
  }

  tags = merge(var.tags, {
    Name     = "${local.cluster_name}-general"
    Workload = "general"
  })

  depends_on = [aws_eks_cluster.main]
}

# Launch Templates for optimized configurations
resource "aws_launch_template" "go_services" {
  name_prefix   = "${local.cluster_name}-go-services-"
  image_id      = data.aws_ami.eks_optimized.id
  instance_type = var.go_services_config.instance_types[0]

  vpc_security_group_ids = [var.node_security_group_id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    bootstrap_arguments = "--container-runtime containerd --kubelet-extra-args '--node-labels=workload=go-services'"
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name     = "${local.cluster_name}-go-services"
      Workload = "go-services"
    })
  }
}

resource "aws_launch_template" "python_ai_services" {
  name_prefix   = "${local.cluster_name}-python-ai-"
  image_id      = data.aws_ami.eks_optimized.id
  instance_type = var.python_ai_config.instance_types[0]

  vpc_security_group_ids = [var.node_security_group_id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    bootstrap_arguments = "--container-runtime containerd --kubelet-extra-args '--node-labels=workload=python-ai'"
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 100
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name     = "${local.cluster_name}-python-ai"
      Workload = "python-ai"
    })
  }
}

resource "aws_launch_template" "general_services" {
  name_prefix   = "${local.cluster_name}-general-"
  image_id      = data.aws_ami.eks_optimized.id
  instance_type = var.general_services_config.instance_types[0]

  vpc_security_group_ids = [var.node_security_group_id]

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    cluster_name        = aws_eks_cluster.main.name
    cluster_endpoint    = aws_eks_cluster.main.endpoint
    cluster_ca          = aws_eks_cluster.main.certificate_authority[0].data
    bootstrap_arguments = "--container-runtime containerd --kubelet-extra-args '--node-labels=workload=general'"
  }))

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 50
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name     = "${local.cluster_name}-general"
      Workload = "general"
    })
  }
}

# EKS Add-ons
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.24.0-eksbuild.1"
  service_account_role_arn = var.ebs_csi_driver_role_arn
  
  tags = merge(var.tags, {
    Name = "${local.cluster_name}-ebs-csi"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.10.1-eksbuild.5"

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-coredns"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.28.2-eksbuild.2"

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-kube-proxy"
  })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.15.1-eksbuild.1"

  tags = merge(var.tags, {
    Name = "${local.cluster_name}-vpc-cni"
  })
}

# Data sources
data "aws_ami" "eks_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}