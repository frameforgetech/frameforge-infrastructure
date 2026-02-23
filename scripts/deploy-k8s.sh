#!/bin/bash

# FrameForge - Deploy to Kubernetes
# This script deploys all services to EKS

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR="$SCRIPT_DIR/../k8s"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform/environments/dev"

echo "========================================="
echo "FrameForge - Deploy to Kubernetes"
echo "========================================="
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}Error: kubectl not configured${NC}"
    echo "Run: aws eks update-kubeconfig --name frameforge-dev --region us-east-1"
    exit 1
fi

echo -e "${GREEN}✓ kubectl configured${NC}"
echo ""

# Check if infrastructure exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform infrastructure not found${NC}"
    echo "Run: ./apply-dev.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Terraform infrastructure found${NC}"
echo ""

# Get values from Terraform
echo -e "${BLUE}Gathering infrastructure details...${NC}"
cd "$TERRAFORM_DIR"

DB_HOST=$(terraform output -raw db_address 2>/dev/null || echo "")
DB_SECRET_ARN=$(terraform output -raw db_secret_arn 2>/dev/null || echo "")
RABBITMQ_HOST=$(terraform output -raw rabbitmq_private_ip 2>/dev/null || echo "")
REDIS_HOST=$(terraform output -raw redis_private_ip 2>/dev/null || echo "")
S3_VIDEOS=$(terraform output -raw videos_bucket 2>/dev/null || echo "")
S3_RESULTS=$(terraform output -raw results_bucket 2>/dev/null || echo "")
IRSA_ROLE_ARN=$(terraform output -raw eks_api_gateway_sa_role_arn 2>/dev/null || echo "")

if [ -z "$DB_HOST" ] || [ -z "$RABBITMQ_HOST" ]; then
    echo -e "${RED}Error: Could not get infrastructure details from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Infrastructure details gathered${NC}"
echo "  DB: $DB_HOST"
echo "  RabbitMQ: $RABBITMQ_HOST"
echo "  Redis: $REDIS_HOST"
echo "  S3 Videos: $S3_VIDEOS"
echo "  S3 Results: $S3_RESULTS"
echo "  IRSA Role: $IRSA_ROLE_ARN"
echo ""

# Get DB password from Secrets Manager
echo -e "${BLUE}Retrieving database password from AWS Secrets Manager...${NC}"
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text 2>/dev/null | jq -r .password 2>/dev/null || echo "")

if [ -z "$DB_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: Could not retrieve DB password automatically${NC}"
    read -sp "Enter database password: " DB_PASSWORD
    echo ""
fi

echo -e "${GREEN}✓ Database password retrieved${NC}"
echo ""

# Deploy namespace
echo -e "${BLUE}Creating namespace...${NC}"
kubectl apply -f "$K8S_DIR/namespace.yaml"
echo ""

# Deploy ConfigMap
echo -e "${BLUE}Creating ConfigMap...${NC}"
kubectl apply -f "$K8S_DIR/configmap.yaml"
echo ""

# Create ServiceAccount with dynamic IRSA annotation
echo -e "${BLUE}Creating ServiceAccount with IRSA...${NC}"
if [ -n "$IRSA_ROLE_ARN" ]; then
    echo "Annotating service account with IAM role: $IRSA_ROLE_ARN"
    kubectl apply -f "$K8S_DIR/serviceaccount.yaml"
    kubectl annotate serviceaccount frameforge-sa \
        -n frameforge \
        eks.amazonaws.com/role-arn="$IRSA_ROLE_ARN" \
        --overwrite
    echo -e "${GREEN}✓ ServiceAccount annotated with IRSA role${NC}"
else
    echo -e "${YELLOW}Warning: IRSA role ARN not found, applying without annotation${NC}"
    kubectl apply -f "$K8S_DIR/serviceaccount.yaml"
fi
echo ""

# Create secrets
echo -e "${BLUE}Creating secrets...${NC}"

# Check if secret already exists
if kubectl get secret frameforge-secrets -n frameforge &>/dev/null; then
    echo -e "${YELLOW}Secret already exists. Delete it? (yes/no)${NC}"
    read -p "> " delete_secret
    if [ "$delete_secret" = "yes" ]; then
        kubectl delete secret frameforge-secrets -n frameforge
    else
        echo "Skipping secret creation"
    fi
fi

if ! kubectl get secret frameforge-secrets -n frameforge &>/dev/null; then
    # Generate JWT secret if not provided
    JWT_SECRET=${JWT_SECRET:-$(openssl rand -base64 32)}
    
    # Construct connection URLs
    REDIS_URL="redis://${REDIS_HOST}:6379"
    RABBITMQ_URL="amqp://frameforge:frameforge123@${RABBITMQ_HOST}:5672"
    
    kubectl create secret generic frameforge-secrets \
      --namespace=frameforge \
      --from-literal=jwt-secret="$JWT_SECRET" \
      --from-literal=db-user='frameforge_admin' \
      --from-literal=db-password="$DB_PASSWORD" \
      --from-literal=db-host="$DB_HOST" \
      --from-literal=rabbitmq-user='frameforge' \
      --from-literal=rabbitmq-password='frameforge123' \
      --from-literal=rabbitmq-host="$RABBITMQ_HOST" \
      --from-literal=rabbitmq-url="$RABBITMQ_URL" \
      --from-literal=redis-host="$REDIS_HOST" \
      --from-literal=redis-password='' \
      --from-literal=redis-url="$REDIS_URL" \
      --from-literal=aws-access-key-id='' \
      --from-literal=aws-secret-access-key='' \
      --from-literal=aws-region='us-east-1' \
      --from-literal=s3-videos-bucket="$S3_VIDEOS" \
      --from-literal=s3-results-bucket="$S3_RESULTS"
    
    echo -e "${GREEN}✓ Secrets created${NC}"
fi
echo ""

# Deploy all services
echo -e "${BLUE}Deploying services...${NC}"
kubectl apply -f "$K8S_DIR/deployments/"
echo ""

echo -e "${BLUE}Creating services...${NC}"
kubectl apply -f "$K8S_DIR/services/"
echo ""

echo -e "${BLUE}Creating Horizontal Pod Autoscalers...${NC}"
kubectl apply -f "$K8S_DIR/hpa/"
echo ""

# Wait for deployments
echo -e "${BLUE}Waiting for deployments to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment --all -n frameforge || true
echo ""

# Show status
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Deployment Summary${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

echo "Pods:"
kubectl get pods -n frameforge
echo ""

echo "Services:"
kubectl get svc -n frameforge
echo ""

echo "HPAs:"
kubectl get hpa -n frameforge
echo ""

# Get LoadBalancer URL
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}API Gateway URL${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

LB_HOSTNAME=$(kubectl get svc api-gateway -n frameforge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -n "$LB_HOSTNAME" ]; then
    echo -e "${GREEN}LoadBalancer URL: http://$LB_HOSTNAME${NC}"
    echo ""
    echo "Test with:"
    echo "  curl http://$LB_HOSTNAME/health"
else
    echo -e "${YELLOW}LoadBalancer still provisioning...${NC}"
    echo "Check status with:"
    echo "  kubectl get svc api-gateway -n frameforge -w"
fi

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Next Steps${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "1. Wait for LoadBalancer:"
echo "   kubectl get svc api-gateway -n frameforge -w"
echo ""
echo "2. Monitor pods:"
echo "   kubectl get pods -n frameforge -w"
echo ""
echo "3. Check logs:"
echo "   kubectl logs -n frameforge -l app=api-gateway --tail=50 -f"
echo ""
echo "4. Test API:"
echo "   curl http://\$LB_URL/health"
echo ""
echo -e "${YELLOW}Remember to destroy infrastructure when done: ./destroy-dev.sh${NC}"
echo ""
