# PyAirtable Infrastructure

Production-ready Infrastructure as Code for the PyAirtable platform using Terraform, Kubernetes, and AWS services.

## Architecture Overview

This repository contains the complete infrastructure setup for PyAirtable, a microservices-based platform built with hybrid architecture supporting both Go and Python services with AI/ML capabilities.

### Key Components

- **EKS Cluster** with hybrid node groups optimized for different workload types
- **Aurora Serverless v2** PostgreSQL for cost-effective database scaling
- **ElastiCache Redis** for session storage and caching
- **Istio Service Mesh** for advanced traffic management and security
- **Comprehensive Monitoring** with Prometheus, Grafana, and Jaeger
- **CI/CD Pipeline** with automated deployment and validation

### Cost Optimization

Target monthly cost: **$300-600** with intelligent autoscaling and spot instances.

## Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.6.0
- kubectl >= 1.28.0
- Helm >= 3.12.0

### Initial Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Reg-Kris/pyairtable-infrastructure.git
   cd pyairtable-infrastructure
   ```

2. **Configure Terraform backend:**
   ```bash
   # Create S3 bucket for Terraform state
   aws s3 mb s3://pyairtable-terraform-state-$(aws sts get-caller-identity --query Account --output text)
   
   # Create DynamoDB table for state locking
   aws dynamodb create-table \
     --table-name pyairtable-terraform-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST
   ```

3. **Set up environment variables:**
   ```bash
   export AWS_REGION=us-west-2
   export TERRAFORM_STATE_BUCKET=pyairtable-terraform-state-$(aws sts get-caller-identity --query Account --output text)
   export TERRAFORM_LOCK_TABLE=pyairtable-terraform-locks
   ```

4. **Initialize and deploy:**
   ```bash
   cd terraform
   
   # Initialize Terraform
   terraform init \
     -backend-config="bucket=$TERRAFORM_STATE_BUCKET" \
     -backend-config="key=dev/terraform.tfstate" \
     -backend-config="region=$AWS_REGION" \
     -backend-config="dynamodb_table=$TERRAFORM_LOCK_TABLE"
   
   # Plan deployment
   terraform plan -var-file="environments/dev.tfvars" -var="environment=dev"
   
   # Apply changes
   terraform apply -var-file="environments/dev.tfvars" -var="environment=dev"
   ```

## Architecture Details

### EKS Hybrid Node Groups

The cluster uses three specialized node groups:

#### 1. Go Services Node Group
- **Instance Types:** t3.medium, t3.large
- **Capacity:** SPOT instances for 70% cost savings
- **Workloads:** API Gateway, Platform Services
- **Optimizations:** Compute-optimized with minimal memory overhead

#### 2. Python AI Services Node Group
- **Instance Types:** r5.large, r5.xlarge (memory-optimized)
- **Capacity:** SPOT instances with higher memory allocation
- **Workloads:** LLM Orchestrator, MCP Server
- **Optimizations:** High memory for AI/ML workloads

#### 3. General Services Node Group
- **Instance Types:** t3.medium, t3.large
- **Capacity:** ON_DEMAND for stable stateful services
- **Workloads:** Frontend, Databases, Redis
- **Optimizations:** Balanced for mixed workloads

### Database Architecture

#### Aurora Serverless v2 PostgreSQL
- **Scaling:** 0.5 ACU minimum to 4 ACU maximum
- **Cost:** Pay-per-use with intelligent scaling
- **Features:** Automated backups, Performance Insights, encryption
- **High Availability:** Multi-AZ deployment in production

#### ElastiCache Redis
- **Configuration:** 2-node cluster with automatic failover
- **Security:** Encryption at rest and in transit
- **Use Cases:** Session storage, API caching, real-time data

### Service Mesh (Istio)

Advanced traffic management and security features:
- **mTLS:** Automatic mutual TLS between services
- **Traffic Management:** Canary deployments, circuit breakers
- **Observability:** Distributed tracing with Jaeger
- **Security:** Fine-grained access policies

### Monitoring Stack

#### Prometheus
- **Metrics Collection:** Application and infrastructure metrics
- **Storage:** 15-day retention for cost optimization
- **Alerts:** Integration with Slack and email notifications

#### Grafana
- **Dashboards:** Pre-configured dashboards for all services
- **Data Sources:** Prometheus, CloudWatch, Jaeger
- **Authentication:** OAuth integration with GitHub

#### Jaeger
- **Distributed Tracing:** End-to-end request tracing
- **Performance Analysis:** Latency and dependency mapping
- **Integration:** Automatic instrumentation via Istio

## Environment Configuration

### Development (dev)
- **Cost Target:** $200-300/month
- **Resources:** Minimal node groups with spot instances
- **Features:** Basic monitoring, single-AZ deployment

### Staging (staging)
- **Cost Target:** $400-500/month
- **Resources:** Production-like but smaller scale
- **Features:** Full monitoring, multi-AZ, performance testing

### Production (prod)
- **Cost Target:** $500-600/month
- **Resources:** Full redundancy with autoscaling
- **Features:** Complete monitoring, backup, disaster recovery

## Security Features

### Network Security
- **VPC:** Isolated network with private subnets
- **Security Groups:** Least-privilege access rules
- **Network Policies:** Kubernetes-native service isolation
- **WAF:** Web Application Firewall for public endpoints

### Identity and Access Management
- **RBAC:** Role-based access control for all services
- **Service Accounts:** Dedicated accounts with minimal permissions
- **IRSA:** IAM Roles for Service Accounts integration
- **Pod Security Standards:** Enforced security contexts

### Data Protection
- **Encryption:** All data encrypted at rest and in transit
- **Secrets Management:** AWS Secrets Manager integration
- **Key Management:** AWS KMS for encryption keys
- **Backup:** Automated backups with point-in-time recovery

## Cost Optimization Strategies

### Compute Optimization
- **Spot Instances:** 70% cost savings on ephemeral workloads
- **Autoscaling:** Automatic scaling based on demand
- **Reserved Instances:** For stable production workloads
- **Scheduled Scaling:** Scale down during off-hours

### Storage Optimization
- **GP3 Volumes:** Cost-effective storage with better performance
- **Lifecycle Policies:** Automatic cleanup of old data
- **Compression:** Reduced storage requirements
- **Tiered Storage:** Multiple storage classes based on access patterns

### Network Optimization
- **Single NAT Gateway:** Reduced network costs in non-prod
- **VPC Endpoints:** Avoid data transfer charges
- **CloudFront:** CDN for static content delivery
- **Regional Deployment:** Single region to minimize costs

## Deployment Guide

### Using GitHub Actions (Recommended)

1. **Fork the repository** and configure secrets:
   ```
   AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/github-actions-role
   TERRAFORM_STATE_BUCKET: your-terraform-state-bucket
   TERRAFORM_LOCK_TABLE: your-terraform-lock-table
   SLACK_WEBHOOK_URL: your-slack-webhook (optional)
   INFRACOST_API_KEY: your-infracost-key (optional)
   ```

2. **Deploy via workflow dispatch:**
   - Go to Actions tab
   - Select "Terraform Deploy"
   - Choose environment and action
   - Run workflow

### Manual Deployment

1. **Set up AWS credentials:**
   ```bash
   aws configure
   # or use IAM roles/instance profiles
   ```

2. **Deploy infrastructure:**
   ```bash
   cd terraform
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=environments/dev.tfvars
   terraform apply -var-file=environments/dev.tfvars
   ```

3. **Configure kubectl:**
   ```bash
   aws eks update-kubeconfig --region us-west-2 --name pyairtable-dev-eks
   ```

4. **Deploy Kubernetes manifests:**
   ```bash
   kubectl apply -k k8s/base/
   kubectl apply -k k8s/overlays/dev/
   ```

## Monitoring and Operations

### Health Checks

The infrastructure includes comprehensive health monitoring:

- **EKS Cluster:** Node health, pod status, resource utilization
- **Aurora Database:** Connection health, performance metrics, backup status
- **Redis Cache:** Memory usage, connection count, replication lag
- **Load Balancers:** Target health, response times, error rates

### Alerting

Automated alerts for critical issues:

- **Infrastructure:** Node failures, resource exhaustion
- **Database:** Connection limits, slow queries, backup failures
- **Application:** High error rates, response time degradation
- **Security:** Unauthorized access attempts, certificate expiration

### Backup and Recovery

- **Database Backups:** Automated daily backups with 7-day retention
- **Configuration Backups:** Terraform state and Kubernetes manifests
- **Disaster Recovery:** Cross-region backup for production
- **Recovery Testing:** Automated recovery validation

## Troubleshooting

### Common Issues

#### EKS Node Group Scaling Issues
```bash
# Check node group status
aws eks describe-nodegroup --cluster-name pyairtable-dev-eks --nodegroup-name go-services

# Check cluster autoscaler logs
kubectl logs -n kube-system deployment/cluster-autoscaler
```

#### Database Connection Issues
```bash
# Check Aurora cluster status
aws rds describe-db-clusters --db-cluster-identifier pyairtable-dev-aurora

# Test connectivity from pod
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- psql -h ENDPOINT -U postgres -d pyairtable
```

#### Istio Service Mesh Issues
```bash
# Check Istio installation
istioctl verify-install

# Analyze service mesh configuration
istioctl analyze

# Check proxy status
istioctl proxy-status
```

### Debugging Commands

```bash
# Check all pod status
kubectl get pods -A

# View pod logs
kubectl logs -f deployment/api-gateway -n pyairtable-api

# Check service endpoints
kubectl get endpoints -A

# Validate network policies
kubectl describe networkpolicy -A

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

## Security Best Practices

### Infrastructure Security
- Enable AWS CloudTrail for audit logging
- Use least-privilege IAM policies
- Enable VPC Flow Logs for network monitoring
- Regular security assessments with AWS Config

### Application Security
- Implement proper RBAC for all services
- Use network policies to isolate workloads
- Enable pod security standards
- Regular vulnerability scanning of container images

### Data Security
- Encrypt all data at rest and in transit
- Use AWS Secrets Manager for sensitive data
- Implement proper backup and retention policies
- Regular access reviews and key rotation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request with detailed description
5. Ensure all CI/CD checks pass

### Development Workflow

1. **Local Testing:**
   ```bash
   # Validate Terraform
   terraform fmt -check -recursive
   terraform validate
   
   # Security scanning
   checkov -f terraform/
   tfsec terraform/
   ```

2. **Integration Testing:**
   ```bash
   # Deploy to dev environment
   terraform apply -var-file=environments/dev.tfvars
   
   # Run validation tests
   ./scripts/validate-infrastructure.sh
   ```

## Support

- **Documentation:** [Architecture Docs](docs/architecture/)
- **Issues:** [GitHub Issues](https://github.com/Reg-Kris/pyairtable-infrastructure/issues)
- **Discussions:** [GitHub Discussions](https://github.com/Reg-Kris/pyairtable-infrastructure/discussions)
- **Security:** [Security Policy](SECURITY.md)

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

**Maintained by:** Reg-Kris Organization  
**Last Updated:** January 2025  
**Version:** 1.0.0