variable "region" {
  description = "São Paulo: o state tem o billing_email (dado pessoal), fica no Brasil."
  type        = string
  default     = "sa-east-1"
}

variable "github_repo" {
  description = "Único repo que pode assumir as roles."
  type        = string
  default     = "satmed/platform"
}

variable "create_oidc_provider" {
  description = "false se a conta já tem o provider OIDC do GitHub (só pode existir um)."
  type        = bool
  default     = true
}
