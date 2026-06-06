locals {
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

# ── OpenAI API key ────────────────────────────────────────────────────────────

resource "aws_secretsmanager_secret" "openai_api_key" {
  name                    = "${var.project}/${var.environment}/openai-api-key"
  description             = "OpenAI API key for the genai-service in ${var.project}-${var.environment}"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${var.project}-${var.environment}-openai-api-key" })
}

resource "aws_secretsmanager_secret_version" "openai_api_key" {
  secret_id     = aws_secretsmanager_secret.openai_api_key.id
  secret_string = var.openai_api_key

  lifecycle {
    # Prevent Terraform from overwriting a key that was rotated out-of-band
    ignore_changes = [secret_string]
  }
}

# ── ESO IRSA role — allows the external-secrets ServiceAccount to read secrets ─

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "eso_secrets_policy" {
  statement {
    sid    = "AllowGetSecretValue"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.project}/${var.environment}/*",
    ]
  }
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${var.project}-${var.environment}-eso-secrets-policy"
  description = "Allows ESO to read ${var.project}/${var.environment}/* secrets"
  policy      = data.aws_iam_policy_document.eso_secrets_policy.json

  tags = local.common_tags
}
