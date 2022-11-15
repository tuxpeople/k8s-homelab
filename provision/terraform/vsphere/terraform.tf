terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.2.0"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.1"
    }
  }
  backend "local" {
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

resource "vsphere_virtual_machine" "allvms" {
  for_each = var.vms

  resource_pool_id = data.vsphere_compute_cluster.this[each.key].resource_pool_id
  datastore_id     = data.vsphere_datastore.this[each.key].id
  folder           = each.value.folder

  name     = each.value.vmname
  num_cpus = each.value.vCPU
  memory   = each.value.vMEM

  guest_id = data.vsphere_virtual_machine.template[each.key].guest_id

  cdrom {
    client_device = true
  }

  network_interface {
    network_id = data.vsphere_network.this[each.key].id
  }
  wait_for_guest_net_timeout = 0

  disk {
    label            = "disk0"
    size             = each.value.disksize
    eagerly_scrub    = each.value.eagerly_scrub
    thin_provisioned = each.value.thin_provisioned
  }
  clone {
    template_uuid = data.vsphere_virtual_machine.template[each.key].id
  }

  vapp {
    properties = {
      user-data   = each.value.user_data != "" ? base64encode(file("${path.module}/${each.value.user_data}")) : base64encode(file("${path.module}/cloud-init.yaml"))
      hostname    = "${each.value.hostname}"
      instance-id = "${each.value.vmname}"
    }
  }

  /* extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("cloud-init.tftpl", {
      hostname    = "${each.value.hostname}",
      instance_id = "${each.value.vmname}"
    }))
    "guestinfo.userdata.encoding" = "base64"
  } */

  provisioner "local-exec" {
    command = "sleep 120; fix-ssh-key ${each.value.hostname}"
  }
}
/*
resource "null_resource" "remoteExecProvisionerWFolder" {

  provisioner "file" {
    content     = <<-DOC
    %{for vm in var.vms~}
host-record=${vm.hostname},${vm.ip}
    %{endfor~}
    DOC
    destination = "/mnt/data/dns.d/k8s-homelab.dns"
  }

  connection {
    host = "10.20.30.1"
    type = "ssh"
    user = "root"
  }
} */
