vms = {
  k3s-node1 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node1"
    hostname = "k3s-node1"
    folder   = "Kubernetes/Prod"
    network  = "Lab (308)"

    datastore  = "datastore11_ssd"
    datacenter = "SKY"
    template   = "focal-server-cloudimg-amd64"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"

    user_data = ""
  }

  k3s-node2 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node2"
    hostname = "k3s-node2"
    folder   = "Kubernetes/Prod"
    network  = "Lab (308)"

    datastore  = "datastore13_m2"
    datacenter = "SKY"
    template   = "focal-server-cloudimg-amd64"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"

    user_data = ""
  }

  k3s-node3 = {
    vCPU     = 4
    vMEM     = 8192
    disksize = 50

    vmname   = "k3s-node3"
    hostname = "k3s-node3"
    folder   = "Kubernetes/Prod"
    network  = "Lab (308)"

    datastore  = "datastore15_ssd"
    datacenter = "SKY"
    template   = "focal-server-cloudimg-amd64"
    cluster    = "Homelab"

    guest_id         = "ubuntu64Guest"
    thin_provisioned = "true"
    eagerly_scrub    = "false"

    user_data = ""
  }
}
