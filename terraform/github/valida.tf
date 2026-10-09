# Valida em Rust: repo privado, nasce por código (nunca pelo site).
resource "github_repository" "valida_rs" {
  name        = "valida-rs"
  description = "Valida ASO: geração (Typst), assinatura ICP-Brasil verificada e validação pública por QR"
  visibility  = "private" # plano Team: ruleset vale em repo privado

  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  # Só squash: um commit por PR, fácil de auditar.
  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  allow_auto_merge       = false
  allow_update_branch    = true
  delete_branch_on_merge = true

  # Sem secret_scanning: em repo PRIVADO exige GitHub Advanced Security (pago).
  # Quem cobre é o gitleaks (pre-commit + job "secrets" do rust-ci).

  archive_on_destroy = true # remover este bloco arquiva o repo, nunca apaga

  lifecycle {
    prevent_destroy = true
  }
}

# Alertas do Dependabot (recurso separado: o atributo no repo está deprecated).
resource "github_repository_vulnerability_alerts" "valida_rs" {
  repository = github_repository.valida_rs.name
  enabled    = true
}

# Acesso por time: dev escreve código, devsecops administra.
resource "github_team_repository" "dev_valida_rs" {
  team_id    = github_team.dev.id
  repository = github_repository.valida_rs.name
  permission = "push"
}

resource "github_team_repository" "devsecops_valida_rs" {
  team_id    = github_team.devsecops.id
  repository = github_repository.valida_rs.name
  permission = "admin"
}
