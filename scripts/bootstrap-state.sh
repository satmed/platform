#!/usr/bin/env bash
# Tira o state do Terraform do laptop: cria o bucket + roles OIDC (terraform/aws-bootstrap),
# migra os dois states para o S3 e configura as variáveis do CI no GitHub.
# Uso: scripts/bootstrap-state.sh   (depois de `aws login`). Pode rodar de novo: pula o que já fez.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
boot=terraform/aws-bootstrap
gh_dir=terraform/github
repo=satmed/platform
backup="$HOME/.satmed-tfstate-backup/$(date +%F-%H%M%S)"

# Mesmas travas do tf-apply.sh: só da main igual à do GitHub.
[ "$(git branch --show-current)" = main ] || { echo "ERRO: rode a partir da main"; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "ERRO: main local difere do GitHub. Rode: git pull"; exit 1; }

conta=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
  || { echo "ERRO: sem credencial AWS. Rode: aws login"; exit 1; }
echo "Conta AWS: $conta  ·  região: sa-east-1"

guarda() { # move o state local para fora do repo (nunca apaga)
  mkdir -p "$backup" && chmod 700 "$backup"
  for f in "$1"/terraform.tfstate "$1"/terraform.tfstate.backup; do
    [ -f "$f" ] && mv "$f" "$backup/$(basename "$1")-$(basename "$f")"
  done
  echo "state local antigo guardado em $backup (apague quando confiar no S3)"
}

# ── 1. Bucket + roles, com state local na primeira vez
if [ ! -f "$boot/backend.local.hcl" ]; then
  # Só pode existir um provider OIDC do GitHub por conta: reaproveita se já houver.
  if aws iam list-open-id-connect-providers --output text | grep -q token.actions.githubusercontent.com; then
    echo 'create_oidc_provider = false' > "$boot/terraform.tfvars"
  else
    echo 'create_oidc_provider = true' > "$boot/terraform.tfvars"
  fi

  mv "$boot/backend.tf" "$boot/backend.tf.off"
  trap 'mv "$boot/backend.tf.off" "$boot/backend.tf" 2>/dev/null || true' EXIT
  terraform -chdir="$boot" init -input=false
  plan=$(mktemp -t bootplan)
  terraform -chdir="$boot" plan -out="$plan"
  read -r -p "Criar ESTES recursos na conta $conta? Digite 'sim': " ok
  [ "$ok" = sim ] || { rm -f "$plan"; echo "Cancelado. Nada foi criado."; exit 1; }
  terraform -chdir="$boot" apply "$plan"
  rm -f "$plan"
  mv "$boot/backend.tf.off" "$boot/backend.tf"
  trap - EXIT

  bucket=$(terraform -chdir="$boot" output -raw state_bucket)
  printf 'bucket = "%s"\n' "$bucket" > "$boot/backend.local.hcl"
  terraform -chdir="$boot" init -input=false -migrate-state -force-copy -backend-config=backend.local.hcl
  guarda "$boot"
fi
bucket=$(terraform -chdir="$boot" output -raw state_bucket)
cp "$boot/backend.local.hcl" "$gh_dir/backend.local.hcl"

# ── 2. State da governança: laptop → S3, conferindo que nada se perdeu no caminho
if [ -f "$gh_dir/terraform.tfstate" ]; then
  antes=$(terraform -chdir="$gh_dir" state list -state=terraform.tfstate | wc -l)
  terraform -chdir="$gh_dir" init -input=false -migrate-state -force-copy -backend-config=backend.local.hcl
  depois=$(terraform -chdir="$gh_dir" state list | wc -l)
  [ "$antes" = "$depois" ] || { echo "ERRO: $antes recursos antes, $depois no S3. Nada foi movido."; exit 1; }
  echo "state migrado: $depois recursos no S3"
  guarda "$gh_dir"
else
  terraform -chdir="$gh_dir" init -input=false -reconfigure -backend-config=backend.local.hcl >/dev/null
fi

# ── 3. Variáveis do CI. Os environments nascem do Terraform (environments.tf).
gh variable set TF_STATE_BUCKET -R "$repo" -b "$bucket"
if ! gh api "repos/$repo/environments/github-apply" >/dev/null 2>&1; then
  echo
  echo "Falta criar os environments: rode scripts/tf-apply.sh e depois este script de novo."
  exit 0
fi
gh variable set AWS_ROLE_ARN -R "$repo" --env github-plan -b "$(terraform -chdir="$boot" output -raw plan_role_arn)"
gh variable set AWS_ROLE_ARN -R "$repo" --env github-apply -b "$(terraform -chdir="$boot" output -raw apply_role_arn)"

# billing_email: do terraform.tfvars local direto para o secret, sem passar pela tela.
email=$(sed -nE 's/^[[:space:]]*billing_email[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "$gh_dir/terraform.tfvars")
[ -n "$email" ] || { echo "ERRO: billing_email não encontrado em $gh_dir/terraform.tfvars"; exit 1; }
for env in github-plan github-apply; do
  printf '%s' "$email" | gh secret set TF_VAR_BILLING_EMAIL -R "$repo" --env "$env"
done

echo
echo "Pronto. Próximo: scripts/github-app-create.sh plan && scripts/github-app-create.sh apply"
