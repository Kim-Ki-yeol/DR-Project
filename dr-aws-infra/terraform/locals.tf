locals {
  # 프로젝트 이름
  project_name = "dr-aws-infra"

  # 환경 이름
  environment = "dr"

  # 공통 태그 정의
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "terraform"
  }
}