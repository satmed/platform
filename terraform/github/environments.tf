# Onde as credenciais do CI moram. Cada environment guarda a chave de UMA GitHub App:
#   github-plan:  app só-leitura, roda em PR (qualquer branch).
#   github-apply: app com escrita, só da main, e só depois de um humano aprovar.

data "github_user" "approver" {
  username = "Alvie40"
}

resource "github_repository_environment" "plan" {
  repository  = github_repository.platform.name
  environment = "github-plan"
}

resource "github_repository_environment" "apply" {
  repository          = github_repository.platform.name
  environment         = "github-apply"
  can_admins_bypass   = false # nem o owner pula a aprovação
  prevent_self_review = false # org com um humano só: quem abre é quem aprova (com time: true)

  reviewers {
    users = [data.github_user.approver.id]
  }

  deployment_branch_policy {
    protected_branches     = true # só a main (protegida pelo ruleset) chega aqui
    custom_branch_policies = false
  }
}
