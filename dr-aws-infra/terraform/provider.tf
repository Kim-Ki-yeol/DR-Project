# AWS Provider 설정
# Terraform이 어떤 클라우드 플랫폼을 사용할지 정의하는 파일

provider "aws" {
  region = var.aws_region   # 사용할 AWS 리전 (variables.tf에서 정의)

  # Terraform으로 생성되는 모든 리소스에 공통으로 붙을 태그 설정
  default_tags {
    tags = {
      Project     = local.project_name   # 프로젝트 이름 (locals.tf에서 정의)
      Environment = local.environment    # 환경 구분 (DR)
      ManagedBy   = "terraform"          # Terraform으로 관리되는 리소스 표시
    }
  }
}