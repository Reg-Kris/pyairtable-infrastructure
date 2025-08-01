# PyAirtable Infrastructure Deployment Guide

Complete step-by-step guide for deploying the PyAirtable infrastructure from scratch.

## Prerequisites

### Required Tools

1. **AWS CLI** (v2.0+)
   ```bash
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install
   ```

2. **Terraform** (v1.6.0+)
   ```bash
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

3. **kubectl** (v1.28.0+)
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

4. **Helm** (v3.12.0+)
   ```bash
   curl https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz | tar xz
   sudo mv linux-amd64/helm /usr/local/bin/
   ```

5. **GitHub CLI** (optional, for repository management)
   ```bash
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

### AWS Account Setup

1. **AWS Account**: Active AWS account with billing enabled
2. **IAM User**: Administrator access or specific permissions for:
   - EKS
   - VPC
   - RDS
   - ElastiCache
   - IAM
   - CloudWatch
   - S3
   - DynamoDB

3. **AWS CLI Configuration**:
   ```bash
   aws configure
   # Enter your Access Key ID, Secret Access Key, Region (us-west-2), and output format (json)
   ```

## Phase 1: Bootstrap Infrastructure

### Step 1: Create Terraform Backend

```bash
# Set your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
PROJECT_NAME="pyairtable"

# Create S3 bucket for Terraform state
aws s3 mb s3://${PROJECT_NAME}-terraform-state-${ACCOUNT_ID} --region ${REGION}

# Enable versioning on the bucket
aws s3api put-bucket-versioning \
    --bucket ${PROJECT_NAME}-terraform-state-${ACCOUNT_ID} \
    --versioning-configuration Status=Enabled

# Enable server-side encryption
aws s3api put-bucket-encryption \
    --bucket ${PROJECT_NAME}-terraform-state-${ACCOUNT_ID} \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            }
        }]
    }'

# Block public access
aws s3api put-public-access-block \
    --bucket ${PROJECT_NAME}-terraform-state-${ACCOUNT_ID} \
    --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name ${PROJECT_NAME}-terraform-locks \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region ${REGION}
```

### Step 2: Clone and Configure Repository

```bash
# Clone the infrastructure repository
git clone https://github.com/Reg-Kris/pyairtable-infrastructure.git
cd pyairtable-infrastructure

# Create backend configuration file
cat > terraform/backend.hcl <<EOF
bucket         = "${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
key            = "dev/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
encrypt        = true
EOF
```

## Phase 2: Development Environment Deployment

### Step 3: Initialize Terraform

```bash
cd terraform

# Initialize Terraform with backend configuration
terraform init -backend-config=backend.hcl

# Validate configuration
terraform validate

# Format code (optional)
terraform fmt -recursive
```

### Step 4: Plan Deployment

```bash
# Create development environment plan
terraform plan \
    -var-file="environments/dev.tfvars" \
    -var="environment=dev" \
    -out=dev.tfplan

# Review the plan carefully
# Expected resources: ~50-70 resources including:
# - VPC with subnets and networking
# - EKS cluster with 3 node groups
# - Aurora Serverless v2 cluster
# - ElastiCache Redis cluster
# - Security groups and IAM roles
# - Monitoring infrastructure
```

### Step 5: Deploy Infrastructure

```bash
# Apply the plan
terraform apply dev.tfplan

# This will take approximately 15-20 minutes
# EKS cluster creation is the longest step (~10-15 minutes)
```

### Step 6: Verify Deployment

```bash
# Get cluster name from Terraform output
CLUSTER_NAME=$(terraform output -raw cluster_name)

# Configure kubectl
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}

# Verify cluster access
kubectl cluster-info
kubectl get nodes

# Check node groups
kubectl get nodes --show-labels

# Verify system pods
kubectl get pods -n kube-system

# Check resource quotas
kubectl get resourcequotas -A
```

## Phase 3: Application Platform Setup

### Step 7: Deploy Kubernetes Base Manifests

```bash
# Navigate to Kubernetes manifests
cd ../k8s

# Apply base configurations
kubectl apply -k base/namespaces/
kubectl apply -k base/rbac/
kubectl apply -k base/network-policies/

# Verify namespace creation
kubectl get namespaces

# Check RBAC configuration
kubectl get serviceaccounts -A
kubectl get rolebindings,clusterrolebindings -A | grep pyairtable

# Verify network policies
kubectl get networkpolicies -A
```

### Step 8: Install Istio Service Mesh

```bash
# Download and install Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.19.0 sh -
cd istio-1.19.0
export PATH=$PWD/bin:$PATH

# Install Istio
istioctl install --set values.defaultRevision=default

# Enable Istio injection for application namespaces
kubectl label namespace pyairtable-api istio-injection=enabled
kubectl label namespace pyairtable-ai istio-injection=enabled
kubectl label namespace pyairtable-data istio-injection=enabled
kubectl label namespace pyairtable-automation istio-injection=enabled
kubectl label namespace pyairtable-frontend istio-injection=enabled

# Verify Istio installation
istioctl verify-install
kubectl get pods -n istio-system
```

### Step 9: Setup Monitoring Stack

```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
    --namespace pyairtable-monitoring \
    --create-namespace \
    --set prometheus.prometheusSpec.retention=15d \
    --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# Install Jaeger
helm install jaeger jaegertracing/jaeger \
    --namespace pyairtable-monitoring \
    --set provisionDataStore.cassandra=false \
    --set allInOne.enabled=true \
    --set storage.type=memory

# Verify monitoring stack
kubectl get pods -n pyairtable-monitoring
```

## Phase 4: Production Deployment (Optional)

### Step 10: Deploy Staging Environment

```bash
cd ../terraform

# Create staging backend configuration
cat > staging-backend.hcl <<EOF
bucket         = "${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
key            = "staging/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
encrypt        = true
EOF

# Initialize staging workspace
terraform init -backend-config=staging-backend.hcl -reconfigure

# Plan staging deployment
terraform plan \
    -var-file="environments/staging.tfvars" \
    -var="environment=staging" \
    -out=staging.tfplan

# Apply staging environment
terraform apply staging.tfplan
```

### Step 11: Deploy Production Environment

```bash
# Create production backend configuration
cat > prod-backend.hcl <<EOF
bucket         = "${PROJECT_NAME}-terraform-state-${ACCOUNT_ID}"
key            = "prod/terraform.tfstate"
region         = "${REGION}"
dynamodb_table = "${PROJECT_NAME}-terraform-locks"
encrypt        = true
EOF

# Initialize production workspace
terraform init -backend-config=prod-backend.hcl -reconfigure

# Plan production deployment
terraform plan \
    -var-file="environments/prod.tfvars" \
    -var="environment=prod" \
    -out=prod.tfplan

# Apply production environment (requires careful review)
terraform apply prod.tfplan
```

## Phase 5: CI/CD Setup

### Step 12: Configure GitHub Actions

1. **Fork the repository** to your GitHub account

2. **Create GitHub Secrets**:
   - Go to repository Settings → Secrets and variables → Actions
   - Add the following secrets:

   ```
   AWS_ROLE_ARN: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
   TERRAFORM_STATE_BUCKET: pyairtable-terraform-state-ACCOUNT_ID
   TERRAFORM_LOCK_TABLE: pyairtable-terraform-locks
   SLACK_WEBHOOK_URL: your-slack-webhook (optional)
   INFRACOST_API_KEY: your-infracost-key (optional)
   ```

3. **Create IAM Role for GitHub Actions**:
   ```bash
   # Create trust policy for GitHub Actions
   cat > github-actions-trust-policy.json <<EOF
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Effect": "Allow",
               "Principal": {
                   "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
               },
               "Action": "sts:AssumeRoleWithWebIdentity",
               "Condition": {
                   "StringEquals": {
                       "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                   },
                   "StringLike": {
                       "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/pyairtable-infrastructure:*"
                   }
               }
           }
       ]
   }
   EOF

   # Create IAM role
   aws iam create-role \
       --role-name github-actions-role \
       --assume-role-policy-document file://github-actions-trust-policy.json

   # Attach necessary policies (adjust as needed)
   aws iam attach-role-policy \
       --role-name github-actions-role \
       --policy-arn arn:aws:iam::aws:policy/PowerUserAccess
   ```

4. **Setup OIDC Provider** (if not exists):
   ```bash
   aws iam create-open-id-connect-provider \
       --url https://token.actions.githubusercontent.com \
       --client-id-list sts.amazonaws.com \
       --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

### Step 13: Test CI/CD Pipeline

1. **Create a test PR**:
   ```bash
   git checkout -b test-deployment
   echo "# Test deployment" >> README.md
   git add README.md
   git commit -m "Test CI/CD pipeline"
   git push origin test-deployment
   ```

2. **Create Pull Request** on GitHub

3. **Verify pipeline execution**:
   - Security scan should run
   - Terraform plan should execute
   - Cost estimation should appear (if Infracost is configured)

4. **Merge PR** to trigger deployment

## Phase 6: Validation and Monitoring

### Step 14: Validate Deployment

```bash
# Run infrastructure validation
cd scripts
./validate-infrastructure.sh dev

# Check all services are running
kubectl get pods -A

# Verify database connectivity
kubectl run -it --rm debug --image=postgres:15 --restart=Never -- \
    psql -h $(terraform output -raw aurora_cluster_endpoint) -U postgres -d pyairtable_dev

# Test Redis connectivity
kubectl run -it --rm debug --image=redis:7 --restart=Never -- \
    redis-cli -h $(terraform output -raw elasticache_primary_endpoint)
```

### Step 15: Access Monitoring Dashboards

```bash
# Port forward to access Grafana
kubectl port-forward -n pyairtable-monitoring svc/prometheus-grafana 3000:80

# Access Grafana at http://localhost:3000
# Default credentials: admin/prom-operator

# Port forward to access Prometheus
kubectl port-forward -n pyairtable-monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Port forward to access Jaeger
kubectl port-forward -n pyairtable-monitoring svc/jaeger-query 16686:16686
```

## Phase 7: Cost Monitoring Setup

### Step 16: Configure Cost Alerts

```bash
# Create budget alert
aws budgets create-budget \
    --account-id ${ACCOUNT_ID} \
    --budget '{
        "BudgetName": "PyAirtable-Monthly-Budget",
        "BudgetLimit": {
            "Amount": "600",
            "Unit": "USD"
        },
        "TimeUnit": "MONTHLY",
        "BudgetType": "COST"
    }' \
    --notifications-with-subscribers '[{
        "Notification": {
            "NotificationType": "ACTUAL",
            "ComparisonOperator": "GREATER_THAN",
            "Threshold": 80
        },
        "Subscribers": [{
            "SubscriptionType": "EMAIL",
            "Address": "your-email@example.com"
        }]
    }]'
```

## Troubleshooting

### Common Issues

1. **EKS Cluster Creation Timeout**:
   ```bash
   # Check CloudFormation events
   aws cloudformation describe-stack-events --stack-name eksctl-pyairtable-dev-cluster
   ```

2. **Node Group Not Ready**:
   ```bash
   # Check node group status
   aws eks describe-nodegroup --cluster-name pyairtable-dev-eks --nodegroup-name go-services
   
   # Check node logs
   kubectl describe nodes
   ```

3. **Database Connection Issues**:
   ```bash
   # Check security groups
   aws ec2 describe-security-groups --group-ids $(terraform output -raw aurora_security_group_id)
   
   # Verify subnets
   aws rds describe-db-subnet-groups --db-subnet-group-name pyairtable-dev-aurora-subnet-group
   ```

### Recovery Procedures

1. **Rollback Deployment**:
   ```bash
   # Rollback to previous Terraform state
   terraform plan -destroy -var-file="environments/dev.tfvars"
   terraform destroy -var-file="environments/dev.tfvars"
   ```

2. **Disaster Recovery**:
   ```bash
   # Restore from backup (Aurora)
   aws rds restore-db-cluster-from-snapshot \
       --db-cluster-identifier pyairtable-dev-aurora-restored \
       --snapshot-identifier pyairtable-dev-aurora-final-snapshot
   ```

## Next Steps

After successful deployment:

1. **Deploy Applications**: Use the application repositories to deploy services
2. **Setup SSL/TLS**: Configure certificates for HTTPS endpoints
3. **Configure DNS**: Set up domain names and routing
4. **Security Hardening**: Implement additional security measures
5. **Performance Tuning**: Optimize based on actual usage patterns
6. **Backup Strategy**: Implement comprehensive backup procedures

## Support and Maintenance

- **Daily**: Monitor dashboards and alerts
- **Weekly**: Review cost reports and optimize resources
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Conduct security audits and disaster recovery tests

For additional support, refer to:
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [Security Best Practices](../security/SECURITY_GUIDE.md)
- [Cost Optimization Guide](../cost/COST_OPTIMIZATION.md)