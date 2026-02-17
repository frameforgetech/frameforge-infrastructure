# FrameForge - Quick Start Guide

Complete guide to run and test the FrameForge microservices platform locally.

## 📋 Prerequisites

- ✅ Docker Desktop installed and running
- ✅ Git installed
- ✅ Node.js 20+ installed (optional, for development)
- ✅ At least 4GB RAM available for Docker

## 🚀 Start the Platform

### 1. Navigate to Infrastructure

```bash
cd /mnt/c/pos/hack-soat11-dev/frameforge-infrastructure
```

### 2. Run Setup Script

```bash
chmod +x scripts/*.sh
./scripts/setup-local.sh
```

This will:
- ✅ Install dependencies for all services
- ✅ Build all services
- ✅ Start Docker Compose stack

### 3. Wait for Services (30-60 seconds)

Check status:
```bash
docker-compose ps
```

All services should show "Up" and "healthy" status.

## 🧪 Testing the Platform

### Test 1: Health Checks

```bash
# API Gateway
curl http://localhost:3000/health
# Expected: {"status":"ok","service":"api-gateway"}

# Auth Service
curl http://localhost:3001/health
# Expected: {"status":"ok","service":"auth-service"}
```

### Test 2: User Registration

```bash
curl -X POST http://localhost:3001/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john@example.com",
    "password": "SecurePass123!"
  }'
```

Expected response:
```json
{
  "userId": "uuid-here",
  "username": "johndoe",
  "email": "john@example.com",
  "createdAt": "2026-02-17T..."
}
```

### Test 3: User Login

```bash
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "password": "SecurePass123!"
  }'
```

Expected response:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 86400,
  "user": {
    "userId": "uuid-here",
    "username": "johndoe",
    "email": "john@example.com"
  }
}
```

### Test 4: Token Validation

```bash
# Use the token from login response
TOKEN="your-token-here"

curl -X POST http://localhost:3001/api/v1/auth/validate \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}"
```

Expected response:
```json
{
  "valid": true,
  "userId": "uuid-here",
  "username": "johndoe"
}
```

## 🌐 Web Interfaces

Open these URLs in your browser:

| Service | URL | Credentials |
|---------|-----|-------------|
| **API Gateway** | http://localhost:3000/health | - |
| **Auth Service** | http://localhost:3001/health | - |
| **MailHog** (Email UI) | http://localhost:8025 | - |
| **RabbitMQ** Management | http://localhost:15672 | frameforge / frameforge123 |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3002 | admin / admin |

## 📊 Monitoring

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f auth-service
docker-compose logs -f api-gateway
```

### Check Metrics

1. Open Prometheus: http://localhost:9090
2. Query examples:
   - `http_requests_total` - Total HTTP requests
   - `http_request_duration_seconds` - Request duration
   - `up` - Service availability

### Grafana Dashboards

1. Open Grafana: http://localhost:3002
2. Login: admin / admin
3. Add Prometheus data source: http://prometheus:9090
4. Create dashboards for your metrics

## 🛑 Stop Services

```bash
# Stop all services
./scripts/stop.sh

# Or manually
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

## 🔨 Rebuild Services

If you make code changes:

```bash
# Rebuild everything
./scripts/rebuild.sh

# Or rebuild specific service
docker-compose build auth-service
docker-compose up -d auth-service
```

## 🐛 Troubleshooting

### Port Already in Use

```bash
# Find what's using the port
lsof -i :3000  # or :3001, :5432, etc.

# Kill the process or change ports in docker-compose.yml
```

### Database Connection Errors

```bash
# Check postgres is running
docker-compose ps postgres

# View postgres logs
docker-compose logs postgres

# Restart postgres
docker-compose restart postgres
```

### Service Not Healthy

```bash
# Check service logs
docker-compose logs [service-name]

# Restart service
docker-compose restart [service-name]

# Force rebuild
docker-compose build --no-cache [service-name]
docker-compose up -d [service-name]
```

### Clean Start

```bash
# Stop everything
docker-compose down -v

# Remove all containers and images
docker system prune -a

# Start fresh
./scripts/setup-local.sh
```

## 📚 Next Steps

1. **Explore the APIs** - Use Postman or curl to test different endpoints
2. **Check Email Notifications** - Go to MailHog UI to see sent emails
3. **Monitor RabbitMQ** - See message queues in RabbitMQ management UI
4. **Create Video Jobs** - Use API Gateway to create video processing jobs
5. **View Metrics** - Set up Grafana dashboards for monitoring

## 🔗 Documentation

- [Infrastructure README](./README.md)
- [API Gateway](../frameforge-api-gateway/README.md)
- [Auth Service](../frameforge-auth-service/README.md)
- [Video Processor](../frameforge-video-processor/README.md)
- [Notification Service](../frameforge-notification-service/README.md)

## 💡 Tips

- Use **MailHog** to see all emails sent by the platform (no real SMTP needed)
- **RabbitMQ** management UI shows all message queues and their status
- **Prometheus** stores metrics for all services
- **Grafana** can visualize metrics with custom dashboards
- **Redis** is used for caching (access via redis-cli in container)

---

Need help? Check the logs first: `docker-compose logs -f`
