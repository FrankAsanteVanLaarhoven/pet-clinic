# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "Prod VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Prod VPC CIDR"
  value       = module.vpc.vpc_cidr
}

output "subnet_ids" {
  description = "Prod public subnet IDs"
  value       = module.vpc.subnet_ids
}

output "alb_sg_id" {
  description = "Prod ALB security group ID"
  value       = module.vpc.alb_sg_id
}

output "eks_cluster_sg_id" {
  description = "Prod EKS cluster security group ID"
  value       = module.vpc.eks_cluster_sg_id
}

output "eks_node_sg_id" {
  description = "Prod EKS node security group ID"
  value       = module.vpc.eks_node_sg_id
}

output "rds_sg_id" {
  description = "Prod RDS security group ID"
  value       = module.vpc.rds_sg_id
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "Prod EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Prod EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Prod EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "Prod OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "Prod OIDC provider URL"
  value       = module.eks.oidc_provider_url
}

output "eks_node_role_arn" {
  description = "Prod EKS node IAM role ARN"
  value       = module.eks.node_role_arn
}

# ── ECR ───────────────────────────────────────────────────────────────────────
output "ecr_repository_urls" {
  description = "Prod ECR repository URLs (service_name → URL)"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Prod ECR repository ARNs (service_name → ARN)"
  value       = module.ecr.repository_arns
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "Prod RDS endpoint hostname"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Prod RDS port"
  value       = module.rds.port
}

output "rds_secret_arn" {
  description = "Prod RDS credentials secret ARN"
  value       = module.rds.secret_arn
}

# ── Secrets ───────────────────────────────────────────────────────────────────
output "openai_secret_arn" {
  description = "Prod OpenAI API key secret ARN"
  value       = module.secrets.openai_secret_arn
}

output "eso_policy_arn" {
  description = "Prod ESO IAM policy ARN (attach to ESO IRSA role)"
  value       = module.secrets.eso_policy_arn
}

# ── DNS ───────────────────────────────────────────────────────────────────────
output "route53_zone_id" {
  description = "Prod Route 53 hosted zone ID"
  value       = module.dns.zone_id
}

output "route53_name_servers" {
  description = "Prod Route 53 NS records — delegate from registrar"
  value       = module.dns.name_servers
}

output "acm_certificate_arn" {
  description = "Prod ACM wildcard certificate ARN"
  value       = module.dns.certificate_arn
}

output "alb_controller_policy_arn" {
  description = "Prod ALB Controller IAM policy ARN"
  value       = module.dns.alb_controller_policy_arn
}

# ── Addon IRSA Roles ──────────────────────────────────────────────────────────
output "eso_role_arn" {
  description = "ESO IRSA role ARN — pass to install-addons.sh as ESO_ROLE_ARN"
  value       = module.addons.eso_role_arn
}

output "alb_controller_role_arn" {
  description = "ALB Controller IRSA role ARN — pass to install-addons.sh as ALB_ROLE_ARN"
  value       = module.addons.alb_controller_role_arn
}

output "karpenter_controller_role_arn" {
  description = "Karpenter controller IRSA role ARN"
  value       = module.karpenter.controller_role_arn
}

output "karpenter_interruption_queue_url" {
  description = "Karpenter interruption SQS queue URL"
  value       = module.karpenter.interruption_queue_url
}

output "cloudwatch_agent_role_arn" {
  description = "CloudWatch agent IRSA role ARN"
  value       = module.observability.cloudwatch_agent_role_arn
}

output "grafana_role_arn" {
  description = "Grafana IRSA role ARN (read CloudWatch metrics)"
  value       = module.observability.grafana_role_arn
}
