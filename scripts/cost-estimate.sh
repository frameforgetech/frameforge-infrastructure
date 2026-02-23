#!/bin/bash

# FrameForge Infrastructure - Cost Estimation
# Estimates monthly AWS costs for the infrastructure

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================="
echo "FrameForge - Cost Estimation (Dev)"
echo "========================================="
echo ""

echo -e "${BLUE}Base Infrastructure Costs (Running 24/7):${NC}"
echo ""

# EKS
echo -e "${RED}EKS Control Plane:${NC}"
echo "  - Cost: \$0.10/hour = \$72/month"
echo "  - Note: NOT free tier eligible"
echo ""

# NAT Gateway
echo -e "${RED}NAT Gateway:${NC}"
echo "  - Cost: \$0.045/hour = \$32.40/month"
echo "  - Data processing: \$0.045/GB"
echo "  - Est. total: \$35-45/month (with moderate traffic)"
echo ""

# EC2 for RabbitMQ and Redis
echo -e "${YELLOW}EC2 Instances (2x t3.small):${NC}"
echo "  - RabbitMQ: \$0.0208/hour = \$15/month"
echo "  - Redis: \$0.0208/hour = \$15/month"
echo "  - Total: \$30/month"
echo "  - Note: t3.micro available in free tier but may be too small"
echo ""

# RDS
echo -e "${GREEN}RDS PostgreSQL (db.t3.micro):${NC}"
echo "  - Cost: \$0.016/hour = \$11.52/month"
echo "  - Storage (20GB): \$2.30/month"
echo "  - Backups: Free up to DB size"
echo "  - Total: \$14/month"
echo "  - Note: FREE for first 12 months (750 hours/month)"
echo ""

# EKS Nodes
echo -e "${YELLOW}EKS Worker Nodes (2x t3.small):${NC}"
echo "  - Cost per node: \$0.0208/hour = \$15/month"
echo "  - 2 nodes: \$30/month"
echo "  - 4 nodes (max): \$60/month"
echo ""

# S3
echo -e "${GREEN}S3 Storage:${NC}"
echo "  - First 5GB: FREE"
echo "  - Additional: \$0.023/GB/month"
echo "  - Lifecycle rules clean up after 30 days"
echo "  - Est. total: \$0-5/month"
echo ""

# CloudWatch
echo -e "${BLUE}CloudWatch Logs:${NC}"
echo "  - Ingestion: \$0.50/GB"
echo "  - Storage: \$0.03/GB/month"
echo "  - Est. total: \$3-10/month"
echo ""

# Data Transfer
echo -e "${BLUE}Data Transfer:${NC}"
echo "  - Out to internet: \$0.09/GB (after 1GB free)"
echo "  - Est. total: \$5-20/month (depends on usage)"
echo ""

echo "========================================="
echo -e "${RED}TOTAL MONTHLY COST ESTIMATES:${NC}"
echo "========================================="
echo ""
echo -e "${GREEN}Minimum (dev, low usage, free tier RDS):${NC}"
echo "  \$72 (EKS) + \$35 (NAT) + \$30 (EC2) + \$30 (EKS nodes) + \$5 (misc)"
echo -e "  ${GREEN}≈ \$172/month${NC}"
echo ""
echo -e "${YELLOW}Typical (dev, moderate usage, free tier RDS):${NC}"
echo "  \$72 (EKS) + \$40 (NAT) + \$30 (EC2) + \$30 (EKS nodes) + \$15 (misc)"
echo -e "  ${YELLOW}≈ \$187/month${NC}"
echo ""
echo -e "${RED}After free tier ends (RDS included):${NC}"
echo "  \$72 (EKS) + \$40 (NAT) + \$30 (EC2) + \$14 (RDS) + \$30 (EKS nodes) + \$15 (misc)"
echo -e "  ${RED}≈ \$201/month${NC}"
echo ""

echo "========================================="
echo -e "${RED}💰 COST OPTIMIZATION TIPS:${NC}"
echo "========================================="
echo ""
echo "1. Destroy when not in use:"
echo "   ./scripts/destroy-dev.sh"
echo ""
echo "2. Use shorter testing windows:"
echo "   - Deploy for 8 hours/day: \$60/month savings"
echo "   - Deploy only on weekdays: \$100/month savings"
echo ""
echo "3. Consider alternatives:"
echo "   - Use local minikube/kind for development"
echo "   - Only deploy to AWS for production testing"
echo "   - Use AWS Fargate instead of EKS (ECS Fargate)"
echo ""
echo "4. Reduce node count:"
echo "   - Start with 1 node instead of 2"
echo "   - Use spot instances (60-90% discount)"
echo ""
echo "5. Optimize NAT Gateway:"
echo "   - Use NAT instances instead (t3.nano = \$3/month)"
echo "   - Or deploy services in public subnets (less secure)"
echo ""
echo -e "${YELLOW}⚠️  With \$100 budget, you have ~15-20 days of uptime/month${NC}"
echo -e "${RED}⚠️  ALWAYS destroy when finished testing!${NC}"
echo ""
