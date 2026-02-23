#!/bin/bash

# Script para configurar métricas customizadas dos serviços FrameForge
# Adiciona ServiceMonitors e dashboard no Grafana
# Uso: ./setup-metrics.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  FrameForge Metrics Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl not configured${NC}"
    echo -e "${YELLOW}Run: aws eks update-kubeconfig --name frameforge-dev --region us-east-1${NC}"
    exit 1
fi

# Check if monitoring namespace exists
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${RED}Error: Monitoring namespace not found${NC}"
    echo -e "${YELLOW}Run: ./install-monitoring.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"
echo ""

# Apply updated services with metrics ports
echo -e "${BLUE}1. Updating Services...${NC}"
kubectl apply -f ../k8s/services/api-gateway.yaml
kubectl apply -f ../k8s/services/auth-service.yaml
kubectl apply -f ../k8s/services/video-processor.yaml
kubectl apply -f ../k8s/services/notification-service.yaml
echo -e "${GREEN}✓ Services updated${NC}"
echo ""

# Apply updated deployments
echo -e "${BLUE}2. Updating Deployments...${NC}"
kubectl apply -f ../k8s/deployments/video-processor.yaml
kubectl apply -f ../k8s/deployments/notification-service.yaml
echo -e "${GREEN}✓ Deployments updated${NC}"
echo ""

# Apply ServiceMonitors
echo -e "${BLUE}3. Creating ServiceMonitors...${NC}"
kubectl apply -f ../k8s/monitoring/servicemonitor.yaml
echo -e "${GREEN}✓ ServiceMonitors created${NC}"
echo ""

# Wait for pods to restart
echo -e "${BLUE}4. Waiting for pods to restart...${NC}"
kubectl rollout status deployment/video-processor -n frameforge --timeout=120s
kubectl rollout status deployment/notification-service -n frameforge --timeout=120s
echo -e "${GREEN}✓ Pods restarted${NC}"
echo ""

# Import Grafana dashboard
echo -e "${BLUE}5. Importing Grafana Dashboard...${NC}"

# Check if Grafana is accessible
GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -z "$GRAFANA_POD" ]; then
    echo -e "${YELLOW}Warning: Grafana pod not found${NC}"
    echo -e "${YELLOW}Dashboard JSON available at: ../k8s/monitoring/grafana-dashboard.json${NC}"
else
    echo -e "${GREEN}✓ Grafana pod found: $GRAFANA_POD${NC}"
    echo ""
    echo -e "${YELLOW}To import dashboard manually:${NC}"
    echo "  1. Port-forward: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "  2. Login: http://localhost:3000 (admin / admin123)"
    echo "  3. Import dashboard from: frameforge-infrastructure/k8s/monitoring/grafana-dashboard.json"
    echo ""
fi

# Verify metrics are being scraped
echo -e "${BLUE}6. Verifying metrics collection...${NC}"
sleep 10

# Port-forward Prometheus temporarily
echo -e "${YELLOW}Port-forwarding Prometheus...${NC}"
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &
PF_PID=$!
sleep 5

# Check if metrics are available
echo -e "${BLUE}Checking metrics endpoints...${NC}"
for service in api-gateway auth-service video-processor notification-service; do
    echo -n "  - $service: "
    if curl -s http://localhost:9090/api/v1/targets 2>/dev/null | grep -q "$service"; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (may take a few minutes)${NC}"
    fi
done

# Kill port-forward
kill $PF_PID 2>/dev/null || true

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Access Grafana:"
echo "     kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "     http://localhost:3000 (admin / admin123)"
echo ""
echo "  2. Import Dashboard:"
echo "     - Go to: Dashboards → Import"
echo "     - Upload: frameforge-infrastructure/k8s/monitoring/grafana-dashboard.json"
echo ""
echo "  3. View Metrics:"
echo "     - Dashboard: \"FrameForge Services Metrics\""
echo ""
echo -e "${BLUE}Available Metrics:${NC}"
echo "  - API Gateway: HTTP requests, response times, upload counts"
echo "  - Auth Service: Login/registration rates, token validations"
echo "  - Video Processor: Jobs processed, processing duration, queue depth"
echo "  - Notification Service: Notifications sent, delivery rate, retry counts"
echo ""
echo -e "${YELLOW}Note: Metrics may take 1-2 minutes to appear in Prometheus${NC}"
echo ""
