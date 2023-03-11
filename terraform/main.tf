terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.1.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.2.1"
    }
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.3.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.2"
    }
  }
  backend "local" {
  }
}

data "sops_file" "terraform_secrets" {
  source_file = "secret.sops.yaml"
}
