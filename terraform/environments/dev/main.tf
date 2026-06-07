# Dev environment root module

module "vpc" {
  source = "../../modules/vpc"

  project     = var.project
  environment = var.environment

  vpc_cidr            = "10.0.0.0/16"
  availability_zones  = ["eu-central-1a", "eu-central-1b"]
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
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

  image_tag_mutability = "MUTABLE"
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

# github-oidc is a global resource — provisioned once via dev environment
module "github_oidc" {
  source = "../../modules/github-oidc"

  project              = var.project
  github_org           = var.github_org
  github_app_repo      = var.github_app_repo
  github_platform_repo = var.github_platform_repo
  state_bucket_name    = "petclinic-terraform-state-${data.aws_caller_identity.current.account_id}"

  ecr_repository_arns = values(module.ecr.repository_arns)
}

# AWS Budget — email alerts at $5 (warn) and $10 (alarm)
module "budget" {
  source = "../../modules/budget"

  project     = var.project
  environment = var.environment
  alert_email = var.budget_alert_email

  warn_threshold_usd  = 5
  alarm_threshold_usd = 10
}

data "aws_caller_identity" "current" {}
