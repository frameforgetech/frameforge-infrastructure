# FrameForge Dev Environment Configuration

environment = "dev"
aws_region  = "us-east-1"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# Database Configuration (RDS PostgreSQL)
db_instance_class = "db.t3.micro"  # Free tier eligible

# EC2 Configuration (RabbitMQ + Redis)
ec2_instance_type = "t3.small"  # Runs both RabbitMQ and Redis

# EKS Configuration
eks_node_instance_type = "t3.medium"  # Changed from t3.small due to capacity issues
eks_desired_size       = 2
eks_min_size          = 2
eks_max_size          = 4

# S3 Configuration
# bucket_prefix will be used as: {prefix}-frameforge-videos-{env}
# Example: tharlysdias-frameforge-videos-dev
# Set this to your unique identifier (company name, username, etc.)
bucket_prefix = "tharlysdias"
