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

variable "domain_name" {
  description = "Root domain name for the Route 53 hosted zone (e.g. petclinic.example.com)"
  type        = string
}

variable "create_certificate" {
  description = "Create ACM wildcard cert. Set false until NS records are delegated to Route 53 — the provider blocks until the cert is ISSUED."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
