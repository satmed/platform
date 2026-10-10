# O "sub" do token OIDC passa a dizer QUAL workflow pediu, não só o repo/environment.
# A role de apply na AWS exige: environment github-apply + terraform.yml + refs/heads/main.
# Sem isto, qualquer workflow que use o environment poderia assumir a role.
resource "github_actions_repository_oidc_subject_claim_customization_template" "platform" {
  repository         = github_repository.platform.name
  use_default        = false
  include_claim_keys = ["repo", "context", "job_workflow_ref"]
}
