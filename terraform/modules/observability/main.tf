locals {
  name = "${var.project}-${var.environment}"
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags,
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ── CloudWatch Container Insights IRSA ───────────────────────────────────────

data "aws_iam_policy_document" "cloudwatch_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cloudwatch_agent" {
  name               = "${local.name}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.cloudwatch_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.name}-cloudwatch-agent-role" })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.cloudwatch_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ── Grafana IRSA (read CloudWatch metrics) ────────────────────────────────────

data "aws_iam_policy_document" "grafana_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:monitoring:grafana"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "grafana_cloudwatch" {
  statement {
    sid    = "AllowCloudWatchRead"
    effect = "Allow"
    actions = [
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:DescribeAlarmHistory",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetInsightRuleReport",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowLogsRead"
    effect = "Allow"
    actions = [
      "logs:DescribeLogGroups",
      "logs:GetLogGroupFields",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:GetLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowTagsRead"
    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ec2:DescribeInstances",
      "ec2:DescribeRegions",
      "tag:GetResources",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "grafana_cloudwatch" {
  name        = "${local.name}-grafana-cloudwatch-policy"
  description = "Allows Grafana to query CloudWatch metrics and logs in ${local.name}"
  policy      = data.aws_iam_policy_document.grafana_cloudwatch.json
  tags        = local.common_tags
}

resource "aws_iam_role" "grafana" {
  name               = "${local.name}-grafana-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.name}-grafana-role" })
}

resource "aws_iam_role_policy_attachment" "grafana" {
  role       = aws_iam_role.grafana.name
  policy_arn = aws_iam_policy.grafana_cloudwatch.arn
}
