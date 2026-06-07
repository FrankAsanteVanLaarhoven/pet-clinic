output "controller_role_arn" {
  description = "IRSA role ARN for the Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "interruption_queue_url" {
  description = "SQS queue URL for Karpenter spot interruption handling"
  value       = aws_sqs_queue.interruption.url
}

output "interruption_queue_arn" {
  description = "SQS queue ARN for Karpenter spot interruption handling"
  value       = aws_sqs_queue.interruption.arn
}
