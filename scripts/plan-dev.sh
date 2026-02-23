#!/bin/bash

# FrameForge Infrastructure - Plan Dev Environment
# Shows what will be created/modified without applying changes

set -e

echo "========================================="
echo "FrameForge - Terraform Plan (Dev)"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEV_DIR="$SCRIPT_DIR/../terraform/environments/dev"

cd "$DEV_DIR"

echo -e "${GREEN}Running Terraform plan for dev environment...${NC}"
echo ""

# Run plan and save to file
terraform plan -out=tfplan

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Plan Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Review the plan above. To apply:"
echo "  ./scripts/apply-dev.sh"
echo ""
echo -e "${YELLOW}Estimated monthly cost: ~\$110-130${NC}"
echo -e "${YELLOW}  - EKS Control Plane: \$72${NC}"
echo -e "${YELLOW}  - NAT Gateway: \$32${NC}"
echo -e "${YELLOW}  - EC2 (2x t3.small): \$20-30${NC}"
echo -e "${YELLOW}  - RDS (db.t3.micro): Free tier (first 12 months)${NC}"
echo ""
