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

variable "oidc_provider_arn" {
  description = "EKS OIDC identity provider ARN"
  type        = string
}

variable "oidc_provider_url" {
  description = "EKS OIDC identity provider URL without https://"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
