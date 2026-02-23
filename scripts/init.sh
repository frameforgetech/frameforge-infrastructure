#!/bin/bash

# FrameForge Infrastructure - Initialize Terraform
# This script initializes Terraform for all environments

set -e

echo "========================================="
echo "FrameForge - Terraform Initialization"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Function to initialize environment
init_environment() {
    local env=$1
    local env_dir="$TERRAFORM_DIR/environments/$env"
    
    if [ ! -d "$env_dir" ]; then
        echo -e "${RED}Error: Environment '$env' not found at $env_dir${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Initializing $env environment...${NC}"
    cd "$env_dir"
    
    # Initialize Terraform
    terraform init -upgrade
    
    # Validate configuration
    terraform validate
    
    echo -e "${GREEN}✓ $env environment initialized successfully${NC}"
    echo ""
}

# Check if specific environment provided
if [ $# -eq 1 ]; then
    init_environment "$1"
else
    # Initialize all environments
    echo "Initializing all environments..."
    echo ""
    
    for env_dir in "$TERRAFORM_DIR/environments"/*; do
        if [ -d "$env_dir" ]; then
            env_name=$(basename "$env_dir")
            init_environment "$env_name"
        fi
    done
fi

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Initialization Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Review variables: terraform/environments/dev/variables.tf"
echo "  2. Plan deployment: ./scripts/plan-dev.sh"
echo "  3. Apply infrastructure: ./scripts/apply-dev.sh"
echo ""
echo -e "${YELLOW}WARNING: EKS costs ~\$72/month. Destroy when not in use!${NC}"
echo ""
