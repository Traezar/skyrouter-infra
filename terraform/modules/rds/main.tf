locals {
  prefix = "${var.project_name}-${var.environment}"
}

data "aws_vpc" "main" {
  id = var.vpc_id
}

# ---------- DB Subnet Group ----------
resource "aws_db_subnet_group" "main" {
  name       = "${local.prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = { Name = "${local.prefix}-db-subnet-group" }
}

# ---------- Security Group ----------
resource "aws_security_group" "rds" {
  name_prefix = "${local.prefix}-rds-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "Allow PostgreSQL from within VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.prefix}-rds-sg" }
}

# ---------- RDS Instance ----------
resource "aws_db_instance" "main" {
  identifier = "${local.prefix}-postgres"

  engine               = "postgres"
  engine_version       = "16"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  max_allocated_storage = 100
  storage_type         = "gp3"
  storage_encrypted    = true

  db_name  = var.db_name
  username = var.db_username
  # Let AWS manage the password via Secrets Manager
  manage_master_user_password = true

  multi_az               = false  # Single-AZ for demo (saves ~50%)
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 1
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = false  # Easy teardown for demo
  skip_final_snapshot = true

  performance_insights_enabled = true

  tags = { Name = "${local.prefix}-postgres" }
}
