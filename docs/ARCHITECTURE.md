# FrameForge - Arquitetura e Decisões Técnicas

> Documentação completa da arquitetura de microsserviços, decisões técnicas e estratégias de implementação do projeto FrameForge.

## 📋 Índice

1. [Visão Geral](#1-visão-geral)
2. [Decisão de Arquitetura](#2-decisão-de-arquitetura)
3. [Arquitetura de Microsserviços](#3-arquitetura-de-microsserviços)
4. [Decisões Técnicas](#4-decisões-técnicas)
5. [Infraestrutura](#5-infraestrutura)
6. [Qualidade e Testes](#6-qualidade-e-testes)
7. [Monitoramento e Observabilidade](#7-monitoramento-e-observabilidade)
8. [Segurança](#8-segurança)
9. [Diagramas](#9-diagramas)

---

## 1. Visão Geral

### 1.1 Escopo do Projeto

O **FrameForge** é um sistema escalável de processamento de vídeos baseado em arquitetura de microsserviços para extração de frames. O sistema permite que usuários façam upload de vídeos, que são processados assincronamente para extrair frames individuais, gerando um arquivo ZIP com os resultados.

### 1.2 Objetivos

- ✅ Implementar arquitetura de microsserviços escalável
- ✅ Processamento assíncrono de vídeos com alta performance
- ✅ Sistema resiliente com retry automático e mensageria
- ✅ Deploy independente de cada serviço
- ✅ Monitoramento completo com métricas e logs
- ✅ Infraestrutura como código (Terraform + Kubernetes)

### 1.3 Stack Tecnológico

| Camada | Tecnologia |
|--------|-----------|
| **Backend** | Node.js 20+ / TypeScript |
| **Framework** | Express.js |
| **Database** | PostgreSQL 15 |
| **Cache** | Redis 7 |
| **Message Queue** | RabbitMQ 3 |
| **Storage** | AWS S3 |
| **Processing** | FFmpeg |
| **Auth** | JWT + bcrypt |
| **IaC** | Terraform |
| **Orchestration** | Kubernetes (EKS) |
| **Monitoring** | Prometheus + Grafana |
| **CI/CD** | GitHub Actions |

---

## 2. Decisão de Arquitetura

### 2.1 Contexto

O projeto foi inicialmente implementado como monorepo durante o desenvolvimento rápido. Para atender aos requisitos do desafio e seguir boas práticas de microsserviços, foi decidida a reorganização em múltiplos repositórios independentes.

### 2.2 Princípios Aplicados

#### SOLID

- **S**ingle Responsibility: Cada serviço/repositório tem uma responsabilidade única
- **O**pen/Closed: Extensível via plugins e middlewares
- **L**iskov Substitution: Interfaces bem definidas e substituíveis
- **I**nterface Segregation: Contratos segregados por contexto
- **D**ependency Inversion: Dependência de abstrações (shared-contracts)

#### Domain-Driven Design (DDD)

- **Bounded Context**: Cada serviço representa um contexto delimitado do domínio
- **Ubiquitous Language**: Terminologia consistente em todo o código
- **Aggregates**: Entidades agrupadas logicamente

#### Microsserviços

- **Independent Deployability**: Serviços podem ser deployados independentemente
- **Decentralized Data**: Cada serviço gerencia seus dados
- **Business Capability**: Organizados por capacidade de negócio
- **Smart Endpoints, Dumb Pipes**: Lógica nos serviços, não na infraestrutura

### 2.3 Estrutura de Repositórios (Atual/Proposta)

```
FrameForge Ecosystem
├── frameforge-auth-service          🔐 Autenticação e JWT
├── frameforge-api-gateway           🚪 Ponto de entrada único
├── frameforge-video-processor       🎬 Processamento de vídeos
├── frameforge-notification-service  📧 Envio de notificações
├── frameforge-shared-contracts      📦 Biblioteca compartilhada (npm)
├── frameforge-infrastructure        🏗️ IaC (Terraform + K8s + Docker)
└── frameforge-ci-cd (futuro)        🔄 Workflows reutilizáveis
```

---

## 3. Arquitetura de Microsserviços

### 3.1 Serviços

#### 3.1.1 Auth Service 🔐

**Responsabilidade:** Autenticação e geração de tokens JWT

**Tecnologias:**
- TypeScript, Express.js
- JWT para tokens
- bcrypt para hash de senhas
- PostgreSQL para armazenamento de usuários

**Endpoints:**
- `POST /api/v1/auth/register` - Registro de usuário
- `POST /api/v1/auth/login` - Login e geração de JWT
- `POST /api/v1/auth/validate` - Validação de token

**Escalabilidade:** 2 réplicas fixas (stateless)

**Métricas:**
- `auth_registration_attempts_total{status}`
- `auth_login_attempts_total{status}`
- `auth_token_validation_total{status}`

---

#### 3.1.2 API Gateway 🚪

**Responsabilidade:** Ponto de entrada único, orquestração de requisições

**Tecnologias:**
- TypeScript, Express.js
- Redis para cache e rate limiting
- RabbitMQ para publicação de jobs
- AWS SDK para S3 pre-signed URLs

**Endpoints:**
- `POST /api/v1/videos/upload-url` - Gerar URL de upload (S3)
- `POST /api/v1/videos/jobs` - Criar job de processamento
- `GET /api/v1/videos/jobs` - Listar jobs
- `GET /api/v1/videos/jobs/:id` - Detalhes do job

**Funcionalidades:**
- Validação de JWT (via Auth Service)
- Rate limiting (100 req/min por usuário)
- Cache de responses (Redis, TTL 5min)
- Invalidação de cache em updates

**Escalabilidade:** 2-10 réplicas (HPA baseado em CPU)

**Métricas:**
- `http_requests_total{method, path, status}`
- `http_request_duration_seconds{method, path}`
- `cache_hits_total`, `cache_misses_total`
- `rate_limit_exceeded_total`

---

#### 3.1.3 Video Processor 🎬

**Responsabilidade:** Processamento assíncrono de vídeos e extração de frames

**Tecnologias:**
- TypeScript, Node.js
- FFmpeg para processamento de vídeo
- RabbitMQ para consumo de jobs
- AWS SDK para S3 (download/upload)

**Fluxo de Processamento:**
1. Consumir job da fila RabbitMQ
2. Baixar vídeo do S3
3. Validar formato e integridade
4. Extrair frames com FFmpeg (1 frame/segundo)
5. Gerar arquivo manifest.json
6. Criar ZIP com frames + manifest
7. Upload do resultado para S3
8. Atualizar status do job no banco
9. Publicar evento de conclusão (RabbitMQ)
10. Limpar arquivos temporários

**Escalabilidade:** 2-20 réplicas (HPA agressivo baseado em fila)

**Métricas:**
- `video_processing_duration_seconds`
- `video_processing_total{status}`
- `video_frames_extracted_total`
- `queue_depth`

---

#### 3.1.4 Notification Service 📧

**Responsabilidade:** Envio de notificações por email

**Tecnologias:**
- TypeScript, Node.js
- Nodemailer para envio de emails
- RabbitMQ para consumo de eventos

**Funcionalidades:**
- Consumir eventos de conclusão/falha
- Enviar email com link de download (se sucesso)
- Retry com exponential backoff (3 tentativas)
- Log de notificações enviadas

**Escalabilidade:** 2 réplicas fixas

**Métricas:**
- `notification_delivery_total{status}`
- `notification_retry_attempts_total`

---

#### 3.1.5 Shared Contracts 📦

**Responsabilidade:** Biblioteca npm com tipos e entidades compartilhadas

**Conteúdo:**
- Entidades TypeORM (User, VideoJob, NotificationLog)
- Interfaces de API (Request/Response types)
- Enums e constantes
- Database migrations

**Publicação:**
- GitHub Packages (npm privado)
- Versionamento semântico rigoroso
- `@frameforge/shared-contracts`

**Versionamento:**
- **Major (1.0.0 → 2.0.0)**: Breaking changes
- **Minor (1.0.0 → 1.1.0)**: Novos recursos
- **Patch (1.0.0 → 1.0.1)**: Bug fixes

---

### 3.2 Comunicação Entre Serviços

#### 3.2.1 Síncrona (REST)

```
API Gateway → Auth Service (validação de token)
- Protocolo: HTTP/REST
- Timeout: 5 segundos
- Retry: Sem retry (fail-fast)
- Circuit Breaker: Sim (threshold: 50% erro em 10 requisições)
```

#### 3.2.2 Assíncrona (Message Queue)

```
API Gateway → RabbitMQ → Video Processor
- Exchange: frameforge.video.jobs (topic)
- Queue: video.processing.jobs
- Routing Key: video.job.created
- TTL: 1 hora
- Dead Letter Queue: video.processing.dlq

Video Processor → RabbitMQ → Notification Service
- Exchange: frameforge.video.events (topic)
- Queue: video.events.notifications
- Routing Keys: video.job.completed, video.job.failed
- TTL: 30 minutos
```

---

## 4. Decisões Técnicas

### 4.1 Shared Code Strategy

**Decisão:** NPM Package Privado via GitHub Packages

**Alternativas Consideradas:**
- ❌ Git Submodules (complexo, difícil de versionar)
- ❌ Copiar código (duplicação, inconsistência)
- ✅ NPM Package (versionamento semântico, fácil de usar)

**Implementação:**

```json
// frameforge-shared-contracts/package.json
{
  "name": "@frameforge/shared-contracts",
  "version": "1.0.0",
  "publishConfig": {
    "registry": "https://npm.pkg.github.com"
  }
}

// Outros serviços
{
  "dependencies": {
    "@frameforge/shared-contracts": "^1.0.0"
  }
}
```

---

### 4.2 Database Migrations

**Decisão:** Migrations no Shared Contracts, executadas pelo Auth Service

**Problema:** Múltiplos serviços acessam o mesmo banco, quem executa migrations?

**Alternativas Consideradas:**
- ❌ Cada serviço executa suas migrations (conflitos, race conditions)
- ❌ Migration service separado (overhead desnecessário)
- ✅ Auth Service executa todas (primeiro a subir, responsabilidade clara)

**Implementação:**

```typescript
// frameforge-shared-contracts/src/migrations/index.ts
export const migrations = [
  CreateUsersTable1700000001000,
  CreateVideoJobsTable1700000002000,
  CreateNotificationLogTable1700000003000,
];

// frameforge-auth-service/src/database.ts
import { migrations } from '@frameforge/shared-contracts';

const dataSource = new DataSource({
  migrations: migrations,
  migrationsRun: true, // Auto-run on startup
});
```

**Benefícios:**
- ✅ Migrations versionadas com shared-contracts
- ✅ Execução garantida antes de outros serviços
- ✅ Sem race conditions
- ✅ Rollback controlado

---

### 4.3 Configuration Management

**Decisão:** Environment Variables + ConfigMaps/Secrets

**Hierarquia:**
1. Defaults (código)
2. .env file (desenvolvimento local)
3. Environment variables (Docker/Kubernetes)
4. ConfigMaps (configuração não-sensível)
5. Secrets (credenciais)

**Exemplo:**

```typescript
export const config = {
  port: parseInt(process.env.PORT || '3000'),
  database: {
    url: process.env.DATABASE_URL || 'postgresql://localhost/frameforge',
    poolSize: parseInt(process.env.DB_POOL_SIZE || '10'),
  },
  jwt: {
    secret: process.env.JWT_SECRET!, // Required
    expiresIn: parseInt(process.env.JWT_EXPIRES_IN || '3600'),
  },
};

// Validação na inicialização
if (!config.jwt.secret) {
  throw new Error('JWT_SECRET is required');
}
```

---

### 4.4 Logging Strategy

**Decisão:** Logs Estruturados JSON com Trace IDs

**Formato Padrão:**

```typescript
interface LogEntry {
  timestamp: string;      // ISO 8601
  level: 'ERROR' | 'WARN' | 'INFO' | 'DEBUG';
  service: string;        // Nome do serviço
  traceId: string;        // UUID para correlação
  requestId?: string;     // ID da requisição HTTP
  userId?: string;        // ID do usuário
  message: string;
  context?: object;
  error?: {
    name: string;
    message: string;
    stack: string;
  };
}
```

**Exemplo:**

```json
{
  "timestamp": "2026-02-19T10:30:00.000Z",
  "level": "ERROR",
  "service": "video-processor",
  "traceId": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "user_xyz789",
  "message": "Failed to extract frames from video",
  "context": {
    "jobId": "job_123",
    "videoUrl": "s3://bucket/video.mp4"
  },
  "error": {
    "name": "FFmpegError",
    "message": "Corrupted video file",
    "stack": "..."
  }
}
```

---

## 5. Infraestrutura

### 5.1 AWS Infrastructure (Terraform)

**Componentes:**

#### VPC
- CIDR: 10.0.0.0/16
- 2 Subnets públicas (10.0.1.0/24, 10.0.2.0/24)
- 2 Subnets privadas (10.0.10.0/24, 10.0.11.0/24)
- NAT Gateway para acesso externo das privadas
- Internet Gateway

#### RDS PostgreSQL
- Instância: db.t3.micro
- Engine: PostgreSQL 15
- Multi-AZ: Não (dev)
- Backup: 7 dias
- Senha gerenciada por Secrets Manager

#### EC2 Instances
- RabbitMQ: t3.small (10.0.10.135)
- Redis: t3.small (10.0.10.87)

#### S3 Buckets
- `frameforge-videos-dev` (uploads)
- `frameforge-results-dev` (resultados processados)
- Versionamento habilitado
- Lifecycle policy: 30 dias → Glacier

#### EKS Cluster
- Nome: frameforge-dev
- Versão: 1.28
- Node Group: 2x t3.small
- Auto-scaling: 2-10 nodes

#### Security Groups
- `api-gateway-sg`: Porta 3000
- `auth-service-sg`: Porta 3001
- `postgres-sg`: Porta 5432
- `rabbitmq-sg`: Portas 5672, 15672
- `redis-sg`: Porta 6379

**Custos Estimados:**
- EKS Control Plane: $72/mês
- EC2 (2x t3.small): $30/mês
- RDS (t3.micro): $12/mês (Free Tier: $0)
- NAT Gateway: $32/mês
- **Total: ~$146-170/mês**

---

### 5.2 Kubernetes Architecture

**Namespace:** `frameforge`

#### Deployments

```yaml
# API Gateway
replicas: 2-10 (HPA)
resources:
  requests: cpu=100m, memory=128Mi
  limits: cpu=500m, memory=512Mi
readinessProbe: /health
livenessProbe: /health

# Auth Service
replicas: 2
resources:
  requests: cpu=100m, memory=128Mi
  limits: cpu=300m, memory=256Mi

# Video Processor
replicas: 2-20 (HPA agressivo)
resources:
  requests: cpu=500m, memory=512Mi
  limits: cpu=2000m, memory=2Gi

# Notification Service
replicas: 2
resources:
  requests: cpu=50m, memory=64Mi
  limits: cpu=200m, memory=256Mi
```

#### HPA (Horizontal Pod Autoscaler)

```yaml
# API Gateway HPA
minReplicas: 2
maxReplicas: 10
targetCPUUtilization: 70%

# Video Processor HPA
minReplicas: 2
maxReplicas: 20
targetCPUUtilization: 60%
customMetrics:
  - type: External
    name: rabbitmq_queue_depth
    target: 10 # Scale up se fila > 10 jobs
```

---

## 6. Qualidade e Testes

### 6.1 Estratégia de Testes

**Estrutura por Serviço:**

```
frameforge-{service}/
├── src/
│   └── *.test.ts           # Unit tests (co-located)
├── tests/
│   ├── unit/               # Additional unit tests
│   ├── integration/        # Integration tests
│   └── property/           # Property-based tests
```

#### 6.1.1 Unit Tests

- Co-localizados com código
- Mocks de dependências externas
- Rápidos (<1s por teste)
- **Coverage: 80%+**
- Framework: Jest

#### 6.1.2 Integration Tests

- Testam integração com DB, Redis, RabbitMQ
- Usam containers Docker (Testcontainers)
- Médios (~5s por teste)
- Coverage: Fluxos principais

#### 6.1.3 Property-Based Tests

- Validam propriedades universais
- Mínimo 100 iterações
- Framework: fast-check
- Coverage: Regras de negócio

**Exemplo:**

```typescript
import fc from 'fast-check';

describe('Password Validation', () => {
  it('should always hash to different value', () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 8 }),
        async (password) => {
          const hash1 = await bcrypt.hash(password, 10);
          const hash2 = await bcrypt.hash(password, 10);
          return hash1 !== hash2; // Deve sempre ser diferente
        }
      ),
      { numRuns: 100 }
    );
  });
});
```

#### 6.1.4 E2E Tests

- Testam fluxo completo do sistema
- Ambiente staging
- Lentos (~30s por teste)
- Coverage: Happy paths + edge cases críticos

---

### 6.2 Code Quality

**Ferramentas:**

- **ESLint**: Linting rigoroso
- **Prettier**: Formatação consistente
- **SonarQube**: Análise estática (rating A obrigatório)
- **Husky**: Pre-commit hooks
- **Trivy**: Security scan de imagens Docker

**Métricas Obrigatórias:**

- Coverage: >80%
- Code Smells: <10
- Duplicação: <3%
- Bugs: 0
- Vulnerabilidades: 0 críticas

---

## 7. Monitoramento e Observabilidade

### 7.1 Métricas (Prometheus)

**Métricas Padrão (todos os serviços):**

```typescript
// System metrics
- process_cpu_user_seconds_total
- process_resident_memory_bytes
- nodejs_heap_size_total_bytes
- nodejs_heap_size_used_bytes

// HTTP metrics
- http_requests_total{method, path, status}
- http_request_duration_seconds{method, path}

// Business metrics (específicas por serviço)
- auth_registration_attempts_total{status}
- auth_login_attempts_total{status}
- video_processing_duration_seconds
- video_processing_total{status}
- notification_delivery_total{status}
```

**Endpoint:** `GET /metrics` (exposto em cada serviço)

---

### 7.2 Dashboards (Grafana)

**Dashboards Criados:**

1. **System Overview** - Visão geral de todos os serviços
2. **Auth Service** - Login/registro rates, latência
3. **API Gateway** - Request rate, cache hit ratio, rate limiting
4. **Video Processor** - Queue depth, processing time, success rate
5. **Notification Service** - Delivery rate, retry count

---

### 7.3 Alertas

**Alertas Configurados:**

```yaml
# Alta latência
- alert: HighLatency
  expr: http_request_duration_seconds{quantile="0.99"} > 2
  for: 5m
  severity: warning

# Taxa de erro elevada
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 5m
  severity: critical

# Fila muito grande
- alert: LargeQueue
  expr: rabbitmq_queue_messages > 100
  for: 10m
  severity: warning

# Memory leak
- alert: MemoryLeak
  expr: increase(process_resident_memory_bytes[1h]) > 100000000
  for: 1h
  severity: warning
```

---

## 8. Segurança

### 8.1 Defense in Depth

**Camadas de Segurança:**

#### Network Security
- VPC com subnets públicas e privadas
- Security groups com least privilege
- NAT Gateway para acesso externo
- Sem IPs públicos em serviços internos

#### Authentication & Authorization
- JWT tokens com expiração curta (1h)
- bcrypt para hash de senhas (10 salt rounds)
- Rate limiting por usuário (100 req/min)

#### Data Security
- Passwords nunca em plaintext
- Secrets no Kubernetes Secrets
- Encryption at rest (S3, RDS)
- Encryption in transit (TLS)
- Pre-signed URLs temporárias (15min)

#### Application Security
- Validação de input (Joi schemas)
- SQL injection prevention (TypeORM)
- XSS prevention (sanitização)
- CORS configurado
- Helmet.js para headers seguros

---

### 8.2 Secrets Management

**Terraform:**
- Senhas geradas aleatoriamente
- Armazenadas no AWS Secrets Manager
- Recovery window: 0 dias (deleção imediata)

**Kubernetes:**
- Secrets encodados em base64
- Injetados como environment variables
- Nunca commitados no git (secrets.yaml.template)

---

## 9. Diagramas

### 9.1 Arquitetura Geral

```
┌─────────────────────────────────────────────────────────────┐
│                      FrameForge System                       │
└─────────────────────────────────────────────────────────────┘

                    ┌──────────┐
                    │  Client  │
                    └─────┬────┘
                          │ HTTPS
                          ▼
                ┌─────────────────┐
                │  Load Balancer  │
                │   (ELB/ALB)     │
                └────────┬─────────┘
                         │
                         ▼
                ┌─────────────────┐
                │  API Gateway    │◄────┐
                │  (Port 3000)    │     │ JWT Validation
                │  - Upload URLs  │     │ (REST)
                │  - Job Mgmt     │     │
                │  - Cache/Limit  │     │
                └────┬────────────┘     │
                     │                  │
         ┌───────────┴────────┐         │
         │ Publish Job        │         │
         │ (RabbitMQ)         │         ▼
         ▼                    │   ┌──────────────┐
    ┌─────────┐               │   │ Auth Service │
    │RabbitMQ │               │   │ (Port 3001)  │
    │  Queue  │               │   │ - Register   │
    └────┬────┘               │   │ - Login      │
         │                    │   │ - Validate   │
         │ Consume Job        │   └──────────────┘
         ▼                    │
    ┌──────────────┐          │
    │    Video     │          │
    │  Processor   │          │
    │  - Extract   │          │
    │  - Compress  │          │
    │  - Upload    │          │
    └──────┬───────┘          │
           │                  │
           │ Publish Event    │
           │ (RabbitMQ)       │
           ▼                  │
    ┌─────────────┐           │
    │ RabbitMQ    │           │
    │   Events    │           │
    └──────┬──────┘           │
           │                  │
           │ Consume Event    │
           ▼                  │
    ┌──────────────┐          │
    │Notification  │          │
    │  Service     │          │
    │ - Email      │          │
    │ - Retry      │          │
    └──────────────┘          │
                              │
┌─────────────────────────────┴───────────────────────┐
│                  Shared Resources                    │
└──────────────────────────────────────────────────────┘

    ┌──────────┐  ┌───────┐  ┌──────┐  ┌────────────┐
    │PostgreSQL│  │ Redis │  │  S3  │  │Prometheus  │
    │  (RDS)   │  │       │  │      │  │  +Grafana  │
    └──────────┘  └───────┘  └──────┘  └────────────┘
```

---

### 9.2 Fluxo de Processamento

```
┌─────────────────────────────────────────────────────────────┐
│              Video Processing Flow                           │
└────────────────────────────────────────────────────────────┘

1. Usuario                  2. API Gateway          3. S3
   │                            │                     │
   │ POST /upload-url           │                     │
   ├───────────────────────────►│                     │
   │◄───────────────────────────┤                     │
   │   {uploadUrl, videoId}     │                     │
   │                            │                     │
   │ PUT video to uploadUrl                           │
   ├──────────────────────────────────────────────────►
   │◄────────────────────────────────────────────────┤
   │   200 OK                                         │
   │                            │                     │
   │ POST /jobs {videoId}       │                     │
   ├───────────────────────────►│                     │
   │                            │  4. RabbitMQ        │
   │                            │      │              │
   │                            │  Publish Job        │
   │                            ├──────►              │
   │◄───────────────────────────┤                     │
   │   {jobId, status}          │                     │
   │                            │                     │
                                │  5. Video Processor │
                                │      │              │
                                │  Consume Job        │
                                │◄─────┘              │
                                │                     │
                                │  Download Video     │
                                ├─────────────────────►
                                │◄────────────────────┤
                                │                     │
                            6. FFmpeg Extract Frames  │
                            ────────────────          │
                                │                     │
                            7. Create ZIP             │
                            ──────────                │
                                │                     │
                                │  Upload Result      │
                                ├─────────────────────►
                                │◄────────────────────┤
                                │                     │
                            8. Update Job Status      │
                                │                     │
                                │  9. Publish Event   │
                                ├──────►              │
                                │                     │
                        10. Notification Service      │
                                │                     │
                            Consume Event             │
                                │                     │
                            Send Email                │
                                │                     │
   ◄────────────────────────────┤                     │
     Email: "Processing complete!"
```

---

### 9.3 CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│              CI/CD Pipeline (per repository)                 │
└─────────────────────────────────────────────────────────────┘

    ┌──────────┐
    │   Push   │
    │ to main  │
    └─────┬────┘
          │
          ▼
    ┌──────────┐
    │   Lint   │  ESLint + Prettier + TypeScript
    │  & Type  │  < 1 min
    └─────┬────┘
          │
          ▼
    ┌──────────┐
    │   Test   │  Unit + Integration + Property
    │ Coverage │  Coverage > 80%
    └─────┬────┘  ~ 3 min
          │
          ▼
    ┌──────────┐
    │  Build   │  TypeScript → JavaScript
    │  Docker  │  Docker multi-stage build
    └─────┬────┘  ~ 2 min
          │
          ▼
    ┌──────────┐
    │ Security │  npm audit + Trivy scan
    │   Scan   │  Zero critical vulnerabilities
    └─────┬────┘
          │
          ▼
    ┌──────────┐
    │ SonarQube│  Code quality gate
    │  Quality │  Rating A required
    │   Gate   │
    └─────┬────┘
          │  (fail if quality gate ❌)
          │
          ▼
    ┌──────────┐
    │  Deploy  │  Push image to ECR
    │ Staging  │  Update K8s deployment
    └─────┬────┘  kubectl apply
          │
          ▼
    ┌──────────┐
    │  Smoke   │  Health checks + basic E2E
    │  Tests   │  Rollback on failure
    └─────┬────┘
          │  (fail → rollback ❌)
          │
          ▼
    ┌──────────┐
    │  Manual  │  Approval required
    │ Approval │  for production
    └─────┬────┘
          │  (awaiting approval... ⏳)
          │
          ▼
    ┌──────────┐
    │  Deploy  │  Blue-green deployment
    │   Prod   │  Zero downtime
    └──────────┘  Rollback on failure

Total time: ~8-10 minutes (staging)
```

---

### 9.4 Kubernetes Architecture

```
┌─────────────────────────────────────────────────────────────┐
│          Kubernetes Namespace: frameforge                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Ingress / LoadBalancer                                      │
│  ├── api-gateway.frameforge.com → api-gateway-service      │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┴──────────────┐
        │                             │
    ┌───▼────────────┐        ┌───────▼────────┐
    │ API Gateway    │        │ Auth Service   │
    │   Service      │        │    Service     │
    │  ClusterIP     │        │   ClusterIP    │
    └───┬────────────┘        └───┬────────────┘
        │                         │
    ┌───▼────────────┐        ┌───▼────────────┐
    │ API Gateway    │        │ Auth Service   │
    │  Deployment    │        │   Deployment   │
    │  Replicas: 2-10│        │   Replicas: 2  │
    └────────────────┘        └────────────────┘
        │ HPA (CPU)               │ Fixed
        ▼
    ┌────────────────────────────┐
    │ Video Processor Deployment │
    │      Replicas: 2-20        │
    │   HPA (CPU + Queue Depth)  │
    └────────────────────────────┘
        │
        ▼
    ┌────────────────────────────┐
    │ Notification Service       │
    │      Deployment            │
    │      Replicas: 2           │
    └────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  ConfigMap: frameforge-config                                │
│  ├── RABBITMQ_HOST, REDIS_HOST, DATABASE_HOST              │
│  └── APP_ENV, LOG_LEVEL, etc.                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  Secret: frameforge-secrets                                  │
│  ├── JWT_SECRET, DATABASE_PASSWORD                          │
│  ├── AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY              │
│  └── SMTP_PASSWORD, etc.                                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  PersistentVolumeClaim: postgres-pvc (10Gi)                 │
│  PersistentVolumeClaim: rabbitmq-pvc (5Gi)                  │
│  PersistentVolumeClaim: redis-pvc (1Gi)                     │
└─────────────────────────────────────────────────────────────┘
```

---

## 10. Benefícios da Arquitetura

### 10.1 Técnicos

- ✅ **Deploy Independente**: Atualizar um serviço não afeta outros
- ✅ **Escalabilidade Diferenciada**: Video Processor escala 10x mais que Auth
- ✅ **Resilência**: Falha em um serviço não derruba o sistema todo
- ✅ **Performance**: Cache e async processing reduzem latência
- ✅ **Manutenibilidade**: Código organizado, responsabilidades claras

### 10.2 Organizacionais

- ✅ **Ownership Claro**: Times diferentes podem ter serviços diferentes
- ✅ **Onboarding Rápido**: Entender um serviço por vez
- ✅ **Code Review Focado**: PRs menores, específicos
- ✅ **Qualidade Isolada**: Métricas e debt técnico por serviço

### 10.3 Qualidade

- ✅ **Testabilidade**: Testes isolados, mocks facilitados
- ✅ **Observabilidade**: Métricas e logs por serviço
- ✅ **Segurança**: Least privilege, isolamento de recursos

---

## 11. Desafios e Mitigações

| Desafio | Mitigação |
|---------|-----------|
| **Duplicação de Código** | Shared contracts como npm package |
| **Versionamento de Contratos** | Semantic versioning rigoroso + changelog |
| **Testes de Integração** | Testes de contrato, staging environment |
| **Sincronização de Migrations** | Auth Service executa migrations no startup |
| **Setup Local Complexo** | Docker Compose automatizado, scripts |
| **Distribuição de Logs** | Logs estruturados JSON com trace IDs |
| **Monitoramento Complexo** | Dashboards Grafana consolidados |

---

## 12. Próximos Passos

### Implementado ✅

- [x] Arquitetura de microsserviços
- [x] Auth Service completo
- [x] API Gateway com cache e rate limiting
- [x] Video Processor com FFmpeg
- [x] Notification Service
- [x] Infraestrutura Terraform (VPC, RDS, S3, EKS)
- [x] Kubernetes manifests
- [x] Docker Compose para dev local
- [x] Monitoramento Prometheus + Grafana
- [x] CI/CD básico

### Melhorias Futuras 🚀

- [ ] Migrar para múltiplos repositórios
- [ ] Publicar shared-contracts no GitHub Packages
- [ ] Implementar Circuit Breaker (resilience4j)
- [ ] Adicionar distributed tracing (Jaeger/Zipkin)
- [ ] Implementar API versioning (v2)
- [ ] Adicionar refresh tokens JWT
- [ ] Implementar webhooks para notificações
- [ ] Otimizar processamento de vídeo (GPU?)
- [ ] Adicionar support para múltiplos formatos (WebM, AVI)
- [ ] Implementar quotas por usuário
- [ ] Adicionar autenticação OAuth2 (Google, GitHub)
- [ ] Deploy multi-região (latência reduzida)

---

## 📚 Referências

### Livros
- "Building Microservices" - Sam Newman
- "Domain-Driven Design" - Eric Evans
- "Clean Architecture" - Robert C. Martin

### Padrões e Boas Práticas
- 12-Factor App
- SOLID Principles
- DDD (Domain-Driven Design)
- API Design Guidelines (REST)
- Kubernetes Best Practices

### Documentação Oficial
- [Node.js Documentation](https://nodejs.org/docs/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [AWS Documentation](https://docs.aws.amazon.com/)

---

**Última Atualização:** 19 de Fevereiro de 2026  
**Versão:** 2.0  
**Status:** ✅ Implementação concluída, sistema em produção
