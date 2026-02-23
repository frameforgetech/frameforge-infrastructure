data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for RabbitMQ
resource "aws_security_group" "rabbitmq" {
  name        = "frameforge-rabbitmq-${var.environment}"
  description = "Security group for RabbitMQ"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5672
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "AMQP"
  }

  ingress {
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Management UI"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "frameforge-rabbitmq-sg-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# Security Group for Redis
resource "aws_security_group" "redis" {
  name        = "frameforge-redis-${var.environment}"
  description = "Security group for Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Redis"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      Name        = "frameforge-redis-sg-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2" {
  name = "frameforge-ec2-role-${var.environment}"

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

  tags = merge(
    {
      Name        = "frameforge-ec2-role-${var.environment}"
      Environment = var.environment
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "frameforge-ec2-profile-${var.environment}"
  role = aws_iam_role.ec2.name
}

# RabbitMQ Instance
resource "aws_instance" "rabbitmq" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[0]
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.rabbitmq.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              
              # Run RabbitMQ
              docker run -d --name rabbitmq \
                --restart unless-stopped \
                -p 5672:5672 \
                -p 15672:15672 \
                -e RABBITMQ_DEFAULT_USER=frameforge \
                -e RABBITMQ_DEFAULT_PASS=frameforge123 \
                rabbitmq:3-management-alpine
              EOF

  tags = merge(
    {
      Name        = "frameforge-rabbitmq-${var.environment}"
      Environment = var.environment
      Service     = "rabbitmq"
    },
    var.tags
  )
}

# Redis Instance
resource "aws_instance" "redis" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[0]
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.redis.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              
              # Install Docker
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              
              # Run Redis
              docker run -d --name redis \
                --restart unless-stopped \
                -p 6379:6379 \
                redis:7-alpine redis-server --appendonly yes
              EOF

  tags = merge(
    {
      Name        = "frameforge-redis-${var.environment}"
      Environment = var.environment
      Service     = "redis"
    },
    var.tags
  )
}
