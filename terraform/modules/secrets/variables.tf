variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "tags" {
  description = "Additional tags to merge onto resources"
  type        = map(string)
  default     = {}
}
