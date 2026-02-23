# FrameForge Custom Metrics

Este diretório contém configurações para métricas customizadas dos serviços FrameForge.

## 📊 Métricas Disponíveis

### API Gateway
- `http_requests_total` - Total de requisições HTTP
- `http_request_duration_seconds` - Duração das requisições
- `video_upload_requests_total` - Requisições de upload
- `video_job_queries_total` - Consultas de jobs

### Auth Service
- `auth_registration_attempts_total` - Tentativas de registro
- `auth_login_attempts_total` - Tentativas de login
- `auth_token_validation_total` - Validações de token

### Video Processor
- `video_processor_jobs_processed_total` - Jobs processados com sucesso
- `video_processor_jobs_failed_total` - Jobs que falharam
- `video_processor_processing_duration_seconds` - Duração do processamento
- `video_processor_queue_depth` - Profundidade da fila
- `video_processor_frames_extracted_total` - Total de frames extraídos

### Notification Service
- `notification_service_notifications_sent_total` - Notificações enviadas
- `notification_service_notifications_failed_total` - Notificações que falharam
- `notification_service_notification_duration_seconds` - Duração do envio
- `notification_service_retry_attempts_total` - Tentativas de retry

## 🚀 Setup

### Instalação Automática

```bash
cd frameforge-infrastructure/scripts
chmod +x setup-metrics.sh
./setup-metrics.sh
```

### Instalação Manual

1. **Aplicar Services atualizados:**
```bash
kubectl apply -f k8s/services/
```

2. **Aplicar Deployments atualizados:**
```bash
kubectl apply -f k8s/deployments/
```

3. **Criar ServiceMonitors:**
```bash
kubectl apply -f k8s/monitoring/servicemonitor.yaml
```

4. **Importar Dashboard no Grafana:**
   - Port-forward: `kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80`
   - Acesse: http://localhost:3000
   - Login: admin / admin123
   - Import dashboard: `k8s/monitoring/grafana-dashboard.json`

## 📈 Visualização

### Prometheus

Verificar targets sendo coletados:

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Acesse: http://localhost:9090/targets

### Grafana

Dashboard customizado "FrameForge Services Metrics" inclui:

1. **API Gateway**
   - Request rate por endpoint
   - Response time percentis (p50, p95, p99)
   - Status codes

2. **Auth Service**
   - Taxa de sucesso de registro
   - Taxa de sucesso de login
   - Validações de token por minuto

3. **Video Processor**
   - Jobs processados vs falhados
   - Duração de processamento (p50, p95, p99)
   - Profundidade da fila em tempo real
   - Total de frames extraídos

4. **Notification Service**
   - Taxa de sucesso de envio
   - Notificações por tipo
   - Duração de envio
   - Tentativas de retry

5. **Service Health**
   - Tabela de status de todos os serviços

## 🔍 Queries Úteis

### Taxa de erro da API
```promql
rate(http_requests_total{status_code=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100
```

### Tempo médio de processamento de vídeo
```promql
rate(video_processor_processing_duration_seconds_sum[5m]) / rate(video_processor_processing_duration_seconds_count[5m])
```

### Taxa de falha de login
```promql
rate(auth_login_attempts_total{status="failure"}[5m]) / rate(auth_login_attempts_total[5m]) * 100
```

### Notificações pendentes (queue depth)
```promql
video_processor_queue_depth
```

## 🔧 Troubleshooting

### Métricas não aparecem no Prometheus

1. Verificar se ServiceMonitors foram criados:
```bash
kubectl get servicemonitor -n frameforge
```

2. Verificar se Prometheus está selecionando os ServiceMonitors:
```bash
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector
```

3. Verificar endpoints dos pods:
```bash
# API Gateway (métricas em /metrics)
kubectl port-forward -n frameforge svc/api-gateway 3000:80
curl http://localhost:3000/metrics

# Video Processor (porta separada 9091)
kubectl port-forward -n frameforge svc/video-processor 9091:9091
curl http://localhost:9091/metrics

# Notification Service (porta separada 9092)
kubectl port-forward -n frameforge svc/notification-service 9092:9092
curl http://localhost:9092/metrics
```

4. Verificar logs do Prometheus:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus
```

### Dashboard não carrega

1. Verificar se Prometheus está configurado como datasource
2. Verificar se as queries estão retornando dados no Prometheus UI
3. Aguardar 1-2 minutos após deploy para métricas aparecerem

## 📝 Configuração do Prometheus

O Prometheus Operator usa ServiceMonitors para descobrir targets automaticamente.

**Importante**: O Helm chart `kube-prometheus-stack` foi instalado com:
```bash
--set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Isso permite que o Prometheus descubra ServiceMonitors de qualquer namespace com label `release: prometheus`.

## 🎯 Alertas (Futuro)

Para adicionar alertas, crie PrometheusRules:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: frameforge-alerts
  namespace: frameforge
  labels:
    release: prometheus
spec:
  groups:
  - name: frameforge
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
```
