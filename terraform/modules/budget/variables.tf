variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "alert_email" {
  description = "Email address to receive budget alert notifications"
  type        = string
}

variable "warn_threshold_usd" {
  description = "Monthly spend (USD) that triggers a WARNING notification"
  type        = number
  default     = 5
}

variable "alarm_threshold_usd" {
  description = "Monthly spend (USD) that triggers an ALARM notification"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
