# EFS 파일 시스템 생성
# 장애 시 AWS 측 애플리케이션이 공유 스토리지를 사용할 수 있도록 구성한다.
resource "aws_efs_file_system" "main" {
  creation_token = "${local.project_name}-efs"

  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-efs"
  })
}

# EFS 마운트 타겟 생성
# 각 Private Subnet에 마운트 타겟을 두어 EKS 노드가 AZ별로 안정적으로 접근할 수 있게 한다.
resource "aws_efs_mount_target" "main" {
  count = length(aws_subnet.private)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}

# EFS 접근 지점 생성
# 쿠버네티스에서 애플리케이션별 디렉터리를 더 안전하게 사용할 수 있도록 Access Point를 만든다.
resource "aws_efs_access_point" "app" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 1000
    gid = 1000
  }

  root_directory {
    path = "/app-data"

    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-efs-ap"
  })
}