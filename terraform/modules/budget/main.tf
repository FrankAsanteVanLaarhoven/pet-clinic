locals {
  name = "${var.project}-${var.environment}-monthly"
}

# ── Monthly cost budget with two email thresholds ─────────────────────────────

resource "aws_budgets_budget" "monthly" {
  name         = local.name
  budget_type  = "COST"
  limit_amount = tostring(var.alarm_threshold_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Warn at warn_threshold_usd (actual spend)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.warn_threshold_usd
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Alarm at alarm_threshold_usd (actual spend)
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = var.alarm_threshold_usd
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Forecast alarm — warn if we're on track to exceed limit
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
