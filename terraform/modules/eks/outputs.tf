output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster (created by us)"
  value       = aws_security_group.cluster.id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "node_group_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

output "node_role_arn" {
  description = "IAM role ARN for node group"
  value       = aws_iam_role.node_group.arn
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${data.aws_region.current.name}"
}

output "api_gateway_sa_role_arn" {
  description = "IAM role ARN for API Gateway service account (IRSA)"
  value       = aws_iam_role.api_gateway_sa.arn
}

output "node_security_group_id" {
  description = "Security group ID attached to the EKS worker nodes"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# Helper data source for region
data "aws_region" "current" {}
