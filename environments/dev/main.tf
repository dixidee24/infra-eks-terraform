terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project}-${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.50.1.0/24", "10.50.2.0/24"]
  public_subnets  = ["10.50.101.0/24", "10.50.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Project = var.project
    Env     = var.environment
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project}-${var.environment}-eks"
  cluster_version = "1.29"

  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    ci = {
      instance_types = ["t3.medium"]
      min_size       = 0
      desired_size   = 1
      max_size       = 2
      labels = {
        workload = "ci"
      }
    }

    app = {
      instance_types = ["t3.medium"]
      min_size       = 0
      desired_size   = 1
      max_size       = 2
      labels = {
        workload = "app"
      }
    }
  }

  tags = {
    Project = var.project
    Env     = var.environment
  }
}
