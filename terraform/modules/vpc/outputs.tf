output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "List of public subnet IDs (AZ a, AZ b)"
  value       = aws_subnet.public[*].id
}

output "subnet_cidrs" {
  description = "List of public subnet CIDRs"
  value       = aws_subnet.public[*].cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "alb_sg_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "eks_cluster_sg_id" {
  description = "EKS cluster control-plane security group ID"
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_sg_id" {
  description = "EKS node security group ID"
  value       = aws_security_group.eks_node.id
}

output "rds_sg_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}
