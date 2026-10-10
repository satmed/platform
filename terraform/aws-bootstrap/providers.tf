# Bootstrap do state remoto: o bucket que guarda o state da governança e as roles que o
# CI assume por OIDC. Aplicado SÓ por humano, do laptop (o CI não tem permissão de IAM).
# O próprio state deste diretório também vai para o bucket (scripts/bootstrap-state.sh).
terraform {
  required_version = ">= 1.10" # use_lockfile (lock nativo do S3, sem DynamoDB)
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      project    = "satmed-platform"
      managed_by = "terraform/aws-bootstrap"
    }
  }
}
