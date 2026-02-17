#!/bin/bash

echo "🛑 Stopping FrameForge services..."

cd "$(dirname "$0")/.."

docker-compose down

echo ""
echo "✅ All services stopped"
echo ""
echo "To remove volumes as well, run:"
echo "  docker-compose down -v"
echo ""
