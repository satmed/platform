variable "billing_email" {
  description = "E-mail de cobrança da org (valor fica no terraform.tfvars, fora do git)"
  type        = string
  sensitive   = true
}
