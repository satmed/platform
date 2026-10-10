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

    # Agora existe CI: o check do servidor é obrigatório para o merge.
    required_status_checks {
      strict_required_status_checks_policy = true # a branch tem que estar atualizada com a main
      required_check {
        context        = "static-checks" # nome do job no platform-ci.yml
        integration_id = 15368           # só o GitHub Actions pode marcar este check
      }
    }
  }
}

# Tags de versão da esteira (v1.2.0...) são imutáveis: os produtos fixam o SHA e o
# Dependabot lê a tag para propor o bump. Tag movida ou apagada = bump apontando para o nada.
resource "github_repository_ruleset" "platform_protect_tags" {
  name        = "protect-version-tags"
  repository  = github_repository.platform.name
  target      = "tag"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/tags/v*"]
      exclude = []
    }
  }

  rules {
    deletion         = true # ninguém apaga uma versão publicada
    update           = true # ninguém move a tag para outro commit
    non_fast_forward = true
  }
}
