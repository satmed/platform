# Configurações da org satmed: menor privilégio por padrão.
resource "github_organization_settings" "satmed" {
  billing_email = var.billing_email

  # Membro vê só os repos que o time dele recebe. Nada de "todo mundo lê tudo".
  default_repository_permission = "none"

  # Só owners (via Terraform) criam repo: todo repo nasce com regra,
  # CODEOWNERS e esteira. Não existe repo "solto".
  members_can_create_repositories          = false
  members_can_create_public_repositories   = false
  members_can_create_private_repositories  = false
  members_can_create_internal_repositories = false
  members_can_fork_private_repositories    = false # fork privado = cópia fora do nosso controle

  # GitHub Pages publica na internet: só owner decide.
  members_can_create_pages         = false
  members_can_create_public_pages  = false
  members_can_create_private_pages = false

  has_organization_projects   = true
  has_repository_projects     = true
  web_commit_signoff_required = false

  # Todo repo novo já nasce com inventário de dependências e alertas (grátis em qualquer plano).
  dependency_graph_enabled_for_new_repositories            = true
  dependabot_alerts_enabled_for_new_repositories           = true
  dependabot_security_updates_enabled_for_new_repositories = true

  # Secret scanning em repo PRIVADO exige GitHub Advanced Security (pago).
  # Nos públicos, ligamos por repo (ver repos.tf). O gitleaks cobre os privados.
  advanced_security_enabled_for_new_repositories               = false
  secret_scanning_enabled_for_new_repositories                 = false
  secret_scanning_push_protection_enabled_for_new_repositories = false
}
