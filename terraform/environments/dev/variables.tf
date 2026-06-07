variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "project" {
  description = "Project name used in resource naming and tags"
  type        = string
  default     = "petclinic"
}

variable "domain_name" {
  description = "Root domain name for Route 53 and ACM certificate (e.g. dev.petclinic.example.com)"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username that owns the app repo"
  type        = string
  default     = "FrankAsanteVanLaarhoven"
}

variable "github_app_repo" {
  description = "Application repo name containing build-push.yml"
  type        = string
  default     = "spring-petclinic-microservices"
}

variable "github_platform_repo" {
  description = "Platform repo name containing infra workflows (nightly-stop, weekly-destroy, manual-start)"
  type        = string
  default     = "pet-clinic"
}

variable "budget_alert_email" {
  description = "Email address for AWS Budget alerts ($5 warn, $10 alarm)"
  type        = string
  default     = "frankleroyvan@gmail.com"
}
