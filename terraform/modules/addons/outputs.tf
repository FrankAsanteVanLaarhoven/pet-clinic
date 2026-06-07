output "eso_role_arn" {
  description = "IRSA role ARN for External Secrets Operator"
  value       = aws_iam_role.eso.arn
}

output "eso_role_name" {
  description = "IRSA role name for External Secrets Operator"
  value       = aws_iam_role.eso.name
}

output "alb_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_role_name" {
  description = "IRSA role name for the AWS Load Balancer Controller"
  value       = aws_iam_role.alb_controller.name
}
