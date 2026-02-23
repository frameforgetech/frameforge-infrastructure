#!/bin/bash

# FrameForge Infrastructure - DESTROY Dev Environment
# ⚠️  WARNING: This will DELETE ALL infrastructure and data!

set -e

echo "========================================="
echo "FrameForge - DESTROY Dev Environment"
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

# Show warning
echo -e "${RED}⚠️  DANGER ZONE ⚠️${NC}"
echo -e "${RED}This will permanently delete:${NC}"
echo -e "${RED}  • VPC and all networking${NC}"
echo -e "${RED}  • RDS database (all data will be lost)${NC}"
echo -e "${RED}  • S3 buckets (all videos and results)${NC}"
echo -e "${RED}  • EC2 instances (RabbitMQ, Redis)${NC}"
echo -e "${RED}  • EKS cluster and all workloads${NC}"
echo ""
echo -e "${YELLOW}💾 Make sure you have backups if needed!${NC}"
echo ""
echo "Type 'yes' to confirm destruction, or anything else to cancel:"
read -p "> " confirm

if [ "$confirm" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Double confirmation required!${NC}"
echo "Type 'destroy' to proceed:"
read -p "> " confirm2

if [ "$confirm2" != "destroy" ]; then
    echo "Destruction cancelled."
    exit 0
fi

echo ""
echo -e "${RED}Destroying infrastructure...${NC}"
echo ""

# Get variables from terraform
REGION=$(grep -E '^\s*region\s*=' terraform.tfvars | cut -d'"' -f2 || echo "us-east-1")
CLUSTER_NAME=$(grep -E '^\s*cluster_name\s*=' terraform.tfvars | cut -d'"' -f2 || echo "frameforge-dev")
PROJECT_PREFIX=$(grep -E '^\s*project_prefix\s*=' terraform.tfvars | cut -d'"' -f2 || echo "tharlysdias-frameforge")

echo -e "${YELLOW}🧹 Pre-cleanup: Removing Kubernetes-created resources...${NC}"
echo ""

# 1. Delete Load Balancers created by Kubernetes
echo -e "${YELLOW}→ Checking for Load Balancers...${NC}"
LBS=$(aws elbv2 describe-load-balancers --region "$REGION" 2>/dev/null | \
      jq -r '.LoadBalancers[].LoadBalancerArn' || echo "")

if [ -n "$LBS" ]; then
    for lb_arn in $LBS; do
        echo "  Deleting Load Balancer: $lb_arn"
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION" 2>/dev/null || true
    done
    echo "  ⏳ Waiting 10s for ENI release..."
    sleep 10
else
    echo "  ✓ No Load Balancers found"
fi

# 2. Delete EKS Node Groups
echo -e "${YELLOW}→ Checking for EKS Node Groups...${NC}"
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null | \
              jq -r '.nodegroups[]' || echo "")

if [ -n "$NODE_GROUPS" ]; then
    for ng in $NODE_GROUPS; do
        echo "  Deleting Node Group: $ng"
        aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$REGION" 2>/dev/null || true
    done
    
    # Wait for node groups to be deleted
    for ng in $NODE_GROUPS; do
        echo "  ⏳ Waiting for Node Group deletion: $ng"
        aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$REGION" 2>/dev/null || true
    done
    echo "  ✓ Node Groups deleted"
else
    echo "  ✓ No Node Groups found"
fi

# 3. Empty S3 Buckets (including all versions and delete markers)
echo -e "${YELLOW}→ Emptying S3 Buckets...${NC}"
VIDEOS_BUCKET="${PROJECT_PREFIX}-videos-dev"
RESULTS_BUCKET="${PROJECT_PREFIX}-results-dev"

for bucket in "$VIDEOS_BUCKET" "$RESULTS_BUCKET"; do
    if aws s3 ls "s3://$bucket" --region "$REGION" 2>/dev/null; then
        echo "  Emptying bucket: $bucket"
        
        # Delete all versions and delete markers
        aws s3api list-object-versions --bucket "$bucket" --region "$REGION" --output json 2>/dev/null | \
        jq '{Objects: [.Versions[]?, .DeleteMarkers[]?] | map({Key: .Key, VersionId: .VersionId})}' > /tmp/delete-${bucket}.json 2>/dev/null || true
        
        if [ -f /tmp/delete-${bucket}.json ] && [ "$(cat /tmp/delete-${bucket}.json | jq '.Objects | length')" -gt 0 ]; then
            aws s3api delete-objects --bucket "$bucket" --delete "file:///tmp/delete-${bucket}.json" --region "$REGION" 2>/dev/null || true
            echo "    ✓ Deleted all versions from $bucket"
        fi
        
        rm -f /tmp/delete-${bucket}.json
    else
        echo "  ✓ Bucket $bucket not found or already deleted"
    fi
done

echo ""
echo -e "${GREEN}✓ Pre-cleanup complete${NC}"
echo ""

# Destroy Terraform infrastructure (with refresh=false to avoid reading deleted resources)
echo -e "${YELLOW}Running terraform destroy...${NC}"
terraform destroy -auto-approve -refresh=false

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Infrastructure Destroyed!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${GREEN}✓ All resources deleted${NC}"
echo -e "${GREEN}✓ No more AWS charges from this environment${NC}"
echo ""
echo "You can recreate the infrastructure anytime with:"
echo "  ./scripts/apply-dev.sh"
echo ""
