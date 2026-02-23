#!/bin/bash

# FrameForge Infrastructure - Get Outputs
# Shows important connection strings and IPs

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEV_DIR="$SCRIPT_DIR/../terraform/environments/dev"

cd "$DEV_DIR"

echo "========================================="
echo "FrameForge - Infrastructure Outputs"
echo "========================================="
echo ""

# Check if infrastructure exists
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${YELLOW}No infrastructure found. Deploy first:${NC}"
    echo "  ./scripts/apply-dev.sh"
    exit 0
fi

echo -e "${BLUE}VPC Information:${NC}"
echo "  VPC ID: $(terraform output -raw vpc_id 2>/dev/null || echo 'N/A')"
echo ""

echo -e "${BLUE}S3 Buckets:${NC}"
echo "  Videos: $(terraform output -raw videos_bucket 2>/dev/null || echo 'N/A')"
echo "  Results: $(terraform output -raw results_bucket 2>/dev/null || echo 'N/A')"
echo ""

echo -e "${BLUE}Database (RDS):${NC}"
echo "  Address: $(terraform output -raw db_address 2>/dev/null || echo 'N/A')"
echo "  Secret ARN: $(terraform output -raw db_secret_arn 2>/dev/null || echo 'N/A')"
echo ""

echo -e "${BLUE}Message Queue:${NC}"
echo "  RabbitMQ IP: $(terraform output -raw rabbitmq_private_ip 2>/dev/null || echo 'N/A')"
echo ""

echo -e "${BLUE}Cache:${NC}"
echo "  Redis IP: $(terraform output -raw redis_private_ip 2>/dev/null || echo 'N/A')"
echo ""

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Connection Commands:${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

DB_SECRET_ARN=$(terraform output -raw db_secret_arn 2>/dev/null || echo "")
if [ -n "$DB_SECRET_ARN" ]; then
    echo "Get database password:"
    echo "  aws secretsmanager get-secret-value --secret-id $DB_SECRET_ARN --query SecretString --output text | jq -r .password"
    echo ""
fi

RABBITMQ_IP=$(terraform output -raw rabbitmq_private_ip 2>/dev/null || echo "")
if [ -n "$RABBITMQ_IP" ]; then
    echo "RabbitMQ Management UI (via SSH tunnel):"
    echo "  ssh -L 15672:$RABBITMQ_IP:15672 ec2-user@BASTION_IP"
    echo "  Then open: http://localhost:15672"
    echo "  User: frameforge / Pass: frameforge123"
    echo ""
fi

echo -e "${YELLOW}Full outputs:${NC}"
terraform output

echo ""
