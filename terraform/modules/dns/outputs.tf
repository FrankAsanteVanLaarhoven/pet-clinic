output "zone_id" {
  description = "Route 53 hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_name" {
  description = "Route 53 hosted zone domain name"
  value       = aws_route53_zone.main.name
}

output "name_servers" {
  description = "Route 53 NS records — delegate these from your registrar"
  value       = aws_route53_zone.main.name_servers
}

output "certificate_arn" {
  description = "ACM wildcard certificate ARN — empty string if create_certificate = false"
  value       = var.create_certificate ? aws_acm_certificate.wildcard[0].arn : ""
}

output "alb_controller_policy_arn" {
  description = "IAM policy ARN for the AWS Load Balancer Controller IRSA role"
  value       = aws_iam_policy.alb_controller.arn
}
