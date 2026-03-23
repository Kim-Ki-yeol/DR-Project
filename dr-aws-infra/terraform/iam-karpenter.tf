# Karpenter Controller용 IAM Policy 생성
resource "aws_iam_policy" "karpenter_controller" {
  name        = "${local.project_name}-KarpenterControllerPolicy"
  description = "Policy for Karpenter Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KarpenterEC2Access"
        Effect = "Allow"
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:TerminateInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeVpcs",
          "ec2:DescribeCapacityReservations"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterSSMAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterPricingAccess"
        Effect = "Allow"
        Action = [
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterPassNodeRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.karpenter_node_role.arn
      },
      {
        Sid    = "KarpenterEKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster"
        ]
        Resource = aws_eks_cluster.main.arn
      },
      {
        Sid    = "KarpenterInstanceProfileAccess"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid    = "KarpenterInterruptionQueueAccess"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage"
        ]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-KarpenterControllerPolicy"
  })
}

# Karpenter Controller용 IAM Role 생성
resource "aws_iam_role" "karpenter_controller" {
  name = "${local.project_name}-karpenter-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.eks_oidc_issuer}:sub" = "system:serviceaccount:kube-system:karpenter"
            "${local.eks_oidc_issuer}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-karpenter-controller-role"
  })
}

# Karpenter Controller Role에 Policy 연결
resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# Karpenter가 생성할 EC2 노드용 IAM Role
resource "aws_iam_role" "karpenter_node_role" {
  name = "${local.project_name}-karpenter-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-karpenter-node-role"
  })
}

# Karpenter 노드 Role에 EKS Worker 정책 연결
resource "aws_iam_role_policy_attachment" "karpenter_node_worker_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

# Karpenter 노드 Role에 ECR 읽기 전용 정책 연결
resource "aws_iam_role_policy_attachment" "karpenter_node_ecr_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Karpenter 노드 Role에 SSM 정책 연결
resource "aws_iam_role_policy_attachment" "karpenter_node_ssm_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Karpenter 노드 Role에 EKS CNI 정책 연결
resource "aws_iam_role_policy_attachment" "karpenter_node_cni_policy" {
  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Karpenter 노드용 Instance Profile 생성
resource "aws_iam_instance_profile" "karpenter_node_instance_profile" {
  name = "${local.project_name}-karpenter-node-instance-profile"
  role = aws_iam_role.karpenter_node_role.name

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-karpenter-node-instance-profile"
  })
}

# Karpenter interruption queue 생성
resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${local.project_name}-karpenter-interruption"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-karpenter-interruption"
  })
}

# EventBridge에서 SQS로 메시지를 보낼 수 있도록 Queue Policy 설정
resource "aws_sqs_queue_policy" "karpenter_interruption" {
  queue_url = aws_sqs_queue.karpenter_interruption.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgeSendMessage"
        Effect    = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption.arn
      }
    ]
  })
}

# Spot interruption 이벤트 룰
resource "aws_cloudwatch_event_rule" "karpenter_spot_interruption" {
  name        = "${local.project_name}-karpenter-spot-interruption"
  description = "Capture EC2 Spot Instance Interruption Warning events for Karpenter"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Spot Instance Interruption Warning"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_spot_interruption" {
  rule      = aws_cloudwatch_event_rule.karpenter_spot_interruption.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# Instance rebalance recommendation 이벤트 룰
resource "aws_cloudwatch_event_rule" "karpenter_rebalance" {
  name        = "${local.project_name}-karpenter-rebalance"
  description = "Capture EC2 Instance Rebalance Recommendation events for Karpenter"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance Rebalance Recommendation"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_rebalance" {
  rule      = aws_cloudwatch_event_rule.karpenter_rebalance.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# Instance state-change 이벤트 룰
resource "aws_cloudwatch_event_rule" "karpenter_instance_state_change" {
  name        = "${local.project_name}-karpenter-instance-state-change"
  description = "Capture EC2 Instance State-change Notification events for Karpenter"

  event_pattern = jsonencode({
    source        = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_instance_state_change" {
  rule      = aws_cloudwatch_event_rule.karpenter_instance_state_change.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}

# AWS Health 이벤트 룰
resource "aws_cloudwatch_event_rule" "karpenter_health" {
  name        = "${local.project_name}-karpenter-health"
  description = "Capture AWS Health events for Karpenter"

  event_pattern = jsonencode({
    source        = ["aws.health"]
    "detail-type" = ["AWS Health Event"]
  })
}

resource "aws_cloudwatch_event_target" "karpenter_health" {
  rule      = aws_cloudwatch_event_rule.karpenter_health.name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption.arn
}