# Repos de produto: cada um é uma chamada ao molde. Repo novo = um bloco aqui, num PR.

locals {
  # Os portões da esteira rust-ci (nomes exatos que o GitHub registra).
  rust_ci_checks = ["rust-ci / secrets", "rust-ci / lint", "rust-ci / test", "rust-ci / supply-chain"]
}

module "valida_rs" {
  source      = "./modules/repo"
  name        = "valida-rs"
  description = "Valida ASO: geração (Typst), assinatura ICP-Brasil verificada e validação pública por QR"
  teams = {
    dev       = { id = github_team.dev.id, permission = "push" }
    devsecops = { id = github_team.devsecops.id, permission = "admin" }
  }
  required_checks = local.rust_ci_checks
}

module "pipectl" {
  source      = "./modules/repo"
  name        = "pipectl"
  description = "Gestor da esteira DevSecOps da SatMed (doctor, status, next)"
  teams = {
    devsecops = { id = github_team.devsecops.id, permission = "admin" }
  }
  required_checks = local.rust_ci_checks
}
