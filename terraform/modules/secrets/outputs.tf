output "openai_secret_arn" {
  description = "Secrets Manager ARN for the OpenAI API key"
  value       = aws_secretsmanager_secret.openai_api_key.arn
}

output "openai_secret_name" {
  description = "Secrets Manager name for the OpenAI API key"
  value       = aws_secretsmanager_secret.openai_api_key.name
}

output "eso_policy_arn" {
  description = "IAM policy ARN to attach to the ESO IRSA role"
  value       = aws_iam_policy.eso_secrets.arn
}
