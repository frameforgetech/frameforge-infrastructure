# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      Name        = "frameforge-vpc-${var.environment}"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.tags
  )
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name        = "frameforge-igw-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name        = "frameforge-public-${var.availability_zones[count.index]}-${var.environment}"
      Environment = var.environment
      Tier        = "public"
      "kubernetes.io/role/elb" = "1"
    },
    var.tags
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      Name        = "frameforge-private-${var.availability_zones[count.index]}-${var.environment}"
      Environment = var.environment
      Tier        = "private"
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.tags
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    {
      Name        = "frameforge-nat-eip-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (only one for cost savings)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    {
      Name        = "frameforge-nat-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )

  timeouts {
    create = "20m"
    delete = "20m"
  }

  depends_on = [aws_internet_gateway.main]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    {
      Name        = "frameforge-public-rt-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(
    {
      Name        = "frameforge-private-rt-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Private Route Table Association
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# VPC Flow Logs (optional, for debugging)
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = merge(
    {
      Name        = "frameforge-vpc-flow-log-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/frameforge-${var.environment}"
  retention_in_days = 7
  skip_destroy      = true

  tags = merge(
    {
      Name        = "frameforge-vpc-flow-log-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_iam_role" "flow_log" {
  name = "frameforge-vpc-flow-log-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    {
      Name        = "frameforge-vpc-flow-log-role-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_iam_role_policy" "flow_log" {
  name = "frameforge-vpc-flow-log-policy-${var.environment}"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
