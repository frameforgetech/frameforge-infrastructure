#!/bin/bash

# Script para instalar Grafana + Prometheus no Kubernetes
# Uso: ./install-monitoring.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Monitoring Stack Installation${NC}"
echo -e "${BLUE}  Prometheus + Grafana${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: Helm not installed${NC}"
    echo -e "${YELLOW}Install: curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash${NC}"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl not configured${NC}"
    echo -e "${YELLOW}Run: aws eks update-kubeconfig --name frameforge-dev --region us-east-1${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Add Helm repositories
echo -e "${BLUE}Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo -e "${GREEN}✓ Repositories added${NC}"
echo ""

# Check if already installed
if helm list -n monitoring | grep -q prometheus; then
    echo -e "${YELLOW}Prometheus stack already installed${NC}"
    echo -e "${YELLOW}Upgrade? (yes/no)${NC}"
    read -p "> " upgrade
    if [ "$upgrade" = "yes" ]; then
        echo -e "${BLUE}Upgrading...${NC}"
        helm upgrade prometheus prometheus-community/kube-prometheus-stack \
            -n monitoring \
            --set grafana.adminPassword=admin123 \
            --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
        echo -e "${GREEN}✓ Upgraded${NC}"
    fi
else
    # Install Prometheus + Grafana
    echo -e "${BLUE}Installing Prometheus + Grafana stack...${NC}"
    helm install prometheus prometheus-community/kube-prometheus-stack \
        -n monitoring \
        --create-namespace \
        --set grafana.adminPassword=admin123 \
        --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
    
    echo ""
    echo -e "${GREEN}✓ Monitoring stack installed${NC}"
fi

echo ""
echo -e "${BLUE}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
echo -e "${GREEN}✓ Grafana is ready${NC}"
echo ""

# Get Grafana pod name
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}")

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Access Grafana:${NC}"
echo "  1. Port-forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  2. Open: http://localhost:3000"
echo "  3. Login: admin / admin123"
echo ""
echo -e "${BLUE}Access Prometheus:${NC}"
echo "  1. Port-forward: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  2. Open: http://localhost:9090"
echo ""
echo -e "${YELLOW}Quick Start Port-Forward:${NC}"
echo ""

# Ask if user wants to start port-forward
read -p "Start Grafana port-forward now? (yes/no): " start_pf
if [ "$start_pf" = "yes" ]; then
    echo ""
    echo -e "${GREEN}Starting port-forward...${NC}"
    echo -e "${BLUE}Access: http://localhost:3000${NC}"
    echo -e "${BLUE}Login: admin / admin123${NC}"
    echo ""
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    echo ""
    kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
fi
