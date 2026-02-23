# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  environment        = var.environment
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
}

# S3 Module
module "s3" {
  source = "../../modules/s3"

  environment   = var.environment
  bucket_prefix = var.bucket_prefix
}

# RDS Module
module "rds" {
  source = "../../modules/rds"

  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
  instance_class = var.db_instance_class
  multi_az       = false  # Single AZ for dev (cost savings)

  allowed_security_group_ids = [
    module.ec2.rabbitmq_security_group_id,
    module.ec2.redis_security_group_id
  ]
}

# Additional rule to allow EKS nodes to access RDS
# Note: This rule is created after EKS is created to avoid data source lookup errors
# when the cluster doesn't exist yet

# EC2 Module (RabbitMQ + Redis)
module "ec2" {
  source = "../../modules/ec2"

  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnet_ids
  instance_type = var.ec2_instance_type
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  environment        = var.environment
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.private_subnet_ids
  node_instance_type = var.eks_node_instance_type
  desired_size      = var.eks_desired_size
  min_size          = var.eks_min_size
  max_size          = var.eks_max_size
  enable_spot_instances = false  # Changed to false due to capacity issues
}

# Security group rule to allow EKS nodes to access RDS
# This is defined after the EKS module to ensure it exists
resource "aws_security_group_rule" "rds_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = module.eks.node_security_group_id
  security_group_id        = module.rds.db_security_group_id
  description              = "Allow PostgreSQL access from EKS worker nodes"
}
