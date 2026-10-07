# O repo da governança: onde as regras moram, FORA dos repos que elas julgam.
resource "github_repository" "platform" {
  name        = "platform"
  description = "SatMed DevSecOps platform: org rules as code + reusable secure pipeline"
  visibility  = "public" # Free: ruleset só vale em repo público

  has_issues      = true
  has_projects    = false
  has_wiki        = false # superfície que ninguém revisa
  has_discussions = false

  # Só squash: um commit por PR, fácil de auditar.
  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  allow_auto_merge       = false
  allow_update_branch    = true
  delete_branch_on_merge = true

  # Em repo público é grátis: barra o push que contém segredo conhecido.
  security_and_analysis {
    secret_scanning {
      status = "enabled"
    }
    secret_scanning_push_protection {
      status = "enabled"
    }
  }

  archive_on_destroy = true # remover este bloco arquiva o repo, nunca apaga

  lifecycle {
    prevent_destroy = true # o Terraform se recusa a destruir a sala das chaves
  }
}

# Alertas do Dependabot. O atributo vulnerability_alerts dentro do repo está
# deprecated no provider 6.x: o certo é este recurso separado.
resource "github_repository_vulnerability_alerts" "platform" {
  repository = github_repository.platform.name
  enabled    = true
}
