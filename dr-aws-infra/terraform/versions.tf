# Terraform 및 Provider 버전 관리
# 팀원 간 동일한 버전을 사용하도록 제한
terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}