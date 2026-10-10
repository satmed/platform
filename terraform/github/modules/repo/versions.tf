# Sem este bloco o Terraform assume "hashicorp/github" dentro do módulo: outro provider,
# sem owner, e o repo nasce na conta pessoal (história nº 5 do lab). Sempre declarar.
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
