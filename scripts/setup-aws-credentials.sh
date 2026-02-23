#!/bin/bash

# Setup AWS Credentials Securely
# This script helps configure AWS credentials in the safest way

set -e

echo "=========================================="
echo "AWS Credentials Setup (Secure)"
echo "=========================================="
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
  echo "❌ AWS CLI not found. Install it first:"
  echo "  On macOS: brew install awscli"
  echo "  On Linux: apt-get install awscli"
  echo "  On Windows: Download from https://aws.amazon.com/cli/"
  exit 1
fi

# Check if credentials are already configured
if [ -f ~/.aws/credentials ]; then
  echo "✅ AWS credentials file found at ~/.aws/credentials"
  echo ""
  echo "Current profiles:"
  grep "^\[" ~/.aws/credentials
  echo ""
  
  read -p "Reconfigure? (yes/no): " reconfigure
  if [ "$reconfigure" != "yes" ]; then
    echo "Using existing credentials."
    aws sts get-caller-identity
    exit 0
  fi
fi

echo "Choose setup method:"
echo "1. Interactive (aws configure)"
echo "2. Manual (paste credentials)"
echo ""
read -p "Select (1 or 2): " method

if [ "$method" = "1" ]; then
  echo ""
  echo "Running: aws configure"
  echo "You'll be asked for:"
  echo "  • AWS Access Key ID: AKIA..."
  echo "  • AWS Secret Access Key: (paste your key)"
  echo "  • Default region: us-east-1"
  echo "  • Default output format: json"
  echo ""
  
  aws configure
  
elif [ "$method" = "2" ]; then
  echo ""
  read -p "Enter AWS Access Key ID: " access_key
  read -sp "Enter AWS Secret Access Key: " secret_key
  echo ""
  read -p "Enter region (default: us-east-1): " region
  region=${region:-us-east-1}
  
  # Create ~/.aws directory if it doesn't exist
  mkdir -p ~/.aws
  
  # Save credentials
  cat >> ~/.aws/credentials << EOF

[default]
aws_access_key_id = $access_key
aws_secret_access_key = $secret_key
EOF
  
  # Save region config
  cat >> ~/.aws/config << EOF

[default]
region = $region
output = json
EOF
  
  chmod 600 ~/.aws/credentials
  chmod 600 ~/.aws/config
  
  echo "✅ Credentials configured!"
else
  echo "❌ Invalid option"
  exit 1
fi

# Verify credentials
echo ""
echo "Verifying credentials..."
IDENTITY=$(aws sts get-caller-identity)

if [ $? -eq 0 ]; then
  echo "✅ Credentials are valid!"
  echo ""
  echo "Account Info:"
  echo "$IDENTITY" | jq .
  echo ""
  echo "Your credentials are now securely stored in: ~/.aws/credentials"
  echo ""
  echo "FrameForge deployment commands can now be run:"
  echo "  cd frameforge-infrastructure/scripts"
  echo "  ./apply-dev.sh"
else
  echo "❌ Credentials verification failed"
  exit 1
fi
