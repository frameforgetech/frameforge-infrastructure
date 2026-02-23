variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"  # Free tier eligible
}

variable "ec2_instance_type" {
  description = "EC2 instance type for RabbitMQ/Redis"
  type        = string
  default     = "t3.small"  # t3.micro might be too small for both services
}

variable "eks_node_instance_type" {
  description = "EKS node instance type"
  type        = string
  default     = "t3.small"
}

variable "eks_desired_size" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_max_size" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 4
}

variable "bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "tharlysdias"
}
