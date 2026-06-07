locals {
  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
    },
    var.tags,
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── GitHub Actions OIDC provider ──────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub's OIDC thumbprint — stable but can be omitted; AWS validates via CA
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(local.common_tags, { Name = "github-actions-oidc" })
}

# ── Trust policy — scoped to app repo main branch only ───────────────────────

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_app_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  description        = "OIDC role for GitHub Actions CI in ${var.github_org}/${var.github_app_repo}"

  tags = merge(local.common_tags, { Name = "${var.project}-github-actions-role" })
}

# ── ECR push permissions — least privilege, no cluster/state access ───────────

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid    = "AllowECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_policy" "ecr_push" {
  name        = "${var.project}-github-actions-ecr-push"
  description = "ECR push permissions for GitHub Actions CI"
  policy      = data.aws_iam_policy_document.ecr_push.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# ── Infra-ops role — trusts platform repo, used by scheduled workflows ────────

data "aws_iam_policy_document" "infra_ops_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Any workflow in the platform repo (nightly-stop, weekly-destroy, manual-start)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_platform_repo}:*"]
    }
  }
}

resource "aws_iam_role" "infra_ops" {
  name               = "${var.project}-github-infra-ops-role"
  assume_role_policy = data.aws_iam_policy_document.infra_ops_assume_role.json
  description        = "OIDC role for GitHub Actions scheduled infra workflows (stop/start/destroy)"

  tags = merge(local.common_tags, { Name = "${var.project}-github-infra-ops-role" })
}

# Scoped infra-ops policy: terraform state + all petclinic AWS resources
data "aws_iam_policy_document" "infra_ops" {
  # Terraform state backend
  statement {
    sid    = "TerraformStateS3"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
      "s3:ListBucket", "s3:GetBucketVersioning",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*",
    ]
  }

  statement {
    sid    = "TerraformStateDynamoDB"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = ["arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/petclinic-terraform-locks"]
  }

  # EKS — scale nodes + describe (for stop/start scripts)
  statement {
    sid    = "EKSManage"
    effect = "Allow"
    actions = [
      "eks:*",
    ]
    resources = ["arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/petclinic-*",
    "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:nodegroup/petclinic-*/*/*"]
  }

  # RDS — stop/start
  statement {
    sid    = "RDSManage"
    effect = "Allow"
    actions = [
      "rds:StopDBInstance", "rds:StartDBInstance",
      "rds:DescribeDBInstances", "rds:DeleteDBInstance",
      "rds:CreateDBInstance", "rds:ModifyDBInstance",
      "rds:CreateDBSubnetGroup", "rds:DeleteDBSubnetGroup", "rds:DescribeDBSubnetGroups",
      "rds:CreateDBParameterGroup", "rds:DeleteDBParameterGroup", "rds:DescribeDBParameterGroups",
      "rds:ModifyDBParameterGroup", "rds:DescribeDBParameters",
      "rds:AddTagsToResource", "rds:RemoveTagsFromResource", "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }

  # EC2 / VPC — full management for terraform apply/destroy
  statement {
    sid       = "EC2VPCManage"
    effect    = "Allow"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  # ECR — manage repos
  statement {
    sid       = "ECRManage"
    effect    = "Allow"
    actions   = ["ecr:*"]
    resources = ["*"]
  }

  # Secrets Manager — petclinic namespace only
  statement {
    sid    = "SecretsManage"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret",
      "secretsmanager:UpdateSecret", "secretsmanager:PutSecretValue",
      "secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret",
      "secretsmanager:TagResource", "secretsmanager:UntagResource",
      "secretsmanager:ListSecrets",
    ]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:petclinic/*"]
  }

  # Route 53 + ACM
  statement {
    sid       = "DNSTLSManage"
    effect    = "Allow"
    actions   = ["route53:*", "acm:*"]
    resources = ["*"]
  }

  # IAM — manage petclinic roles/policies only
  statement {
    sid    = "IAMManagePetclinic"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:PassRole", "iam:TagRole", "iam:UntagRole",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies", "iam:PutRolePolicy", "iam:DeleteRolePolicy",
      "iam:GetRolePolicy", "iam:CreatePolicy", "iam:DeletePolicy",
      "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion", "iam:ListPolicyVersions",
      "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider", "iam:TagOpenIDConnectProvider",
    ]
    resources = ["*"]
  }

  # Budgets
  statement {
    sid       = "BudgetsManage"
    effect    = "Allow"
    actions   = ["budgets:*"]
    resources = ["*"]
  }

  # STS — get caller identity (used by bootstrap + validation)
  statement {
    sid       = "STSIdentity"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "infra_ops" {
  name        = "${var.project}-github-infra-ops"
  description = "Scoped infra management permissions for GitHub Actions scheduled workflows"
  policy      = data.aws_iam_policy_document.infra_ops.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "infra_ops" {
  role       = aws_iam_role.infra_ops.name
  policy_arn = aws_iam_policy.infra_ops.arn
}
