variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_prefix" {
  description = "Prefix for bucket names (e.g., company name)"
  type        = string
  default     = "tharlysdias"
}

variable "videos_bucket_name" {
  description = "Name for videos bucket"
  type        = string
  default     = ""
}

variable "results_bucket_name" {
  description = "Name for results bucket"
  type        = string
  default     = ""
}

variable "lifecycle_days" {
  description = "Days before objects are deleted"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
