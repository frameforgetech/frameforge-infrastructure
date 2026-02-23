resource "random_password" "master" {
  length  = 16
  special = true
}

resource "random_id" "secret_suffix" {
  byte_length = 4
  keepers = {
    environment = var.environment
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "frameforge-rds-${var.environment}"
  description = "Security group for FrameForge RDS PostgreSQL"
  vpc_id      = var.vpc_id

  # Rules managed separately via aws_security_group_rule resources
  # to avoid conflicts with externally managed rules

  tags = merge(
    {
      Name        = "frameforge-rds-sg-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Security group egress rule
resource "aws_security_group_rule" "rds_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
}

# Security group ingress rules for allowed security groups (RabbitMQ, Redis)
resource "aws_security_group_rule" "rds_ingress" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.rds.id
  description              = "PostgreSQL from allowed security groups"
}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "frameforge-db-subnet-${var.environment}"
  subnet_ids = var.subnet_ids

  tags = merge(
    {
      Name        = "frameforge-db-subnet-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = "frameforge-db-${var.environment}"
  engine         = "postgres"
  engine_version = "15.8"

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.database_name
  username = var.master_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = var.backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  multi_az               = var.multi_az
  deletion_protection    = var.environment == "prod" ? true : false
  skip_final_snapshot    = var.environment != "prod"
  final_snapshot_identifier = var.environment == "prod" ? "frameforge-${var.environment}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  performance_insights_enabled    = false  # Costs extra
  
  auto_minor_version_upgrade = true
  
  tags = merge(
    {
      Name        = "frameforge-db-${var.environment}"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "frameforge/rds/${var.environment}/master-password-${random_id.secret_suffix.hex}"
  description             = "RD S master password for FrameForge ${var.environment}"
  recovery_window_in_days = 0

  tags = merge(
    {
      Name        = "frameforge-rds-password-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.master_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.database_name
  })
}
