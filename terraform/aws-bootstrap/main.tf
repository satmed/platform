data "aws_caller_identity" "current" {}

# Sufixo aleatório: nome de bucket é global e o repo é público (sem account id no nome).
resource "random_id" "bucket" {
  byte_length = 4
}

resource "aws_s3_bucket" "state" {
  bucket = "satmed-tfstate-${random_id.bucket.hex}"

  lifecycle {
    prevent_destroy = true # o state é a memória da governança
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced" # sem ACL: só IAM decide
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionamento: um apply ruim não apaga a história; dá para voltar ao state anterior.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # SSE-S3; CMK no KMS custaria US$1/mês sem ganho real aqui
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "versoes-antigas"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days           = 365
      newer_noncurrent_versions = 50 # sempre guarda as 50 últimas, mesmo velhas
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# Só HTTPS. Sem isto, nada impede um cliente mal configurado de falar em texto claro.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "SoTLS"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ── OIDC: o GitHub Actions troca o token do job por credencial AWS de 1 hora. Sem chave fixa.
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
  workflow = "${var.github_repo}/.github/workflows/terraform.yml"

  # O "sub" do token é customizado no repo (terraform/github/oidc.tf) para incluir o
  # workflow: repo + environment + arquivo + ref. Copiar o YAML para outro arquivo não serve.
  sub_plan  = "repo:${var.github_repo}:environment:github-plan:job_workflow_ref:${local.workflow}@*"
  sub_apply = "repo:${var.github_repo}:environment:github-apply:job_workflow_ref:${local.workflow}@refs/heads/main"

  state_key = "github/terraform.tfstate"
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike" # @* : o plan roda em qualquer branch de PR
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.sub_plan]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals" # exato: só o terraform.yml da main, no environment com aprovação
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.sub_apply]
    }
  }
}

# Plan: só lê o state (o plan do CI roda com -lock=false).
data "aws_iam_policy_document" "plan" {
  statement {
    # Sem condição de prefixo: o init do backend lista "env:/" (workspaces). Listar nomes
    # não expõe nada; ler conteúdo continua restrito à chave do state abaixo.
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}"]
  }
}

# Apply: lê e escreve o state e o lock. Nada de IAM, nada fora de github/.
data "aws_iam_policy_document" "apply" {
  source_policy_documents = [data.aws_iam_policy_document.plan.json]
  statement {
    actions = ["s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.state.arn}/${local.state_key}",
      "${aws_s3_bucket.state.arn}/${local.state_key}.tflock",
    ]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}.tflock"]
  }
}

resource "aws_iam_role" "plan" {
  name                 = "satmed-platform-tf-plan"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "plan" {
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

resource "aws_iam_role" "apply" {
  name                 = "satmed-platform-tf-apply"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply" {
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}
