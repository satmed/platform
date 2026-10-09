#!/usr/bin/env bash
# Commit + PR + espera o CI + merge, a partir da branch atual.
# Uso: scripts/pr.sh "mensagem do commit"   (vira também o título do PR)
set -euo pipefail

msg="${1:?uso: scripts/pr.sh \"mensagem do commit\"}"
branch=$(git branch --show-current)
[ "$branch" != main ] || { echo "ERRO: crie uma branch antes (git switch -c ...)"; exit 1; }

# 1. Mostra o que vai entrar e pede confirmação (nada de commit às cegas)
git add -A
git diff --cached --quiet && { echo "Nada para commitar."; exit 1; }
git diff --cached --stat
read -r -p "Commitar ESTES arquivos? Digite 'sim': " ok
[ "$ok" = sim ] || { echo "Cancelado. Nada foi commitado (git restore --staged . desfaz o add)."; exit 1; }

# 2. Commit: o pre-commit roda aqui; se um hook falhar, o script para
git commit -m "$msg"
git push -u origin "$branch"

# 3. PR: o corpo é a lista de arquivos alterados (rastreável no histórico)
gh pr create --base main --title "$msg" --body "$(git diff --stat origin/main...HEAD)"

# 4. Espera o CI. Se algum check falhar, o script para ANTES do merge
sleep 15   # dá tempo do GitHub registrar os checks do PR
gh pr checks --watch --fail-fast

# 5. Merge (squash) e volta para a main atualizada
gh pr merge --squash --delete-branch
git log --oneline -1
