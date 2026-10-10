# State no S3 (terraform/aws-bootstrap). O bucket vem do -backend-config:
#   laptop: terraform init -backend-config=backend.local.hcl (gerado por scripts/bootstrap-state.sh)
#   CI:     -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}"
terraform {
  backend "s3" {
    key          = "github/terraform.tfstate"
    region       = "sa-east-1"
    encrypt      = true
    use_lockfile = true # lock nativo do S3 (Terraform >= 1.10): dois applies não se atropelam
  }
}
