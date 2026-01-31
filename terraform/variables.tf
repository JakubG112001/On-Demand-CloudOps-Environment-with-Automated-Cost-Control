variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cloudops-platform"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email for notifications"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 2
}