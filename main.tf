provider "aws" {
  region     = local.region
  access_key = var.ACCESS_KEY_ID
  secret_key = var.SECRET_ACCESS_KEY
}

data "aws_availability_zones" "available" {}

locals {
  name   = "${basename(path.cwd)}"
  region = "eu-central-1"

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-rds-aurora"
    GithubOrg  = "terraform-aws-modules"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = local.name
  cidr = local.vpc_cidr

  azs              = local.azs
  public_subnets   = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  private_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 3)]
  database_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 6)]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

module "aurora_mysql" {
  source = "terraform-aws-modules/rds-aurora/aws"

  name              = "${local.name}-mysql"
  engine            = "aurora-mysql"
  engine_mode       = "serverless"
  storage_encrypted = true
  master_username   = "root"

  vpc_id               = module.vpc.vpc_id
  db_subnet_group_name = module.vpc.database_subnet_group_name
  security_group_rules = {
    vpc_ingress = {
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
    vpc_ingress = {
      source_security_group_id = module.security_group.security_group_id
    }
  }

  # Serverless v1 clusters do not support managed master user password
  manage_master_user_password = false
  master_password             = random_password.master.result

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  # enabled_cloudwatch_logs_exports = # NOT SUPPORTED

  scaling_configuration = {
    auto_pause               = true
    min_capacity             = 2
    max_capacity             = 16
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }

  tags = local.tags
}

resource "aws_instance" "web_server" {
  ami           = "ami-024e6efaf93d85776" # Linux Ubuntu distribution
  instance_type = "t2.micro"             
  key_name      = "Php-VM-KeyPair"  
  security_groups = module.security_group_ec2.security_group_id
// install Nginx 
    user_data = <<-EOF
      #!/bin/bash
      sudo apt update
      sudo apt install php7.4
      sudo apt search php- | grep '^php-'
      sudo apt install php-mysql
      sudo apt install nginx
      sudo systemctl start nginx
      sudo systemctl enable nginx 
      EOF

  tags = {
    Name = "php-app-VM"
  }
}

module "security_group_ec2" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = local.name
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      description = "SSH from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      description = "HTTPS access from within VPC"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  tags = local.tags
}

resource "random_password" "master" {
  length  = 20
  special = false
}