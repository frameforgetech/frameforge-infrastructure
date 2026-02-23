# FrameForge - Scripts de Automação

Scripts para gerenciar a infraestrutura AWS usando Terraform no WSL.

## 🎯 Referência Rápida

| Quero... | Usar... | $ Custo |
|----------|---------|---------|
| Desenvolver localmente | `./setup-local.sh` | 🆓 Grátis |
| Deploy AWS (primeira vez) | `./init.sh` → `./apply-dev.sh` | 💰 ~$170/mês |
| Ver custos AWS | `./cost-estimate.sh` | 🆓 Grátis |
| Destruir tudo AWS | `./destroy-dev.sh` | 💸 Economiza $ |
| Monitorar RabbitMQ | `./access-rabbitmq.sh` | 🆓 Grátis |

## 📋 Pré-requisitos

```bash
# AWS CLI configurado
aws configure

# Terraform instalado
terraform --version  # >= 1.6

# kubectl (para Kubernetes depois)
kubectl version --client
```

## 🚀 Uso Rápido

### 1. Verificar Custos Estimados

```bash
./cost-estimate.sh
```

**IMPORTANTE**: Revise os custos antes de criar qualquer coisa! ~$170-200/mês.

### 2. Inicializar Terraform

```bash
./init.sh
```

### 3. Planejar Deployment (Ver o que será criado)

```bash
./plan-dev.sh
```

### 4. Aplicar Infraestrutura

```bash
./apply-dev.sh
```

⚠️ **ATENÇÃO**: Isso vai criar recursos que custam dinheiro!

**🎯 Este script é agora ROBUSTO:**
- ✅ **Idempotente** - Pode rodar quantas vezes quiser
- ✅ **Auto-recovery** - Recupera secrets em período de recuperação
- ✅ **Cleanup automático** - Remove log groups conflitantes
- ✅ **Funciona do zero** - Testado e validado!

### 5. Ver Informações da Infraestrutura

```bash
./get-outputs.sh
```

### 6. 💰 DESTRUIR Tudo (Importante!)

```bash
./destroy-dev.sh
```

**Use isso quando terminar de testar para evitar custos!**

## 📂 Scripts Disponíveis

### ☁️ AWS Infrastructure (Produção/Cloud)

| Script | Descrição |
|--------|-----------|
| `init.sh` | Inicializa Terraform (primeira vez) |
| `plan-dev.sh` | Mostra o que será criado/modificado |
| `apply-dev.sh` | Deploy infraestrutura AWS **[PRINCIPAL]** ⭐ |
| `destroy-dev.sh` | Deleta toda infraestrutura AWS 💰 |
| `deploy-k8s.sh` | Deploy serviços no Kubernetes/EKS |
| `get-outputs.sh` | Mostra IPs, endpoints, connection strings |
| `cost-estimate.sh` | Estimativa de custos AWS (~$170/mês) |
| `smoke-test.sh` | Valida se infraestrutura está funcionando |

### 🐳 Local Development (Docker Compose)

| Script | Descrição |
|--------|-----------|
| `setup-local.sh` | Inicia ambiente local (grátis) 🆓 |
| `init-db.sh` | Cria tabelas no PostgreSQL local |
| `rebuild.sh` | Reconstrói imagens Docker |
| `stop.sh` | Para todos serviços locais |

### 📊 Monitoring & Access

| Script | Descrição |
|--------|-----------|
| `install-monitoring.sh` | Instala Prometheus + Grafana (1º) |
| `setup-metrics.sh` | Configura métricas customizadas (2º) |
| `access-rabbitmq.sh` | Acessa RabbitMQ UI via port-forward 🐰 |

### 🔧 Utilities

| Script | Descrição |
|--------|-----------|
| `setup-aws-credentials.sh` | Setup credenciais AWS seguro (primeira vez) |

## 💡 Workflows Comuns

### Primeiro Deploy

```bash
# 1. Ver custos
./cost-estimate.sh

# 2. Inicializar
./init.sh

# 3. Planejar
./plan-dev.sh

# 4. Aplicar
./apply-dev.sh

# 5. Ver outputs
./get-outputs.sh
```

### Teste Rápido (Evitar Custos)

```bash
# Deploy
./apply-dev.sh

# Fazer seus testes...

# DESTRUIR imediatamente
./destroy-dev.sh
```

### Obter Senha do Banco

```bash
# Depois de aplicar, use:
./get-outputs.sh

# Ou diretamente:
SECRET_ARN=$(cd ../terraform/environments/dev && terraform output -raw db_secret_arn)
aws secretsmanager get-secret-value --secret-id $SECRET_ARN --query SecretString --output text | jq -r .password
```

## ⚠️ Avisos Importantes

### Custos

- **EKS Control Plane**: $72/mês (não tem free tier)
- **NAT Gateway**: $32-45/mês
- **EC2 (2x t3.small)**: $30/mês
- **RDS**: GRÁTIS por 12 meses, depois $14/mês
- **TOTAL**: ~$170-200/mês

### Com Budget de $100

- Você tem ~15-20 dias de uptime por mês
- **SEMPRE destrua quando não estiver usando**
- Considere usar apenas para demos/apresentações

### Otimizações

```bash
# Opção 1: Usar menos horas
# - Deploy só durante testes
# - Destroy no final do dia

# Opção 2: Reduzir recursos (editar variables.tf)
eks_desired_size = 1  # Ao invés de 2
ec2_instance_type = "t3.micro"  # Ao invés de t3.small

# Opção 3: Usar spot instances
# - Editar módulo EKS para usar spot
# - Economia de 60-90%
```

## 🔧 Troubleshooting

### Erro: AWS credentials not configured

```bash
aws configure
# Insira: Access Key, Secret Key, Region (us-east-1), Format (json)
```

### Erro: Terraform not initialized

```bash
./init.sh
```

### Erro: Resource already exists

```bash
# Importar recurso existente
cd ../terraform/environments/dev
terraform import module.vpc.aws_vpc.main vpc-xxxxx
```

### Destruir está falhando

```bash
# Forçar remoção de recursos travados
cd ../terraform/environments/dev

# Remover proteções
terraform state list | grep protection | xargs -I {} terraform state rm {}

# Tentar novamente
terraform destroy -auto-approve
```

### ❌ Erro: "Secret already scheduled for deletion"

**Este erro não deve mais acontecer!** O `apply-dev.sh` agora faz auto-recovery de secrets e usa nomes únicos.

Se ainda encontrar, rode novamente:
```bash
./apply-dev.sh
```

O script irá:
- ✅ Recuperar automaticamente secrets em período de recuperação
- ✅ Usar nomes únicos para evitar conflitos
- ✅ Limpar log groups conflitantes

### ❌ Erro: "CloudWatch Log Group already exists"

**Este erro não deve mais acontecer!** O Terraform agora usa `skip_destroy = true` nos log groups.

Se ainda encontrar, rode novamente:
```bash
./apply-dev.sh
```

## 📝 Próximos Passos

Após criar a infraestrutura:

1. **Deploy Kubernetes**
   ```bash
   # Atualizar kubeconfig
   aws eks update-kubeconfig --name frameforge-dev --region us-east-1
   
   # Aplicar manifests
   kubectl apply -f ../k8s/
   ```

2. **Verificar Services**
   ```bash
   kubectl get pods -A
   kubectl get svc -A
   ```

3. **Acessar API**
   ```bash
   # Pegar LoadBalancer URL
   kubectl get svc -n frameforge api-gateway
   ```

## 🆘 Em Caso de Emergência

Se você esqueceu de destruir e os custos estão altos:

```bash
# 1. DESTRUIR IMEDIATAMENTE
./destroy-dev.sh

# 2. Verificar que tudo foi deletado
aws ec2 describe-instances --filters "Name=tag:Project,Values=FrameForge"
aws eks list-clusters

# 3. Deletar manualmente se necessário
aws eks delete-cluster --name frameforge-dev
aws rds delete-db-instance --db-instance-identifier frameforge-dev --skip-final-snapshot
```

## �📧 Contato

Para dúvidas sobre os scripts ou infraestrutura, consulte a documentação em `../docs/`.
