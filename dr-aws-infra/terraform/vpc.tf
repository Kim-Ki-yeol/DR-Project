# VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-vpc"
  })
}

# 인터넷 게이트웨이 생성
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-igw"
  })
}

# Public Subnet 생성
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-${count.index + 1}"
    Type = "public"
    # AWS Load Balancer Controller가 인터넷 공개용 ALB를 생성할 위치임을 식별하는 태그
    "kubernetes.io/role/elb" = "1"
    # 클러스터와 서브넷 간의 연동을 명시하는 태그
    "kubernetes.io/cluster/${local.project_name}-eks-cluster" = "shared"
  })
}

# Private Subnet 생성
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-${count.index + 1}"
    Type = "private"
    # AWS Load Balancer Controller가 내부용(Internal) 로드밸런서를 생성할 위치임을 식별하는 태그
    "kubernetes.io/role/internal-elb" = "1"
    # 클러스터와 서브넷 간의 연동을 명시하는 태그
    "kubernetes.io/cluster/${local.project_name}-eks-cluster" = "shared"
    # Karpenter가 노드를 생성할 Private Subnet을 찾기 위한 태그
    "karpenter.sh/discovery" = "${local.project_name}-eks-cluster"
  })
}

# Public Route Table 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # 외부 인터넷 통신을 위한 라우팅
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-public-rt"
  })
}

# Public Subnet과 Route Table 연결
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway용 Elastic IP 생성
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat-eip"
  })
}

# NAT Gateway 생성
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.igw]

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-nat"
  })
}

# Private Route Table 생성
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project_name}-private-rt"
  })
}

# Private Subnet과 Route Table 연결
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}