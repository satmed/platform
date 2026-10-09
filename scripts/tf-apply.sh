#!/usr/bin/env bash
# Aplica o Terraform da governança com as travas que aprendemos na prática.
# Uso: scripts/tf-apply.sh   (de qualquer pasta do repo)
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
dir=terraform/github
plan=$(mktemp -t tfplan)
trap 'rm -f "$plan"' EXIT   # o plano salvo some sempre, até se der erro

# 1. Só a partir da main IGUAL à do GitHub (o plan desatualizado queria apagar o ruleset)
[ "$(git branch --show-current)" = main ] || { echo "ERRO: rode a partir da main"; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "ERRO: main local difere do GitHub. Rode: git pull"; exit 1; }
[ -z "$(git status --porcelain -- "$dir")" ] || { echo "ERRO: mudanças não commitadas em $dir"; exit 1; }

export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token)}"

# 2. Plan salvo. -detailed-exitcode: 0 = nada muda, 2 = há mudanças, 1 = erro
rc=0; terraform -chdir="$dir" plan -out="$plan" -detailed-exitcode || rc=$?
case $rc in
  0) echo "Nada a aplicar: código e GitHub já batem."; exit 0 ;;
  2) ;;
  *) echo "ERRO no plan"; exit 1 ;;
esac

# 3. Um humano lê o plano e confirma
read -r -p "Aplicar EXATAMENTE este plano? Digite 'sim': " ok
[ "$ok" = sim ] || { echo "Cancelado. Nada foi aplicado."; exit 1; }

# 4. Apply do plano revisado e a prova
terraform -chdir="$dir" apply "$plan"
if terraform -chdir="$dir" plan -detailed-exitcode >/dev/null; then
  echo "PROVA OK: No changes depois do apply."
else
  echo "ATENÇÃO: ainda há diferença depois do apply"; exit 1
fi
