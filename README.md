# FrameForge Infrastructure

Infraestrutura compartilhada, orquestração e documentação para a plataforma de microsserviços FrameForge.

## 📁 Estrutura

```
frameforge-infrastructure/
├── docker-compose.yml          # Stack completo para desenvolvimento local
├── init-db.sh                  # Script de inicialização do banco
├── .github/                    # Workflows de CI/CD
│   └── workflows/
├── docs/                       # 📚 Documentação completa do projeto
│   ├── ARCHITECTURE_DECISION.md
│   ├── ARCHITECTURE_DIAGRAM.md
│   ├── TECHNICAL_DECISIONS.md
│   ├── IMPLEMENTATION_STRATEGY.md
│   ├── REPOSITORY_STRATEGY.md
│   ├── RESUMO_EXECUTIVO.md
│   └── DOCUMENTATION_INDEX.md
├── monitoring/                 # Configuração Prometheus/Grafana
│   └── prometheus.yml
├── docker/                     # Dockerfiles base compartilhados
│   ├── base.Dockerfile
│   └── processor-base.Dockerfile
├── terraform/                  # Infrastructure as Code (TODO)
│   ├── modules/
│   ├── environments/
│   └── README.md
├── k8s/                        # Kubernetes manifests (TODO)
│   ├── base/
│   ├── overlays/
│   └── README.md
└── scripts/                    # Scripts de automação
    ├── setup-local.sh
    └── init-db.sh
```

## 📊 Service Access

| Service | URL | Credentials |
|---------|-----|-------------|
| **API Gateway** | http://localhost:3000 | - |
| **Auth Service** | http://localhost:3001 | - |
| **MailHog UI** | http://localhost:8025 | - |
| **RabbitMQ UI** | http://localhost:15672 | frameforge / frameforge123 |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3002 | admin / admin |
| **PostgreSQL** | localhost:5432 | frameforge / frameforge123 |
| **Redis** | localhost:6379 | - |

## 🏗️ Architecture

```
┌─────────────────┐
│   API Gateway   │ :3000
│   (Express)     │
└────────┬────────┘
         │
    ┌────┴─────┬──────────┬────────────┐
    │          │          │            │
┌───▼───┐  ┌──▼──┐   ┌───▼────┐  ┌───▼────┐
│ Auth  │  │Redis│   │RabbitMQ│  │Postgres│
│Service│  └─────┘   └────┬───┘  └────────┘
└───────┘                 │
    :3001           ┌─────┴──────┐
                    │            │
              ┌─────▼──┐   ┌────▼─────┐
              │ Video  │   │Notification│
              │Processor   │  Service  │
              └────────┘   └───────────┘
```

## 📁 Project Structure

```
frameforge-infrastructure/
├── docker-compose.yml          # Main orchestration file
├── monitoring/
│   └── prometheus.yml          # Prometheus configuration
├── scripts/
│   ├── setup-local.sh         # Setup script
│   ├── stop.sh                # Stop services
│   └── rebuild.sh             # Rebuild images
└── README.md
```

## 🐳 Docker Services

### Core Services
- **postgres** - PostgreSQL 15 database
- **redis** - Redis 7 cache
- **rabbitmq** - RabbitMQ 3 message broker

### Application Services
- **auth-service** - Authentication & JWT management
- **api-gateway** - Main API gateway
- **video-processor** - Video frame extraction worker
- **notification-service** - Email notification worker

### Monitoring & Tools
- **prometheus** - Metrics collection
- **grafana** - Metrics visualization
- **mailhog** - Email testing tool

## 🔧 Useful Commands

```bash
# View logs for specific service
docker-compose logs -f auth-service

# Restart a service
docker-compose restart api-gateway

# Check service status
docker-compose ps

# Execute command in container
docker-compose exec postgres psql -U frameforge

# Clean everything (including volumes)
docker-compose down -v
docker system prune -a

# Rebuild single service
docker-compose build auth-service
docker-compose up -d auth-service
```

## 🧪 Testing the Setup

### 1. Check Services Health

```bash
# API Gateway
curl http://localhost:3000/health

# Auth Service
curl http://localhost:3001/health
```

### 2. Register a User

```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "Test123!"
  }'
```

### 3. Login

```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "password": "Test123!"
  }'
```

### 4. Check Metrics

Visit http://localhost:9090 (Prometheus) or http://localhost:3002 (Grafana)

## 📚 Additional Documentation

- [API Gateway Documentation](../frameforge-api-gateway/README.md)
- [Auth Service Documentation](../frameforge-auth-service/README.md)
- [Video Processor Documentation](../frameforge-video-processor/README.md)
- [Notification Service Documentation](../frameforge-notification-service/README.md)
- [Shared Contracts Documentation](../frameforge-shared-contracts/README.md)

## 🐛 Troubleshooting

### Services won't start

```bash
# Check Docker resources
docker system df

# Clean up
docker system prune -a
docker volume prune
```

### Database connection errors

```bash
# Check postgres logs
docker-compose logs postgres

# Restart postgres
docker-compose restart postgres

# Connect to database
docker-compose exec postgres psql -U frameforge
```

### Port conflicts

If ports are already in use, modify them in `docker-compose.yml`:

```yaml
ports:
  - "3000:3000"  # Change first port: "HOST:CONTAINER"
```

## 🔒 Security Notes

⚠️ **This setup is for local development only!**

For production:
- Use strong passwords
- Enable SSL/TLS
- Use secrets management
- Configure firewall rules
- Enable authentication
- Use environment-specific configs

---

**Part of the FrameForge microservices ecosystem**
