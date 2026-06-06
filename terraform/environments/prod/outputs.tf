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
