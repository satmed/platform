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
  required_checks = [] # passo seguinte: local.rust_ci_checks
}

# Refatoração: os recursos já existem; só mudaram de endereço. Sem estes blocos,
# o Terraform planejaria APAGAR e recriar os repos.
moved {
  from = github_repository.valida_rs
  to   = module.valida_rs.github_repository.this
}
moved {
  from = github_repository_vulnerability_alerts.valida_rs
  to   = module.valida_rs.github_repository_vulnerability_alerts.this
}
moved {
  from = github_team_repository.dev_valida_rs
  to   = module.valida_rs.github_team_repository.this["dev"]
}
moved {
  from = github_team_repository.devsecops_valida_rs
  to   = module.valida_rs.github_team_repository.this["devsecops"]
}
moved {
  from = github_repository_ruleset.valida_rs_protect_main
  to   = module.valida_rs.github_repository_ruleset.protect_main[0]
}
moved {
  from = github_repository.pipectl
  to   = module.pipectl.github_repository.this
}
moved {
  from = github_repository_vulnerability_alerts.pipectl
  to   = module.pipectl.github_repository_vulnerability_alerts.this
}
moved {
  from = github_team_repository.devsecops_pipectl
  to   = module.pipectl.github_team_repository.this["devsecops"]
}
