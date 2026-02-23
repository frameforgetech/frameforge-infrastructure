#!/bin/bash

# FrameForge Infrastructure - Apply Dev Environment
# Creates/updates the infrastructure

set -e

echo "========================================="
echo "FrameForge - Deploy Dev Environment"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEV_DIR="$SCRIPT_DIR/../terraform/environments/dev"

cd "$DEV_DIR"

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

# Show cost warning
echo -e "${YELLOW}⚠️  COST WARNING ⚠️${NC}"
echo -e "${YELLOW}This will create resources that cost ~\$110-130/month:${NC}"
echo -e "${YELLOW}  - EKS Control Plane: \$72/month${NC}"
echo -e "${YELLOW}  - NAT Gateway: \$32/month + data transfer${NC}"
echo -e "${YELLOW}  - EC2 instances: ~\$20-30/month${NC}"
echo ""
echo -e "${YELLOW}Free tier eligible resources:${NC}"
echo -e "${YELLOW}  - RDS db.t3.micro (first 12 months)${NC}"
echo -e "${YELLOW}  - S3 (5GB free)${NC}"
echo ""
echo -e "${RED}💰 Remember to destroy when not in use to avoid charges!${NC}"
echo -e "${RED}   Run: ./scripts/destroy-dev.sh${NC}"
echo ""
read -p "Continue with deployment? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo -e "${GREEN}Pre-deployment state sync...${NC}"
echo ""

ENVIRONMENT="dev"
AWS_REGION="us-east-1"

# Fix: Recover deleted secrets first
echo "  Checking for resources in recovery period..."
SECRET_ARN=$(aws secretsmanager describe-secret \
  --secret-id frameforge/rds/dev/master-password \
  --region "$AWS_REGION" \
  --query "ARN" \
  --output text 2>/dev/null || echo "")

if [ -n "$SECRET_ARN" ]; then
  DELETED_DATE=$(aws secretsmanager describe-secret \
    --secret-id frameforge/rds/dev/master-password \
    --region "$AWS_REGION" \
    --query "DeletedDate" \
    --output text 2>/dev/null || echo "")
  
  if [ "$DELETED_DATE" != "None" ] && [ -n "$DELETED_DATE" ]; then
    echo "    Secret in recovery. Restoring..."
    aws secretsmanager restore-secret \
      --secret-id frameforge/rds/dev/master-password \
      --region "$AWS_REGION" 2>/dev/null || true
    sleep 5
  fi
fi

# Clean log group
LOG_GROUP="/aws/vpc/frameforge-$ENVIRONMENT"
if aws logs describe-log-groups \
  --log-group-name-prefix "/aws/vpc/frameforge-$ENVIRONMENT" \
  --region "$AWS_REGION" 2>/dev/null | grep -q "\"logGroupName\": \"$LOG_GROUP\""; then
  echo "    Removing existing log group..."
  aws logs delete-log-group \
    --log-group-name "$LOG_GROUP" \
    --region "$AWS_REGION" 2>/dev/null || true
  sleep 5
fi

echo ""
echo -e "${GREEN}Deploying dev environment...${NC}"
echo ""

# Apply Terraform
terraform apply -auto-approve

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Show outputs
echo "Infrastructure details:"
terraform output

echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "  1. Get DB password: aws secretsmanager get-secret-value --secret-id \$(terraform output -raw db_secret_arn) --query SecretString --output text | jq -r .password"
echo "  2. Deploy Kubernetes manifests: kubectl apply -f k8s/"
echo "  3. Check services: kubectl get pods -A"
echo ""
echo -e "${RED}⚠️  Don't forget to destroy when done: ./scripts/destroy-dev.sh${NC}"
echo ""
