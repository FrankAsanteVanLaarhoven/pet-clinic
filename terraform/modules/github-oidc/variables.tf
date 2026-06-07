variable "project" {
  description = "Project name"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation or username (e.g. FrankAsanteVanLaarhoven)"
  type        = string
}

variable "github_app_repo" {
  description = "Application repo name (build-push.yml lives here)"
  type        = string
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs the role is allowed to push to"
  type        = list(string)
}

variable "github_platform_repo" {
  description = "Platform repo name (pet-clinic) — infra-ops role trusts this repo"
  type        = string
  default     = "pet-clinic"
}

variable "state_bucket_name" {
  description = "S3 bucket name holding Terraform state — infra-ops role needs read/write access"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
