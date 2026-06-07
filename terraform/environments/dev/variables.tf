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
