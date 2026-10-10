variable "name" {
  description = "Nome do repositório"
  type        = string
}

variable "description" {
  description = "Uma linha sobre o repo"
  type        = string
}

variable "visibility" {
  description = "private (padrão) ou public"
  type        = string
  default     = "private"
}

variable "teams" {
  description = "Acesso por time: slug => { id, permission }"
  type        = map(object({ id = string, permission = string }))
}

variable "required_checks" {
  description = "Checks obrigatórios na main (nomes exatos). Vazio = ainda sem ruleset."
  type        = list(string)
  default     = []
}
