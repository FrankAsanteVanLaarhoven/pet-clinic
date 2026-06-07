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

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
