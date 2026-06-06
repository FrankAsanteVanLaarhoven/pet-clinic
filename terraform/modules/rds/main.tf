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

# ── Random master password ────────────────────────────────────────────────────

resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}|;:,.<>?"
}

# ── Secrets Manager — store credentials before RDS so apps can read them ─────

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${local.name}/rds/master"
  description             = "RDS MySQL master credentials for ${local.name}"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, { Name = "${local.name}-rds-secret" })
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = "petclinic"
    password = random_password.master.result
    engine   = "mysql"
    port     = 3306
    dbname   = "petclinic"
  })
}

# ── DB subnet group ───────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name        = "${local.name}-db-subnet-group"
  subnet_ids  = var.subnet_ids
  description = "DB subnet group for ${local.name}"

  tags = merge(local.common_tags, { Name = "${local.name}-db-subnet-group" })
}

# ── Parameter group — utf8mb4 ─────────────────────────────────────────────────

resource "aws_db_parameter_group" "main" {
  name        = "${local.name}-mysql80"
  family      = "mysql8.0"
  description = "MySQL 8.0 parameter group for ${local.name}"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = merge(local.common_tags, { Name = "${local.name}-mysql80" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── RDS instance ──────────────────────────────────────────────────────────────

resource "aws_db_instance" "main" {
  identifier = "${local.name}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = "petclinic"
  username = "petclinic"
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  parameter_group_name   = aws_db_parameter_group.main.name

  multi_az                = var.multi_az
  publicly_accessible     = false
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot
  deletion_protection     = var.deletion_protection

  tags = merge(local.common_tags, { Name = "${local.name}-mysql" })

  depends_on = [aws_secretsmanager_secret_version.rds]
}
