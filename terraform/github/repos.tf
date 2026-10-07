# O repo da governança: onde as regras moram, FORA dos repos que elas julgam.
# Dose 2: valores IGUAIS aos de hoje (criado à mão pelo gh repo create, depois importado).
resource "github_repository" "platform" {
  name        = "platform"
  description = "SatMed DevSecOps platform: org rules as code + reusable secure pipeline"
  visibility  = "public"

  has_issues      = true
  has_projects    = true
  has_wiki        = true
  has_discussions = false

  allow_merge_commit     = true
  allow_rebase_merge     = true
  allow_squash_merge     = true
  allow_auto_merge       = false
  allow_update_branch    = false
  delete_branch_on_merge = false

  security_and_analysis {
    secret_scanning {
      status = "disabled"
    }
    secret_scanning_push_protection {
      status = "disabled"
    }
  }
}

