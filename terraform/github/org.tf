# Configurações da org satmed.
# Dose 1: valores IGUAIS aos de hoje (importados). O endurecimento vem depois, num PR separado.
resource "github_organization_settings" "satmed" {
  billing_email = var.billing_email

  default_repository_permission = "read"

  members_can_create_repositories          = true
  members_can_create_public_repositories   = true
  members_can_create_private_repositories  = true
  members_can_create_internal_repositories = false
  members_can_fork_private_repositories    = false

  members_can_create_pages         = true
  members_can_create_public_pages  = true
  members_can_create_private_pages = true

  has_organization_projects   = true
  has_repository_projects     = true
  web_commit_signoff_required = false

  advanced_security_enabled_for_new_repositories               = false
  dependabot_alerts_enabled_for_new_repositories               = false
  dependabot_security_updates_enabled_for_new_repositories     = false
  dependency_graph_enabled_for_new_repositories                = false
  secret_scanning_enabled_for_new_repositories                 = false
  secret_scanning_push_protection_enabled_for_new_repositories = false
}
