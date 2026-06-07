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

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.30"
}

variable "subnet_ids" {
  description = "Subnet IDs where the cluster and node group are placed"
  type        = list(string)
}

variable "cluster_sg_id" {
  description = "Security group ID for the EKS cluster control plane"
  type        = string
}

variable "node_sg_id" {
  description = "Security group ID for EKS worker nodes"
  type        = string
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group — must be Graviton free-trial eligible (t4g.*)"
  type        = list(string)
  default     = ["t4g.small"]

  validation {
    condition = alltrue([
      for t in var.node_instance_types : can(regex("^t4g\\.", t))
    ])
    error_message = "node_instance_types must only contain t4g.* Graviton types (free trial until Dec 2026). Got: ${join(", ", var.node_instance_types)}"
  }
}

variable "node_ami_type" {
  description = "AMI type for node group (AL2_ARM_64 for Graviton)"
  type        = string
  default     = "AL2_ARM_64"
}

variable "node_min_size" {
  description = "Minimum number of nodes (0 = allow scale-to-zero for cost stop)"
  type        = number
  default     = 0

  validation {
    condition     = var.node_min_size >= 0 && var.node_min_size <= 2
    error_message = "node_min_size must be 0–2 to keep costs minimal."
  }
}

variable "node_max_size" {
  description = "Maximum number of nodes — capped at 4 to prevent runaway scaling costs"
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size <= 4
    error_message = "node_max_size must be ≤ 4 to cap costs. Use Karpenter for burst scaling."
  }
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Root EBS disk size in GB per node — capped at 20 GB (gp3 free-tier equivalent)"
  type        = number
  default     = 20

  validation {
    condition     = var.node_disk_size <= 20
    error_message = "node_disk_size must be ≤ 20 GB to minimise EBS costs."
  }
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
