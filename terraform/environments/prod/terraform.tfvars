# FrameForge Production Environment Configuration

environment = "prod"
aws_region  = "us-east-1"

# Network Configuration
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Database Configuration (RDS PostgreSQL)
db_instance_class = "db.r5.large"  # Production-grade instance

# EC2 Configuration (RabbitMQ + Redis)
ec2_instance_type = "t3.medium"

# EKS Configuration
eks_node_instance_type = "t3.medium"
eks_desired_size       = 3
eks_min_size          = 3
eks_max_size          = 10

# S3 Configuration
# bucket_prefix will be used as: {prefix}-frameforge-videos-{env}
# Example: tharlysdias-frameforge-videos-prod
bucket_prefix = "tharlysdias"
