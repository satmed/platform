# State remoto e Terraform no CI

Antes: o `terraform.tfstate` da governança só existia no laptop, e o apply era manual
(`scripts/tf-apply.sh`). Se o disco morresse, a org perdia a memória do que o Terraform gerencia.

Depois:

| Peça | Onde | Por quê |
|---|---|---|
| State | S3 `satmed-tfstate-<sufixo>` em `sa-east-1` | versionado, criptografado, só TLS, sem acesso público; lock nativo (`use_lockfile`) |
| Credencial AWS do CI | OIDC → role de 1 hora | nenhuma chave fixa; `sub` exige environment + `terraform.yml` (+ `main` no apply) |
| Credencial GitHub do CI | 2 GitHub Apps (`satmed-terraform-plan` só leitura, `satmed-terraform-apply` escrita) | identidade de máquina, não PAT de pessoa; token de 1 hora |
| Plan | todo PR que mexe em `terraform/github` | resumo no job (sem diff: o repo é público) |
| Apply | push na `main`, depois de aprovar o environment `github-apply` | humano aprova, a máquina aplica o plano salvo e prova `No changes` |
| Drift + 2FA | todo dia 08:00 (Brasília) | mudança feita na mão no GitHub, ou 2FA desligado, vira job vermelho (e-mail) |

`terraform/aws-bootstrap` (bucket + roles) é aplicado **só por humano**: o CI não tem permissão de IAM.

## Ordem da migração (uma vez)

Pré-requisito: `aws login` numa conta AWS sua. Tudo a partir da `main` atualizada.

```bash
scripts/bootstrap-state.sh          # cria bucket+roles (pede 'sim'), migra os 2 states, grava vars
scripts/tf-apply.sh                 # agora no S3: cria environments, OIDC sub, rulesets pendentes
scripts/bootstrap-state.sh          # de novo: grava AWS_ROLE_ARN e o billing_email nos environments
scripts/github-app-create.sh plan   # navegador: Create → Install (All repositories)
scripts/github-app-create.sh apply  # idem
gh variable set TF_CI_ENABLED -R satmed/platform -b true
gh workflow run terraform.yml -R satmed/platform   # plan + 2FA: os dois têm que ficar verdes
```

O state local antigo vai para `~/.satmed-tfstate-backup/<data>/` (fora do repo). Apague
quando confiar no S3; o versionamento do bucket guarda o histórico daqui para frente.

## Depois da migração

- Mudança na governança: PR → plan no PR → merge → **aprovar o apply** no Actions.
- `scripts/tf-apply.sh` continua como *break-glass* (precisa de `aws login` e `gh auth`).
- Voltar um state ruim: `aws s3api list-object-versions --bucket <bucket> --prefix github/`
  e restaurar a versão anterior.

## Decisões e limites conhecidos

- **SSE-S3, não KMS CMK** (aceite AWS-0132 no `.trivyignore.yaml`, vence 2027-04-07).
- **Dependabot não roda o plan** (não recebe secret de environment); o bump de provider é
  planejado no apply, que tem aprovação humana.
- **Check do título do PR é aviso, não barreira**: um evento atrasado com o título antigo já
  sobrescreveu um check vermelho (PR #16). A barreira é o `commit_message_pattern` do ruleset.
- **Plan em PR usa a app só-leitura**: mesmo um workflow alterado no PR não consegue escrever
  na org (a chave de escrita só existe no environment `github-apply`, que só aceita a `main`).
