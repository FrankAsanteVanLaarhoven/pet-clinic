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

# ── Karpenter Controller IRSA ─────────────────────────────────────────────────

data "aws_iam_policy_document" "karpenter_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid    = "AllowEC2ForNodeManagement"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplate",
      "ec2:CreateFleet",
      "ec2:RunInstances",
      "ec2:CreateTags",
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeSpotPriceHistory",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AllowIAMPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [var.node_role_arn]
  }

  statement {
    sid    = "AllowSQSInterruption"
    effect = "Allow"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage",
    ]
    resources = [aws_sqs_queue.interruption.arn]
  }

  statement {
    sid       = "AllowPricingRead"
    effect    = "Allow"
    actions   = ["pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEKSRead"
    effect = "Allow"
    actions = [
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
    ]
    resources = ["arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.name}-karpenter-controller-policy"
  description = "Allows Karpenter to manage EC2 nodes in ${local.name}"
  policy      = data.aws_iam_policy_document.karpenter_controller.json
  tags        = local.common_tags
}

resource "aws_iam_role" "karpenter_controller" {
  name               = "${local.name}-karpenter-controller-role"
  assume_role_policy = data.aws_iam_policy_document.karpenter_assume_role.json
  tags               = merge(local.common_tags, { Name = "${local.name}-karpenter-controller-role" })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# ── Spot Interruption SQS Queue ───────────────────────────────────────────────

resource "aws_sqs_queue" "interruption" {
  name                      = "${local.name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true
  tags                      = merge(local.common_tags, { Name = "${local.name}-karpenter-interruption" })
}

resource "aws_sqs_queue_policy" "interruption" {
  queue_url = aws_sqs_queue.interruption.id
  policy    = data.aws_iam_policy_document.interruption_queue_policy.json
}

data "aws_iam_policy_document" "interruption_queue_policy" {
  statement {
    sid     = "AllowEventBridgePublish"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
    resources = [aws_sqs_queue.interruption.arn]
  }
}

# ── EventBridge Rules → SQS (spot interruption + instance rebalance) ──────────

resource "aws_cloudwatch_event_rule" "spot_interruption" {
  name        = "${local.name}-karpenter-spot-interruption"
  description = "Karpenter: EC2 Spot Instance Interruption Warning"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "spot_interruption" {
  rule      = aws_cloudwatch_event_rule.spot_interruption.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_rebalance" {
  name        = "${local.name}-karpenter-instance-rebalance"
  description = "Karpenter: EC2 Instance Rebalance Recommendation"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "instance_rebalance" {
  rule      = aws_cloudwatch_event_rule.instance_rebalance.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.interruption.arn
}

resource "aws_cloudwatch_event_rule" "instance_state_change" {
  name        = "${local.name}-karpenter-instance-state"
  description = "Karpenter: EC2 Instance State Change Notification"
  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["EC2 Instance State-change Notification"]
  })
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "instance_state_change" {
  rule      = aws_cloudwatch_event_rule.instance_state_change.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.interruption.arn
}
