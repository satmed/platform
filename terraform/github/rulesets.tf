# A governança protege a si mesma primeiro:
# "tranca a sala das chaves antes de abrir qualquer outra porta".
resource "github_repository_ruleset" "platform_protect_main" {
  name        = "protect-main"
  repository  = github_repository.platform.name
  target      = "branch"
  enforcement = "active"
  # Sem bypass_actors: ninguém pula a regra, nem o owner da org.

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"] # a main
      exclude = []
    }
  }

  rules {
    deletion                = true # ninguém apaga a main
    non_fast_forward        = true # ninguém reescreve o histórico (force push)
    required_signatures     = true # todo commit na main precisa ser assinado
    required_linear_history = true # histórico em linha reta, sem merge commits

    pull_request {
      # Org com um humano só: ninguém pode aprovar o próprio PR.
      # Com 1 aprovação obrigatória você nunca conseguiria fazer merge.
      # Então: PR obrigatório (sem push direto), aprovações = 0.
      # Com um time de verdade: 1+ aprovação e revisão do code owner.
      required_approving_review_count   = 0
      require_code_owner_review         = false
      require_last_push_approval        = false
      dismiss_stale_reviews_on_push     = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash"]
    }

    # O required_status_checks entra quando existir CI:
    # exigir um check que nenhum workflow produz bloqueia todo PR para sempre.
  }
}
