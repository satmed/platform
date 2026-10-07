# Acesso vai para TIMES, nunca para pessoas.
# Entrou no time, ganhou o acesso; saiu, perdeu. Ninguém lembra repo por repo.

resource "github_team" "devsecops" {
  name        = "devsecops"
  description = "Owns the rules: governance repo, rulesets, pipelines"
  privacy     = "closed" # visível para membros da org; quem entra é controlado
}

resource "github_team_membership" "devsecops_alvaro" {
  team_id  = github_team.devsecops.id
  username = "Alvie40"
  role     = "maintainer"
}

resource "github_team" "dev" {
  name        = "dev"
  description = "Writes the SatMed apps (Valida, SatPsy, Encore, SatFlow)"
  privacy     = "closed"
}

# Só o time devsecops administra o repo da governança.
resource "github_team_repository" "devsecops_platform" {
  team_id    = github_team.devsecops.id
  repository = github_repository.platform.name
  permission = "admin"
}
