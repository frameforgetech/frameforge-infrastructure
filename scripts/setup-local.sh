#!/bin/bash

set -e

echo "🚀 Setting up FrameForge local development environment..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker and try again."
  exit 1
fi

echo "✅ Docker is running"
echo ""

# Navigate to infrastructure directory
cd "$(dirname "$0")/.."

# Check if all service directories exist
echo "📁 Checking service directories..."
services=(
  "frameforge-shared-contracts"
  "frameforge-auth-service"
  "frameforge-api-gateway"
  "frameforge-video-processor"
  "frameforge-notification-service"
)

for service in "${services[@]}"; do
  if [ ! -d "../$service" ]; then
    echo "❌ Directory ../$service not found"
    exit 1
  fi
  echo "  ✓ $service"
done

echo ""
echo "📦 Installing dependencies for all services..."
for service in "${services[@]}"; do
  if [ -f "../$service/package.json" ]; then
    echo "  Installing $service..."
    (cd "../$service" && npm install --silent > /dev/null 2>&1)
  fi
done

echo ""
echo "🏗️  Building all services..."
for service in "${services[@]}"; do
  if [ -f "../$service/package.json" ]; then
    echo "  Building $service..."
    (cd "../$service" && npm run build > /dev/null 2>&1)
  fi
done

echo ""
echo "🐳 Starting Docker Compose services..."
docker-compose up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

echo ""
echo "✅ Setup complete!"
echo ""
echo "📊 Access the services:"
echo "   🌐 API Gateway:    http://localhost:3000"
echo "   🔐 Auth Service:   http://localhost:3001"
echo "   📧 MailHog UI:     http://localhost:8025"
echo "   🐰 RabbitMQ UI:    http://localhost:15672 (frameforge/frameforge123)"
echo "   📈 Prometheus:     http://localhost:9090"
echo "   📊 Grafana:        http://localhost:3002 (admin/admin)"
echo "   🗄️  PostgreSQL:     localhost:5432 (frameforge/frameforge123)"
echo "   💾 Redis:          localhost:6379"
echo ""
echo "📝 View logs:"
echo "   docker-compose logs -f [service-name]"
echo ""
echo "🛑 Stop services:"
echo "   docker-compose down"
echo ""
