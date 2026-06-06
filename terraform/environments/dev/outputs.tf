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
