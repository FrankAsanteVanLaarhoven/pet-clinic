# Prod environment root module

module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  vpc_cidr            = "10.1.0.0/16"
  availability_zones  = ["eu-central-1a", "eu-central-1b"]
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]
}

module "eks" {
  source = "../../modules/eks"

  project     = var.project
  environment = var.environment

  subnet_ids    = module.vpc.subnet_ids
  cluster_sg_id = module.vpc.eks_cluster_sg_id
  node_sg_id    = module.vpc.eks_node_sg_id
}

module "ecr" {
  source = "../../modules/ecr"

  project     = var.project
  environment = var.environment

  service_names = [
    "config-server",
    "discovery-server",
    "api-gateway",
    "customers-service",
    "visits-service",
    "vets-service",
    "genai-service",
    "admin-server",
  ]

  image_tag_mutability = "IMMUTABLE"
}

module "rds" {
  source = "../../modules/rds"

  project     = var.project
  environment = var.environment

  subnet_ids        = module.vpc.subnet_ids
  security_group_id = module.vpc.rds_sg_id
}

module "secrets" {
  source = "../../modules/secrets"

  project     = var.project
  environment = var.environment
  # openai_api_key is supplied via TF_VAR_openai_api_key env var — never in tfvars
}

module "dns" {
  source = "../../modules/dns"

  project     = var.project
  environment = var.environment
  domain_name = var.domain_name
}

# github-oidc is a GLOBAL resource — already provisioned via dev environment. Do NOT add here.

module "budget" {
  source = "../../modules/budget"

  project     = var.project
  environment = var.environment
  alert_email = var.budget_alert_email

  warn_threshold_usd  = 15
  alarm_threshold_usd = 30
}

module "karpenter" {
  source = "../../modules/karpenter"

  project     = var.project
  environment = var.environment

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  node_role_arn     = module.eks.node_role_arn
}

module "observability" {
  source = "../../modules/observability"

  project     = var.project
  environment = var.environment

  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
}

module "addons" {
  source = "../../modules/addons"

  project     = var.project
  environment = var.environment

  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  eso_policy_arn            = module.secrets.eso_policy_arn
  alb_controller_policy_arn = module.dns.alb_controller_policy_arn
}

data "aws_caller_identity" "current" {}

# Allow traffic between the EKS-managed node primary SG and the Karpenter/node SG.
# This is required when workloads are split across managed nodegroup nodes and Karpenter nodes.
resource "aws_vpc_security_group_ingress_rule" "karpenter_ingress_from_managed_nodes_all" {
  security_group_id            = module.vpc.eks_node_sg_id
  referenced_security_group_id = module.eks.cluster_security_group_id
  ip_protocol                  = "-1"
  description                  = "All traffic from EKS-managed nodes"
}

resource "aws_vpc_security_group_ingress_rule" "managed_nodes_ingress_from_karpenter_all" {
  security_group_id            = module.eks.cluster_security_group_id
  referenced_security_group_id = module.vpc.eks_node_sg_id
  ip_protocol                  = "-1"
  description                  = "All traffic from Karpenter/node SG"
}
