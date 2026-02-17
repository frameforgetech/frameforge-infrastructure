#!/bin/bash

echo "🔨 Rebuilding all services..."

cd "$(dirname "$0")/.."

echo "Building Docker images..."
docker-compose build --no-cache

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "Start services with:"
echo "  docker-compose up -d"
echo ""
