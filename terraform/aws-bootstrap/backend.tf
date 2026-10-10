# O bucket vem do -backend-config (scripts/bootstrap-state.sh grava backend.local.hcl,
# fora do git). Na primeira vez este arquivo fica de lado: o bucket ainda não existe.
terraform {
  backend "s3" {
    key          = "bootstrap/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
