# AWS 리전 설정
variable "aws_region" {
  description = "AWS region for DR infrastructure"
  type        = string
  default     = "ap-northeast-2"
}

# VPC CIDR 대역 설정
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# Public Subnet CIDR 대역 설정
variable "public_subnet_cidr" {
  description = "Public subnet CIDR blocks"
  type        = list(string)

  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

# Private Subnet CIDR 대역 설정
variable "private_subnet_cidr" {
  description = "Private subnet CIDR blocks"
  type        = list(string)

  default = [
    "10.0.11.0/24",
    "10.0.12.0/24"
  ]
}

# 가용 영역 설정
variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)

  default = [
    "ap-northeast-2a",
    "ap-northeast-2c"
  ]
}

variable "app_nodeport" {
  description = "NodePort exposed by Kubernetes service"
  type        = number
  default     = 30080
}

variable "health_check_path" {
  description = "Health check path for ALB target group"
  type        = string
  default     = "/"
}

# Route53 failover를 실제로 생성할지 여부
# ALB가 아직 없으면 false로 두고 1차 apply
# ALB 생성 후 true로 바꾸고 2차 apply
variable "enable_route53_failover" {
  description = "Whether to create Route53 failover records"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Service domain"
  type        = string
  default     = ""
}

variable "onprem_domain" {
  description = "On-premise health check domain"
  type        = string
  default     = ""
}

variable "onprem_public_ip" {
  description = "On-premise public IP"
  type        = string
  default     = ""
}

# ALB는 AWS Load Balancer Controller가 Ingress 생성 후 만들기 때문에
# 처음 apply 시에는 비워두고, 나중에 값 채워 넣는다.
variable "aws_alb_dns_name" {
  description = "DNS name of ALB created by AWS Load Balancer Controller"
  type        = string
  default     = ""
}

variable "aws_alb_zone_id" {
  description = "Hosted zone ID of ALB created by AWS Load Balancer Controller"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 Key Pair name"
  type        = string
}

# DB 계정 정보를 하드코딩하지 않도록 변수로 분리
variable "db_name" {
  description = "RDS database name"
  type        = string
  default     = "drdb"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "CIDR allowed for SSH and monitoring access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "monitoring_instance_type" {
  description = "EC2 instance type for monitoring server"
  type        = string
  default     = "t2.micro"
}

variable "onprem_mysql_ip" {
  description = "On-premise MySQL private or tunnel IP for DMS source endpoint"
  type        = string
  default     = ""
}

variable "onprem_repl_password" {
  description = "Password for on-premise MySQL replication user"
  type        = string
  sensitive   = true
  default     = ""
}