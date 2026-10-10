#!/usr/bin/env bash
# Cria a GitHub App que o CI usa no Terraform (identidade de máquina, não PAT de pessoa)
# pelo "manifest flow": você só clica em Create e Install. A chave privada vai direto
# para o secret do environment; não fica em arquivo nem aparece na tela.
# Uso: scripts/github-app-create.sh plan    (só leitura, para PR e drift)
#      scripts/github-app-create.sh apply   (escrita, só da main com aprovação)
set -euo pipefail

papel=${1:-}
case $papel in
  plan) nivel="read"; acoes="read" ;;
  apply) nivel="write"; acoes="write" ;;
  *) echo "uso: $0 plan|apply"; exit 2 ;;
esac
org=satmed
repo=satmed/platform
env="github-$papel"

gh api "repos/$repo/environments/$env" >/dev/null 2>&1 \
  || { echo "ERRO: environment $env não existe (rode scripts/tf-apply.sh antes)"; exit 1; }

tmp=$(mktemp -d) && chmod 700 "$tmp"
trap 'kill "${servidor:-}" 2>/dev/null || true; rm -rf "$tmp"' EXIT
estado=$(openssl rand -hex 16) # anti-CSRF: o callback só vale com este valor

# Servidor de 1 uso em 127.0.0.1, porta livre escolhida pelo sistema: serve a página
# e recebe o ?code= do GitHub. Só aceita o callback com o state certo.
python3 -I - "$tmp" "$estado" <<'PY' &
import http.server, sys, urllib.parse, pathlib
pasta, estado = pathlib.Path(sys.argv[1]), sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        u = urllib.parse.urlparse(self.path); q = urllib.parse.parse_qs(u.query)
        if u.path == "/":
            corpo = (pasta / "index.html").read_bytes()
        elif u.path == "/callback" and q.get("state") == [estado] and q.get("code"):
            (pasta / "code").write_text(q["code"][0])
            corpo = "App criada. Pode fechar esta aba e voltar ao terminal.".encode()
        else:
            self.send_response(400); self.end_headers(); return
        self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers(); self.wfile.write(corpo)
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
(pasta / "porta").write_text(str(srv.server_address[1]))
while not (pasta / "code").exists():
    srv.handle_request()
PY
servidor=$!
for _ in $(seq 1 50); do [ -s "$tmp/porta" ] && break; sleep 0.1; done
[ -s "$tmp/porta" ] || { echo "ERRO: servidor local não subiu"; exit 1; }
porta=$(cat "$tmp/porta")

# Permissões mínimas para o provider integrations/github gerir org, times, repos e rulesets.
jq -n --arg nome "satmed-terraform-$papel" --arg n "$nivel" --arg a "$acoes" \
  --arg cb "http://127.0.0.1:$porta/callback" '{
    name: $nome,
    url: "https://github.com/satmed/platform",
    description: "Terraform da governança da org satmed (CI do satmed/platform)",
    public: false,
    redirect_url: $cb,
    hook_attributes: {url: "https://example.invalid", active: false},
    default_events: [],
    default_permissions: {
      administration: $n,
      organization_administration: $n,
      members: $n,
      actions: $a,
      metadata: "read"
    }
  }' > "$tmp/manifest.json"

# Página local que faz o POST do manifest para o GitHub (o manifest flow exige um form).
jq -r --arg acao "https://github.com/organizations/$org/settings/apps/new?state=$estado" '
  "<!doctype html><meta charset=utf-8><title>GitHub App</title>
   <form id=f method=post action=\"" + $acao + "\">
   <input type=hidden name=manifest value=\"" + (tojson | @html) + "\"></form>
   <script>document.getElementById(\"f\").submit()</script>"' "$tmp/manifest.json" > "$tmp/index.html"


echo "Abrindo o navegador: confira as permissões e clique em 'Create GitHub App'."
open "http://127.0.0.1:$porta/"
for _ in $(seq 1 300); do [ -f "$tmp/code" ] && break; sleep 1; done
kill "$servidor" 2>/dev/null || true
[ -f "$tmp/code" ] || { echo "ERRO: o GitHub não devolveu o código em 5 min"; exit 1; }

# Troca o código (vale 1 hora, uso único) pela app: id, client_id e a chave privada.
gh api -X POST "app-manifests/$(cat "$tmp/code")/conversions" > "$tmp/app.json"
slug=$(jq -r .slug "$tmp/app.json")
jq -r .pem "$tmp/app.json" | gh secret set TF_APP_PRIVATE_KEY -R "$repo" --env "$env"
gh variable set TF_APP_CLIENT_ID -R "$repo" --env "$env" -b "$(jq -r .client_id "$tmp/app.json")"
echo "App $slug criada; chave guardada no secret do environment $env."

echo "Agora instale na org satmed (All repositories): o Terraform gerencia todos os repos."
open "https://github.com/apps/$slug/installations/new"
