vms = {
  k3s-node1 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node1"
    hostname = "k3s-node1"
    network  = "VM Network"

    datastore  = "NFS"
    datacenter = "SKY"
    template   = "ubuntu-focal-20.04-cloudimg"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"
  }

  k3s-node2 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node2"
    hostname = "k3s-node2"
    network  = "VM Network"

    datastore  = "NFS"
    datacenter = "SKY"
    template   = "ubuntu-focal-20.04-cloudimg"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"
  }

  k3s-node3 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node3"
    hostname = "k3s-node3"
    network  = "VM Network"

    datastore  = "NFS"
    datacenter = "SKY"
    template   = "ubuntu-focal-20.04-cloudimg"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"
  }
}
