resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${local.project_name}-dms-subnet-group"
  replication_subnet_group_description = "DMS subnet group for DR replication"
  subnet_ids                           = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-dms-subnet-group"
  })
}

resource "aws_dms_replication_instance" "main" {
  replication_instance_id      = "${local.project_name}-dms-instance"
  replication_instance_class   = "dms.t3.micro"
  allocated_storage            = 20
  publicly_accessible          = false
  multi_az                     = false
  replication_subnet_group_id  = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids       = [aws_security_group.dms_sg.id]
  auto_minor_version_upgrade   = true
  apply_immediately            = true

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs
  ]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-dms-instance"
  })
}

resource "aws_dms_endpoint" "source" {
  endpoint_id   = "${local.project_name}-source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"

  server_name = var.onprem_mysql_ip
  port        = 3306
  username    = "repl_user"
  password    = var.onprem_repl_password

  ssl_mode = "none"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-source-mysql"
  })
}

resource "aws_dms_endpoint" "target" {
  endpoint_id   = "${local.project_name}-target-rds"
  endpoint_type = "target"
  engine_name   = "mysql"

  server_name = aws_db_instance.main.address
  port        = 3306
  username    = var.db_username
  password    = var.db_password

  ssl_mode = "none"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-target-rds"
  })
}

resource "aws_dms_replication_task" "cdc" {
  replication_task_id      = "${local.project_name}-cdc-task"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  table_mappings = jsonencode({
    rules = [{
      "rule-type" = "selection"
      "rule-id"   = "1"
      "rule-name" = "include-all"
      "object-locator" = {
        "schema-name" = "%"
        "table-name"  = "%"
      }
      "rule-action" = "include"
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-cdc-task"
  })
}