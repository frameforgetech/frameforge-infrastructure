#!/bin/bash

# Script para acessar RabbitMQ Management UI via kubectl tunnel
# Uso: ./access-rabbitmq.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  RabbitMQ Management UI Access${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl not installed${NC}"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not installed${NC}"
    exit 1
fi

# Get RabbitMQ instance private IP
echo -e "${BLUE}Finding RabbitMQ EC2 instance...${NC}"
INSTANCE_IP=$(aws ec2 describe-instances \
    --filters \
        "Name=tag:Name,Values=frameforge-rabbitmq-dev" \
        "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text 2>/dev/null || echo "")

if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "None" ]; then
    echo -e "${RED}Error: RabbitMQ instance not found or not running${NC}"
    echo -e "${YELLOW}Make sure your infrastructure is deployed and running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found RabbitMQ at: $INSTANCE_IP${NC}"
echo ""

# Check if tunnel pod already exists
echo -e "${BLUE}Checking for existing tunnel pod...${NC}"
EXISTING_POD=$(kubectl get pod rabbitmq-tunnel -n frameforge --ignore-not-found -o name 2>/dev/null || echo "")

if [ -n "$EXISTING_POD" ]; then
    echo -e "${YELLOW}Cleaning up existing tunnel pod...${NC}"
    kubectl delete pod rabbitmq-tunnel -n frameforge --ignore-not-found
    sleep 2
fi

# Create tunnel pod
echo -e "${BLUE}Creating tunnel pod...${NC}"
kubectl run rabbitmq-tunnel \
    --image=alpine/socat \
    --restart=Never \
    -n frameforge \
    -- -d tcp-listen:15672,fork,reuseaddr tcp-connect:${INSTANCE_IP}:15672

# Wait for pod to be ready
echo -e "${BLUE}Waiting for tunnel pod to be ready...${NC}"
kubectl wait --for=condition=Ready pod/rabbitmq-tunnel -n frameforge --timeout=30s

echo -e "${GREEN}✓ Tunnel pod created${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    kubectl delete pod rabbitmq-tunnel -n frameforge --ignore-not-found
    echo -e "${GREEN}✓ Cleanup complete${NC}"
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start port forwarding
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Starting Port Forwarding...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Management UI:${NC} http://localhost:15672"
echo -e "${BLUE}Username:${NC} frameforge"
echo -e "${BLUE}Password:${NC} frameforge123"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Start port-forward
kubectl port-forward -n frameforge pod/rabbitmq-tunnel 15672:15672
