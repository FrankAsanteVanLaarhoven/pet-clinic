output "role_arn" {
  description = "IAM role ARN — set as AWS_ROLE_ARN GitHub secret in the app repo"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "IAM role name"
  value       = aws_iam_role.github_actions.name
}

output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "infra_ops_role_arn" {
  description = "IAM role ARN for scheduled infra workflows (stop/start/destroy) — set as INFRA_ROLE_ARN GitHub secret"
  value       = aws_iam_role.infra_ops.arn
}

output "infra_ops_role_name" {
  description = "IAM role name for infra-ops"
  value       = aws_iam_role.infra_ops.name
}
