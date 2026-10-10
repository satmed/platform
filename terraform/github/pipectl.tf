# Pipectl: o gestor da esteira também vive dentro da esteira.
resource "github_repository" "pipectl" {
  name        = "pipectl"
  description = "Gestor da esteira DevSecOps da SatMed (doctor, status, next)"
  visibility  = "private"

  has_issues      = true
  has_projects    = false
  has_wiki        = false
  has_discussions = false

  allow_merge_commit     = false
  allow_rebase_merge     = false
  allow_squash_merge     = true
  allow_auto_merge       = false
  allow_update_branch    = true
  delete_branch_on_merge = true

  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "github_repository_vulnerability_alerts" "pipectl" {
  repository = github_repository.pipectl.name
  enabled    = true
}

# Quem mexe na esteira é o time devsecops (nada de time dev aqui).
resource "github_team_repository" "devsecops_pipectl" {
  team_id    = github_team.devsecops.id
  repository = github_repository.pipectl.name
  permission = "admin"
}
