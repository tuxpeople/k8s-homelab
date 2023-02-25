terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.3.1"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.2"
    }
  }
}

data "sops_file" "cloudflare_secrets" {
  source_file = "secret.sops.yaml"
}

provider "vsphere" {
  user           = data.sops_file.cloudflare_secrets.data["vsphere_user"]
  password       = data.sops_file.cloudflare_secrets.data["vsphere_password"]
  vsphere_server = data.sops_file.cloudflare_secrets.data["vsphere_server"]

  # If you have a self-signed cert
  allow_unverified_ssl = true
}

module "k3s-node" {
  source          = "github.com/tuxpeople/tf-modules//vsphere/vsphere_vm"
  hostname        = "k3s-node"
  vCPU            = 4
  vMEM            = 8192
  disksize        = 50
  instances_count = 3
  folder          = "Kubernetes/Prod"
  network         = "Lab (308)"
  datastore       = "datastore11_ssd"
  #template        = "jammy-server-cloudimg-amd64"
  ssh_private_keyfile = ""
  mac_address = ["00:50:56:8d:c8:e2", "00:50:56:8d:cb:63", "00:50:56:8d:e7:1e"]
}
