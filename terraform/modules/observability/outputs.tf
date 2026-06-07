output "cloudwatch_agent_role_arn" {
  description = "IRSA role ARN for the CloudWatch Container Insights agent"
  value       = aws_iam_role.cloudwatch_agent.arn
}

output "grafana_role_arn" {
  description = "IRSA role ARN for Grafana (read CloudWatch metrics + logs)"
  value       = aws_iam_role.grafana.arn
}
