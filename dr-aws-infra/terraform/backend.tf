# Terraform 및 Provider 버전 관리
# 팀원 간 동일한 버전을 사용하도록 제한

terraform {
  backend "s3" {
    bucket = "dr-aws-terraform-state" # tfstate 저장 S3 버킷
    key = "dr-infra/terraform.tfstate" # 상태파일 경로
    region = "ap-northeast-2" # S3 버킷 리전
    dynamodb_table = "terraform-lock-table"  # 상태 Lock 테이블
    encrypt        = true # 상태파일 암호화
  }
}