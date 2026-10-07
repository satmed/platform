terraform {
  required_version = ">= 1.6"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Token vem de GITHUB_TOKEN, nunca deste arquivo.
provider "github" {
  owner = "satmed"
}
