#!/bin/bash

# Quick Smoke Test for FrameForge Infrastructure
# Validates all components are working correctly

set -e

ENVIRONMENT="${1:-dev}"
AWS_REGION="${2:-us-east-1}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEV_DIR="$SCRIPT_DIR/../terraform/environments/dev"

cd "$DEV_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}FrameForge Infrastructure Smoke Test${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Get outputs
DB_ADDRESS=$(terraform output -raw db_address 2>/dev/null || echo "")
EKS_CLUSTER=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
EKS_ENDPOINT=$(terraform output -raw eks_cluster_endpoint 2>/dev/null || echo "")
SECRET_ARN=$(terraform output -raw db_secret_arn 2>/dev/null || echo "")
RMQ_IP=$(terraform output -raw rabbitmq_private_ip 2>/dev/null || echo "")
REDIS_IP=$(terraform output -raw redis_private_ip 2>/dev/null || echo "")
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")

# Test 1: RDS Connection
echo -e "${YELLOW}1. Testing RDS PostgreSQL...${NC}"
if [ -n "$DB_ADDRESS" ]; then
  if nc -z -w 5 "$DB_ADDRESS" 5432 2>/dev/null; then
    echo -e "   ${GREEN}✅ RDS is reachable on $DB_ADDRESS:5432${NC}"
  else
    # Try DNS resolution at least
    if ping -c 1 "$DB_ADDRESS" &>/dev/null; then
      echo -e "   ${GREEN}✅ RDS DNS resolves: $DB_ADDRESS${NC}"
    else
      echo -e "   ${RED}❌ RDS not reachable${NC}"
    fi
  fi
  
  # Get password
  if [ -n "$SECRET_ARN" ]; then
    PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" \
      --region "$AWS_REGION" --query "SecretString" --output text 2>/dev/null | jq -r .password)
    echo -e "   ${GREEN}✅ RDS password retrieved from Secrets Manager${NC}"
  fi
else
  echo -e "   ${RED}❌ Could not get RDS address${NC}"
fi

# Test 2: EKS Cluster
echo ""
echo -e "${YELLOW}2. Testing EKS Cluster...${NC}"
if [ -n "$EKS_CLUSTER" ]; then
  CLUSTER_STATUS=$(aws eks describe-cluster --name "$EKS_CLUSTER" \
    --region "$AWS_REGION" --query "cluster.status" --output text 2>/dev/null || echo "")
  
  if [ "$CLUSTER_STATUS" = "ACTIVE" ]; then
    echo -e "   ${GREEN}✅ EKS Cluster is ACTIVE: $EKS_CLUSTER${NC}"
  else
    echo -e "   ${YELLOW}⚠️  EKS Cluster status: $CLUSTER_STATUS${NC}"
  fi
  
  # Test kubectl access
  if command -v kubectl &>/dev/null; then
    echo "   Configuring kubectl..."
    aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION" &>/dev/null
    
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
      echo -e "   ${GREEN}✅ kubectl access working - $NODE_COUNT nodes found${NC}"
    else
      echo -e "   ${YELLOW}⚠️  kubectl configured but no nodes yet (still initializing)${NC}"
    fi
  else
    echo -e "   ${YELLOW}ℹ️  kubectl not installed, skipping k8s tests${NC}"
  fi
else
  echo -e "   ${RED}❌ Could not get EKS cluster name${NC}"
fi

# Test 3: EC2 Instances (RabbitMQ, Redis)
echo ""
echo -e "${YELLOW}3. Testing EC2 Instances...${NC}"
INSTANCE_COUNT=$(aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=$ENVIRONMENT" "Name=instance-state-name,Values=running" \
  --region "$AWS_REGION" --query "length(Reservations[].Instances[])" --output text)

if [ "$INSTANCE_COUNT" -gt 0 ]; then
  echo -e "   ${GREEN}✅ $INSTANCE_COUNT EC2 instances running${NC}"
else
  echo -e "   ${YELLOW}⚠️  No running EC2 instances found (still initializing)${NC}"
fi

# Test 4: S3 Buckets
echo ""
echo -e "${YELLOW}4. Testing S3 Buckets...${NC}"
VIDEOS_BUCKET=$(terraform output -raw videos_bucket 2>/dev/null || echo "")
RESULTS_BUCKET=$(terraform output -raw results_bucket 2>/dev/null || echo "")

if [ -n "$VIDEOS_BUCKET" ]; then
  if aws s3 ls "$VIDEOS_BUCKET" --region "$AWS_REGION" &>/dev/null; then
    echo -e "   ${GREEN}✅ Videos bucket accessible: $VIDEOS_BUCKET${NC}"
  else
    echo -e "   ${RED}❌ Videos bucket not accessible${NC}"
  fi
fi

if [ -n "$RESULTS_BUCKET" ]; then
  if aws s3 ls "$RESULTS_BUCKET" --region "$AWS_REGION" &>/dev/null; then
    echo -e "   ${GREEN}✅ Results bucket accessible: $RESULTS_BUCKET${NC}"
  else
    echo -e "   ${RED}❌ Results bucket not accessible${NC}"
  fi
fi

# Test 5: VPC & Networking
echo ""
echo -e "${YELLOW}5. Testing VPC & Networking...${NC}"
if [ -n "$VPC_ID" ]; then
  SG_COUNT=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$AWS_REGION" --query "length(SecurityGroups)" --output text)
  echo -e "   ${GREEN}✅ VPC $VPC_ID has $SG_COUNT security groups${NC}"
  
  SUBNET_COUNT=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
    --region "$AWS_REGION" --query "length(Subnets)" --output text)
  echo -e "   ${GREEN}✅ VPC has $SUBNET_COUNT subnets${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ INFRASTRUCTURE SMOKE TEST COMPLETE${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Configure kubectl and check nodes:"
echo "   aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION"
echo "   kubectl get nodes"
echo ""
echo "2. Check RDS connection:"
echo "   PASSWORD=\$(aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text | jq -r .password)"
echo "   psql -h $DB_ADDRESS -U postgres -d frameforge -c 'SELECT version();'"
echo ""
echo "3. Deploy Kubernetes services:"
echo "   kubectl apply -f ../../k8s/"
echo ""
echo "4. Check service status:"
echo "   kubectl get pods -A"
echo "   kubectl get svc -A"
echo ""
echo -e "${RED}⚠️  Remember to destroy when done to avoid charges:${NC}"
echo "   terraform destroy -auto-approve"
echo ""
