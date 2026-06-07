variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "security_group_id" {
  description = "RDS security group ID"
  type        = string
}

variable "instance_class" {
  description = "RDS instance class — must be free-tier eligible (db.t4g.micro or db.t3.micro)"
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = contains(["db.t4g.micro", "db.t3.micro"], var.instance_class)
    error_message = "instance_class must be db.t4g.micro or db.t3.micro (RDS free tier). Got: ${var.instance_class}"
  }
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB — capped at 20 GB (free tier limit)"
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage <= 20
    error_message = "allocated_storage must be ≤ 20 GB to stay within the RDS free tier."
  }
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling — set equal to allocated_storage to disable autoscaling"
  type        = number
  default     = 20

  validation {
    condition     = var.max_allocated_storage <= 20
    error_message = "max_allocated_storage must be ≤ 20 GB to prevent unexpected storage costs."
  }
}

variable "multi_az" {
  description = "Multi-AZ deployment — must stay false (doubles cost, not needed for dev)"
  type        = bool
  default     = false

  validation {
    condition     = var.multi_az == false
    error_message = "multi_az must be false. Multi-AZ doubles RDS cost (~$30/mo extra). Use read replicas if HA is needed."
  }
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
