terraform {
  backend "local" {
  }
}

module "vsphere" {
    source = "./vsphere"
}

module "cloudflare" {
    source = "./cloudflare"
}
