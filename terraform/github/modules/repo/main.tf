# O molde: todo repo de produto nasce igual, com as mesmas travas.
resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility

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

resource "github_repository_vulnerability_alerts" "this" {
  repository = github_repository.this.name
  enabled    = true
}

resource "github_team_repository" "this" {
  for_each = var.teams

  team_id    = each.value.id
  repository = github_repository.this.name
  permission = each.value.permission
}

# A main: só por PR, assinada, sem bypass, com os checks obrigatórios.
# Só existe quando há checks: exigir um check que nunca rodou trava todo PR.
resource "github_repository_ruleset" "protect_main" {
  count = length(var.required_checks) > 0 ? 1 : 0

  name        = "protect-main"
  repository  = github_repository.this.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_signatures     = true
    required_linear_history = true

    pull_request {
      required_approving_review_count   = 0 # um humano só; com time: 1+ e code owner
      require_code_owner_review         = false
      require_last_push_approval        = false
      dismiss_stale_reviews_on_push     = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash"]
    }

    required_status_checks {
      strict_required_status_checks_policy = true
      dynamic "required_check" {
        for_each = var.required_checks
        content {
          context        = required_check.value
          integration_id = 15368 # só o GitHub Actions publica
        }
      }
    }
  }
}
