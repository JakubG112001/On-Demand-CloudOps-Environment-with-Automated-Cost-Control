# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  
  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
  }
}

# RDS Instance (starts stopped to save costs)
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = true
  
  db_name  = "cloudops"
  username = "postgres"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 1  # Reduced for cost
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  multi_az               = false  # Single AZ for cost savings
  publicly_accessible    = false
  
  enabled_cloudwatch_logs_exports = ["postgresql"]
  
  deletion_protection = false
  skip_final_snapshot = true
  
  # Start in stopped state
  lifecycle {
    ignore_changes = ["latest_restorable_time"]
  }
  
  tags = {
    Name        = "${var.project_name}-db"
    Environment = var.environment
  }
}