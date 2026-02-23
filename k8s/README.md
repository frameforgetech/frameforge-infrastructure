# FrameForge - Kubernetes Manifests

Manifests para deploy dos microserviços no EKS.

## 📋 Pré-requisitos

1. **Infraestrutura Terraform criada**
   ```bash
   cd ../scripts
   ./apply-dev.sh
   ```

2. **kubectl configurado**
   ```bash
   aws eks update-kubeconfig --name frameforge-dev --region us-east-1
   kubectl get nodes  # Verificar conexão
   ```

3. **Docker images buildadas**
   ```bash
   # No diretório de cada microserviço
   docker build -t frameforge-auth-service:latest .
   docker build -t frameforge-api-gateway:latest .
   docker build -t frameforge-video-processor:latest .
   docker build -t frameforge-notification-service:latest .
   ```

4. **Obter valores do Terraform**
   ```bash
   cd ../scripts
   ./get-outputs.sh
   ```

## 🚀 Deploy Rápido

### 1. Criar Secrets

```bash
# Obter valores do Terraform
cd ../terraform/environments/dev
DB_HOST=$(terraform output -raw db_address)
DB_SECRET_ARN=$(terraform output -raw db_secret_arn)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id $DB_SECRET_ARN --query SecretString --output text | jq -r .password)
RABBITMQ_HOST=$(terraform output -raw rabbitmq_private_ip)
REDIS_HOST=$(terraform output -raw redis_private_ip)
S3_VIDEOS=$(terraform output -raw videos_bucket)
S3_RESULTS=$(terraform output -raw results_bucket)

# Criar secret no Kubernetes
cd ../../k8s
kubectl create secret generic frameforge-secrets \
  --namespace=frameforge \
  --from-literal=jwt-secret='super-secret-jwt-key-change-in-production-min-32-chars' \
  --from-literal=db-username='frameforge_admin' \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=db-host="$DB_HOST" \
  --from-literal=rabbitmq-username='frameforge' \
  --from-literal=rabbitmq-password='frameforge123' \
  --from-literal=rabbitmq-host="$RABBITMQ_HOST" \
  --from-literal=redis-host="$REDIS_HOST" \
  --from-literal=redis-password='' \
  --from-literal=aws-access-key-id='' \
  --from-literal=aws-secret-access-key='' \
  --from-literal=aws-region='us-east-1' \
  --from-literal=s3-videos-bucket="$S3_VIDEOS" \
  --from-literal=s3-results-bucket="$S3_RESULTS"
```

### 2. Aplicar Manifests

```bash
# Namespace e configuração
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f serviceaccount.yaml

# Deployments
kubectl apply -f deployments/

# Services
kubectl apply -f services/

# Horizontal Pod Autoscalers
kubectl apply -f hpa/
```

### 3. Verificar Deploy

```bash
# Ver todos os recursos
kubectl get all -n frameforge

# Ver pods
kubectl get pods -n frameforge

# Ver logs de um pod
kubectl logs -n frameforge -l app=api-gateway --tail=50 -f

# Ver services
kubectl get svc -n frameforge

# Pegar URL do LoadBalancer
kubectl get svc api-gateway -n frameforge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 📁 Estrutura

```
k8s/
├── namespace.yaml              # Namespace frameforge
├── configmap.yaml              # Variáveis de ambiente não-sensíveis
├── secrets.yaml.template       # Template para secrets (NÃO commitar com valores reais)
├── serviceaccount.yaml         # Service Account com IRSA
├── deployments/
│   ├── auth-service.yaml       # Auth service (2 replicas)
│   ├── api-gateway.yaml        # API Gateway (2 replicas)
│   ├── video-processor.yaml    # Video Processor (2 replicas)
│   └── notification-service.yaml # Notification (1 replica)
├── services/
│   ├── auth-service.yaml       # ClusterIP
│   ├── api-gateway.yaml        # LoadBalancer (ponto de entrada)
│   ├── video-processor.yaml    # ClusterIP
│   └── notification-service.yaml # ClusterIP
├── hpa/
│   ├── api-gateway-hpa.yaml    # 2-10 replicas
│   └── video-processor-hpa.yaml # 2-20 replicas
└── README.md
```

## 🎯 Recursos por Serviço

### Auth Service
- **Replicas**: 2
- **Resources**: 128Mi-256Mi RAM, 100m-200m CPU
- **Type**: ClusterIP (interno)
- **Health checks**: /health

### API Gateway
- **Replicas**: 2-10 (HPA)
- **Resources**: 256Mi-512Mi RAM, 200m-500m CPU
- **Type**: LoadBalancer (externo)
- **HPA**: Scale em CPU 70%, Memory 80%

### Video Processor
- **Replicas**: 2-20 (HPA)
- **Resources**: 512Mi-2Gi RAM, 500m-1000m CPU
- **Type**: ClusterIP (worker)
- **HPA**: Scale em CPU 75%, Memory 85%

### Notification Service
- **Replicas**: 1
- **Resources**: 128Mi-256Mi RAM, 100m-200m CPU
- **Type**: ClusterIP (worker)

## 🔧 Comandos Úteis

### Scaling Manual

```bash
# Escalar manualmente
kubectl scale deployment api-gateway -n frameforge --replicas=5

# Ver status do HPA
kubectl get hpa -n frameforge

# Descrever HPA
kubectl describe hpa api-gateway-hpa -n frameforge
```

### Debugging

```bash
# Logs de todos os pods de um deployment
kubectl logs -n frameforge -l app=video-processor --tail=100

# Entrar em um pod
kubectl exec -it -n frameforge $(kubectl get pod -n frameforge -l app=api-gateway -o jsonpath='{.items[0].metadata.name}') -- /bin/sh

# Ver eventos
kubectl get events -n frameforge --sort-by='.lastTimestamp'

# Ver resource usage
kubectl top pods -n frameforge
kubectl top nodes
```

### Atualizar Deployment

```bash
# Rebuild e tag nova imagem
docker build -t frameforge-api-gateway:v2 .

# Update deployment
kubectl set image deployment/api-gateway -n frameforge api-gateway=frameforge-api-gateway:v2

# Verificar rollout
kubectl rollout status deployment/api-gateway -n frameforge

# Rollback se necessário
kubectl rollout undo deployment/api-gateway -n frameforge
```

### Atualizar Secrets

```bash
# Deletar secret existente
kubectl delete secret frameforge-secrets -n frameforge

# Recriar com novos valores
kubectl create secret generic frameforge-secrets ...

# Restart deployments para pegar novos secrets
kubectl rollout restart deployment -n frameforge
```

## 🌐 Acessar a API

```bash
# Obter URL do LoadBalancer
export LB_URL=$(kubectl get svc api-gateway -n frameforge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "API Gateway: http://$LB_URL"

# Testar health
curl http://$LB_URL/health

# Registrar usuário
curl -X POST http://$LB_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","name":"Test User"}'

# Login
curl -X POST http://$LB_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}'

# Upload vídeo (com token)
curl -X POST http://$LB_URL/videos/upload \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "video=@test.mp4"
```

## 🔒 Segurança

### Secrets Management

- **NÃO commitar** `secrets.yaml` com valores reais
- Use AWS Secrets Manager para valores sensíveis
- Considere usar External Secrets Operator
- Rotate secrets periodically

### Service Account (IRSA)

Para acesso ao S3 sem credentials hardcoded:

1. Criar IAM role com trust policy para OIDC
2. Anotar ServiceAccount com role ARN
3. Pods automaticamente assumem a role

### Network Policies (Opcional)

Criar NetworkPolicies para restringir tráfego entre pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: video-processor-policy
  namespace: frameforge
spec:
  podSelector:
    matchLabels:
      app: video-processor
  policyTypes:
  - Ingress
  - Egress
  ingress: []  # Nenhum ingress (worker apenas)
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: notification-service
```

## 📊 Monitoramento

### Métricas

```bash
# Ver métricas de recursos
kubectl top pods -n frameforge
kubectl top nodes

# Ver HPA status
kubectl get hpa -n frameforge -w
```

### Logs Centralizados

Considere adicionar:
- **Fluentd/Fluent Bit**: Para shipping de logs
- **CloudWatch Logs Insights**: Para análise
- **ELK Stack**: Elasticsearch, Logstash, Kibana

### Prometheus + Grafana

Os microserviços já exportam métricas. Adicione:

```bash
# Instalar Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Port-forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## 🧹 Cleanup

```bash
# Deletar tudo do namespace
kubectl delete namespace frameforge

# Ou deletar recursos individuais
kubectl delete -f hpa/
kubectl delete -f services/
kubectl delete -f deployments/
kubectl delete -f configmap.yaml
kubectl delete -f serviceaccount.yaml
kubectl delete secret frameforge-secrets -n frameforge
kubectl delete -f namespace.yaml
```

## 🆘 Troubleshooting

### Pods não iniciam

```bash
# Ver detalhes do pod
kubectl describe pod POD_NAME -n frameforge

# Ver logs
kubectl logs POD_NAME -n frameforge

# Problemas comuns:
# - ImagePullError: Imagem não existe localmente/registry
# - CrashLoopBackOff: Container crashando (ver logs)
# - Pending: Recursos insuficientes (ver kubectl describe)
```

### LoadBalancer não cria

```bash
# Ver service
kubectl describe svc api-gateway -n frameforge

# Ver eventos
kubectl get events -n frameforge | grep LoadBalancer

# Verificar AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller
```

### HPA não scala

```bash
# Verificar metrics server
kubectl get deployment metrics-server -n kube-system

# Instalar se não existir
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Ver métricas disponíveis
kubectl top pods -n frameforge
```

### Problemas de conectividade

```bash
# Testar DNS interno
kubectl run -it --rm debug --image=busybox --restart=Never -n frameforge -- nslookup auth-service

# Testar conectividade entre pods
kubectl exec -it POD_NAME -n frameforge -- curl http://auth-service:3001/health

# Ver network policies
kubectl get networkpolicy -n frameforge
```

## 📚 Referências

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [IRSA (IAM Roles for Service Accounts)](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
