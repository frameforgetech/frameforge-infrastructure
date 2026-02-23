# FrameForge Infrastructure - Terraform

Infrastructure as Code para a plataforma FrameForge usando Terraform e AWS.

## 📋 Pré-requisitos

- Terraform 1.6+
- AWS CLI configurado
- Credenciais AWS com permissões adequadas
- kubectl (para gerenciar o cluster EKS)

## 🏗️ Estrutura

```
terraform/
├── modules/                    # Módulos reutilizáveis
│   ├── vpc/                   # VPC com subnets públicas/privadas
│   ├── s3/                    # S3 buckets para vídeos e resultados
│   ├── rds/                   # RDS PostgreSQL
│   ├── ec2/                   # EC2 para RabbitMQ e Redis
│   └── eks/                   # EKS cluster e node groups
├── environments/              # Ambientes isolados
│   ├── dev/                   # Desenvolvimento
│   └── prod/                  # Produção
└── scripts/                   # Scripts de automação
    ├── init.sh
    ├── apply.sh
    └── destroy.sh
```

## 🚀 Quick Start

### 1. Configurar AWS CLI

```bash
aws configure
# AWS Access Key ID: YOUR_KEY
# AWS Secret Access Key: YOUR_SECRET
# Default region name: us-east-1
# Default output format: json
```

### 2. Inicializar Terraform

```bash
cd terraform/environments/dev
terraform init
```

### 3. Planejar mudanças

```bash
terraform plan
```

### 4. Aplicar infraestrutura

```bash
terraform apply
```

### 5. Obter outputs importantes

```bash
terraform output
```

## 💰 Estimativa de Custos (Free Tier)

**IMPORTANTE:** Mesmo no free tier, alguns recursos têm custos!

### Free Tier Elegível (12 meses)
- ✅ EC2 t3.micro - 750 horas/mês
- ✅ RDS db.t3.micro - 750 horas/mês
- ✅ S3 - 5GB storage, 20k GET, 2k PUT
- ✅ Application Load Balancer - 750 horas/mês

### Com Custo (mesmo no Free Tier)
- ⚠️ **EKS Control Plane: ~$72/mês** (não elegível para free tier)
- ⚠️ NAT Gateway: ~$32/mês ($0.045/hora + data transfer)
- ⚠️ Elastic IP não associado: $0.005/hora
- ⚠️ EBS volumes adicionais
- ⚠️ Data transfer out > 100GB

### Estimativa Total Mensal
- **Desenvolvimento (mínimo):** ~$110/mês
  - EKS Control Plane: $72
  - NAT Gateway: $32
  - EC2 + RDS: Free tier
  - S3: Free tier
  - Data transfer: ~$6

- **Produção (escalado):** ~$300-500/mês

## 🔴 IMPORTANTE: Limpeza de Recursos

**Para evitar custos desnecessários, sempre destrua os recursos quando não estiver usando!**

```bash
# Destruir tudo
cd terraform/environments/dev
terraform destroy -auto-approve

# Ou use o script
./scripts/destroy-all.sh
```

## 📦 Recursos Criados

### Networking (VPC)
- VPC com CIDR 10.0.0.0/16
- 2 subnets públicas (10.0.1.0/24, 10.0.2.0/24)
- 2 subnets privadas (10.0.10.0/24, 10.0.11.0/24)
- Internet Gateway
- NAT Gateway (1 para economia)
- Route tables configuradas

### Storage (S3)
- `frameforge-videos-{env}` - Uploads de vídeos
- `frameforge-results-{env}` - Resultados processados (ZIPs)
- Versionamento habilitado
- Lifecycle policies (delete após 30 dias)

### Database (RDS)
- PostgreSQL 15
- Instance class: db.t3.micro (free tier)
- Multi-AZ: false (economia)
- Automated backups: 7 dias
- Storage: 20GB gp3

### Compute (EC2)
- 1x t3.small para RabbitMQ
- 1x t3.small para Redis
- Amazon Linux 2023
- User data para instalação automática

### Kubernetes (EKS)
- EKS 1.28
- Node group: 2-4 nodes t3.small
- Managed node group
- OIDC provider configurado
- Addons: CoreDNS, kube-proxy, vpc-cni

## 🔐 Segurança

- Security Groups restritivos
- RDS não acessível publicamente
- S3 buckets com encryption
- IAM roles com least privilege
- Secrets no AWS Secrets Manager

## 📊 Monitoramento

- CloudWatch Logs para todos os serviços
- CloudWatch Metrics
- EKS Container Insights
- RDS Enhanced Monitoring

## 🔄 CI/CD Integration

Os workflows do GitHub Actions usam os outputs do Terraform:

```yaml
- name: Configure kubectl
  env:
    CLUSTER_NAME: ${{ secrets.EKS_CLUSTER_NAME }}
  run: |
    aws eks update-kubeconfig --name $CLUSTER_NAME --region us-east-1
```

## 📝 Variables

Principais variáveis configuráveis (ver `variables.tf`):

```hcl
environment        # dev, prod
aws_region        # us-east-1, us-west-2, etc
vpc_cidr          # 10.0.0.0/16
db_instance_class # db.t3.micro
eks_node_type     # t3.small
```

## 🎯 Boas Práticas

1. **State remoto:** Use S3 + DynamoDB para lock
2. **Workspace:** Use terraform workspaces para ambientes
3. **Modules:** Reutilize módulos entre ambientes
4. **Secrets:** Nunca commite secrets, use AWS Secrets Manager
5. **Costs:** Sempre destrua recursos de dev quando não usar

## 🚨 Troubleshooting

### EKS cluster não acessível
```bash
aws eks update-kubeconfig --name frameforge-dev --region us-east-1
kubectl get nodes
```

### RDS connection timeout
```bash
# Verificar security group
aws ec2 describe-security-groups --group-ids sg-xxxxx
```

### Terraform state locked
```bash
# Forçar unlock (cuidado!)
terraform force-unlock LOCK_ID
```

## 📚 Documentação

- [AWS Free Tier](https://aws.amazon.com/free/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## 🧹 Limpeza Rápida

```bash
# Deletar TUDO de uma vez (CUIDADO!)
cd terraform/environments/dev
terraform destroy -auto-approve

# Verificar recursos órfãos
aws ec2 describe-instances --filters "Name=tag:Environment,Values=dev"
aws rds describe-db-instances
aws s3 ls
```

## ⚡ Scripts Úteis

```bash
# Inicializar todos os ambientes
./scripts/init-all.sh

# Aplicar mudanças em dev
./scripts/apply-dev.sh

# Destruir tudo (dev)
./scripts/destroy-dev.sh

# Obter outputs importantes
./scripts/get-outputs.sh
```
