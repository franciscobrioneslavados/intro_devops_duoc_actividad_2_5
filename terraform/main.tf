###############################################################################
# Tienda Perritos - Infraestructura AWS
# VPC + NAT Instance + 3 EC2 (Frontend, Backend, DB)
###############################################################################

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  vpc_cidr    = var.vpc_cidr
  azs         = ["us-east-1a", "us-east-1b"]
}

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
  # backend "s3" {
  #  bucket  = "placeholder" # Se sobreescribe en el pipeline con -backend-config
  #  key     = "actividad_2_5/terraform.tfstate"
  #  region  = "us-east-1"
  #  encrypt = true
  # }

}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      OwnerName   = var.owner_name
    }
  }
}

###############################################################################
# VPC - Módulo oficial de Terraform (sin NAT Gateway)
###############################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = "${local.name_prefix}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 2, i)]
  public_subnets  = [for i in range(length(local.azs)) : cidrsubnet(local.vpc_cidr, 2, i + length(local.azs))]

  private_subnet_names = [for az in local.azs : "${local.name_prefix}-private-${az}"]
  public_subnet_names  = [for az in local.azs : "${local.name_prefix}-public-${az}"]

  public_route_table_tags = {
    Name = "${local.name_prefix}-public-rt"
  }
  private_route_table_tags = {
    Name = "${local.name_prefix}-private-rt"
  }

  # Tags for Internet Gateway
  igw_tags = {
    Name = "${local.name_prefix}-igw"
  }

  create_igw              = true  # Create Internet Gateway
  enable_nat_gateway      = false # Using custom NAT instance module
  single_nat_gateway      = true  # Group private subnets into one route table
  enable_vpn_gateway      = false # Not using VPN Gateway
  enable_dns_hostnames    = true  # Enable DNS hostnames
  enable_dns_support      = true  # Enable DNS support
  map_public_ip_on_launch = true  # Enable public IP on launch

}

###############################################################################
# NAT Instance - Módulo custom
###############################################################################
module "nat_instance" {
  source = "git::https://github.com/franciscobrioneslavados/terraform-aws-nat-instance.git//.?ref=v1.3.0"

  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnets
  private_subnet_cidrs = module.vpc.private_subnets_cidr_blocks
  route_table_ids      = module.vpc.private_route_table_ids
  project_name         = "${local.name_prefix}-nat"
  environment          = var.environment
  owner_name           = var.owner_name
  instance_type        = var.instance_type
  ssh_allowed_cidrs    = ["0.0.0.0/32"]
  os_type              = "amazon-linux-2" # or "ubuntu"

  depends_on = [module.vpc]
}


###############################################################################
# Security Groups
###############################################################################
module "sg_frontend" {
  source = "./modules/security-group"

  name        = "${var.project_name}-frontend-sg"
  description = "SG para Frontend - permite HTTP desde internet"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP desde internet"
    },
  ]
}

module "sg_backend" {
  source = "./modules/security-group"

  name        = "${var.project_name}-backend-sg"
  description = "SG para Backend - permite trafico desde frontend"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 3001
      to_port     = 3001
      protocol    = "tcp"
      cidr_blocks = module.vpc.public_subnets_cidr_blocks
      description = "API desde subnet publica (frontend)"
    },
  ]
}

module "sg_db" {
  source = "./modules/security-group"

  name        = "${var.project_name}-db-sg"
  description = "SG para DB - permite MySQL desde backend"
  vpc_id      = module.vpc.vpc_id

  ingress_rules = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
      description = "MySQL desde subnet privada (backend)"
    },
  ]
}

###############################################################################
# EC2 Instances
###############################################################################
module "ec2_frontend" {
  source = "./modules/ec2"

  name                 = "${local.name_prefix}-frontend"
  ami_id               = "ami-0a59ec92177ec3fad"
  instance_type        = var.instance_type
  subnet_id            = module.vpc.public_subnets[0]
  security_group_ids   = [module.sg_frontend.security_group_id]
  iam_instance_profile = var.iam_instance_profile

  user_data = <<-EOF
    #!/bin/bash
    #!/bin/bash
    yum update -y
    yum install -y docker.io
    systemctl enable docker && systemctl start docker
    usermod -aG docker ec2-user
    # Instalar SSM Agent (ya viene en Amazon Linux 2)
    systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
  EOF

  tags       = { Layer = "frontend" }
  depends_on = [module.ec2_backend]
}

module "ec2_backend" {
  source = "./modules/ec2"

  name                 = "${local.name_prefix}-backend"
  ami_id               = "ami-0a59ec92177ec3fad"
  instance_type        = var.instance_type
  subnet_id            = module.vpc.private_subnets[1]
  security_group_ids   = [module.sg_backend.security_group_id]
  iam_instance_profile = var.iam_instance_profile

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker && systemctl start docker
    usermod -aG docker ec2-user
    systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
  EOF

  tags       = { Layer = "backend" }
  depends_on = [module.ec2_db]
}

module "ec2_db" {
  source = "./modules/ec2"

  name                 = "${local.name_prefix}-db"
  ami_id               = "ami-0a59ec92177ec3fad"
  instance_type        = var.instance_type
  subnet_id            = module.vpc.private_subnets[0]
  security_group_ids   = [module.sg_db.security_group_id]
  iam_instance_profile = var.iam_instance_profile

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker && systemctl start docker
    usermod -aG docker ec2-user
    systemctl enable amazon-ssm-agent && systemctl start amazon-ssm-agent
  EOF

  tags = { Layer = "database" }
}
