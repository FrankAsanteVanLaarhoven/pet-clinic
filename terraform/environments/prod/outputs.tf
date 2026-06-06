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
