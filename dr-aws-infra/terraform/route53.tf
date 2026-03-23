# Route53 Health Check
# enable_route53_failover가 true일 때만 생성한다.
resource "aws_route53_health_check" "onprem_health" {
  count = var.enable_route53_failover ? 1 : 0

  fqdn              = var.onprem_domain
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-onprem-health-check"
  })
}

# Primary Record
# 평상시 트래픽은 온프레미스로 전달한다.
resource "aws_route53_record" "primary_onprem" {
  count = var.enable_route53_failover ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "onprem-primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.onprem_health[0].id
  ttl             = 60

  records = [
    var.onprem_public_ip
  ]
}

# Secondary Record
# 온프레미스 장애 발생 시 AWS ALB로 전환한다.
resource "aws_route53_record" "secondary_aws" {
  count = var.enable_route53_failover ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier = "aws-dr"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.aws_alb_dns_name
    zone_id                = var.aws_alb_zone_id
    evaluate_target_health = true
  }
}