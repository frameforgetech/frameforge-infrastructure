output "rabbitmq_instance_id" {
  description = "RabbitMQ instance ID"
  value       = aws_instance.rabbitmq.id
}

output "rabbitmq_private_ip" {
  description = "RabbitMQ private IP"
  value       = aws_instance.rabbitmq.private_ip
}

output "rabbitmq_security_group_id" {
  description = "RabbitMQ security group ID"
  value       = aws_security_group.rabbitmq.id
}

output "redis_instance_id" {
  description = "Redis instance ID"
  value       = aws_instance.redis.id
}

output "redis_private_ip" {
  description = "Redis private IP"
  value       = aws_instance.redis.private_ip
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}
