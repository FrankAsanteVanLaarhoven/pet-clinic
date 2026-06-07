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

variable "cluster_name" {
  description = "EKS cluster name (used in trust policy and node instance profile)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "EKS OIDC identity provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC identity provider URL without https://"
  type        = string
}

variable "node_role_arn" {
  description = "EKS managed node group IAM role ARN — reused by Karpenter nodes"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
