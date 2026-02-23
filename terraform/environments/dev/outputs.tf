# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# S3 Outputs
output "videos_bucket" {
  description = "Videos S3 bucket"
  value       = module.s3.videos_bucket_id
}

output "results_bucket" {
  description = "Results S3 bucket"
  value       = module.s3.results_bucket_id
}

# RDS Outputs
output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "db_address" {
  description = "RDS address"
  value       = module.rds.db_instance_address
}

output "db_secret_arn" {
  description = "ARN of secret containing DB credentials"
  value       = module.rds.db_secret_arn
}

# EC2 Outputs
output "rabbitmq_private_ip" {
  description = "RabbitMQ private IP"
  value       = module.ec2.rabbitmq_private_ip
}

output "redis_private_ip" {
  description = "Redis private IP"
  value       = module.ec2.redis_private_ip
}

# EKS Outputs
output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_kubeconfig_command" {
  description = "Command to configure kubectl"
  value       = module.eks.kubeconfig_command
}

# Connection Strings (sensitive)
output "database_url" {
  description = "PostgreSQL connection URL"
  value       = "postgresql://frameforge_admin:PASSWORD@${module.rds.db_instance_address}:${module.rds.db_instance_port}/frameforge"
  sensitive   = true
}

output "rabbitmq_url" {
  description = "RabbitMQ connection URL"
  value       = "amqp://frameforge:frameforge123@${module.ec2.rabbitmq_private_ip}:5672"
  sensitive   = true
}

output "redis_url" {
  description = "Redis connection URL"
  value       = "redis://${module.ec2.redis_private_ip}:6379"
  sensitive   = true
}

# IRSA Outputs
output "eks_api_gateway_sa_role_arn" {
  description = "ARN of IAM role for API Gateway service account (IRSA)"
  value       = module.eks.api_gateway_sa_role_arn
}

# Instructions
output "next_steps" {
  description = "Next steps after infrastructure is created"
  value       = <<-EOT
    
    ========================================
    FrameForge Infrastructure Created!
    ========================================
    
    1. Get RDS password from AWS Secrets Manager:
       aws secretsmanager get-secret-value --secret-id ${module.rds.db_secret_arn} --query SecretString --output text | jq -r .password
    
    2. Configure kubectl:
       ${module.eks.kubeconfig_command}
    
    3. Connect to RabbitMQ Management:
       SSH tunnel: ssh -L 15672:${module.ec2.rabbitmq_private_ip}:15672 ec2-user@BASTION_IP
       Then open: http://localhost:15672 (frameforge/frameforge123)
    
    4. Update Kubernetes secrets:
       kubectl create secret generic frameforge-secrets \
         --from-literal=db-host=${module.rds.db_instance_address} \
    5. Deploy services using k8s/host=${module.ec2.rabbitmq_private_ip} \
         --from-literal=redis-host=${module.ec2.redis_private_ip}
    
    4. Deploy services using k8s/
    
    ========================================
    COST WARNING: Remember to destroy when not in use!
    terraform destroy -auto-approve
    ========================================
  EOT
}
