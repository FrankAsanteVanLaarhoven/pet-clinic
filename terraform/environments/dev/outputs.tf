# ── VPC ───────────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "Dev VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "Dev VPC CIDR"
  value       = module.vpc.vpc_cidr
}

output "subnet_ids" {
  description = "Dev public subnet IDs"
  value       = module.vpc.subnet_ids
}

output "alb_sg_id" {
  description = "Dev ALB security group ID"
  value       = module.vpc.alb_sg_id
}

output "eks_cluster_sg_id" {
  description = "Dev EKS cluster security group ID"
  value       = module.vpc.eks_cluster_sg_id
}

output "eks_node_sg_id" {
  description = "Dev EKS node security group ID"
  value       = module.vpc.eks_node_sg_id
}

output "rds_sg_id" {
  description = "Dev RDS security group ID"
  value       = module.vpc.rds_sg_id
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "Dev EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Dev EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Dev EKS cluster CA certificate (base64)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "Dev OIDC provider ARN"
  value       = module.eks.oidc_provider_arn
}

output "eks_oidc_provider_url" {
  description = "Dev OIDC provider URL"
  value       = module.eks.oidc_provider_url
}

output "eks_node_role_arn" {
  description = "Dev EKS node IAM role ARN"
  value       = module.eks.node_role_arn
}

# ── ECR ───────────────────────────────────────────────────────────────────────
output "ecr_repository_urls" {
  description = "Dev ECR repository URLs (service_name → URL)"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Dev ECR repository ARNs (service_name → ARN)"
  value       = module.ecr.repository_arns
}

# ── RDS ───────────────────────────────────────────────────────────────────────
output "rds_endpoint" {
  description = "Dev RDS endpoint hostname"
  value       = module.rds.endpoint
}

output "rds_port" {
  description = "Dev RDS port"
  value       = module.rds.port
}

output "rds_secret_arn" {
  description = "Dev RDS credentials secret ARN"
  value       = module.rds.secret_arn
}

# ── Secrets ───────────────────────────────────────────────────────────────────
output "openai_secret_arn" {
  description = "Dev OpenAI API key secret ARN"
  value       = module.secrets.openai_secret_arn
}

output "eso_policy_arn" {
  description = "Dev ESO IAM policy ARN (attach to ESO IRSA role)"
  value       = module.secrets.eso_policy_arn
}

# ── DNS ───────────────────────────────────────────────────────────────────────
output "route53_zone_id" {
  description = "Dev Route 53 hosted zone ID"
  value       = module.dns.zone_id
}

output "route53_name_servers" {
  description = "Dev Route 53 NS records — delegate from registrar"
  value       = module.dns.name_servers
}

output "acm_certificate_arn" {
  description = "Dev ACM wildcard certificate ARN"
  value       = module.dns.certificate_arn
}

output "alb_controller_policy_arn" {
  description = "Dev ALB Controller IAM policy ARN"
  value       = module.dns.alb_controller_policy_arn
}

# ── GitHub Actions OIDC ───────────────────────────────────────────────────────
output "github_actions_role_arn" {
  description = "AWS_ROLE_ARN — set this as a GitHub secret in the app repo"
  value       = module.github_oidc.role_arn
}
