variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS"
  type        = list(string)
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for nodes"
  type        = string
  default     = "t3.small"
}

variable "desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 4
}

variable "disk_size" {
  description = "Node disk size in GB"
  type        = number
  default     = 20
}

variable "enable_spot_instances" {
  description = "Use spot instances (60-90% cost savings)"
  type        = bool
  default     = false
}
