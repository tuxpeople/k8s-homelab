#cloud variables

variable "vsphere_env" {
  type = object({
    server   = string
    user     = string
    password = string
  })
  default = {
    server   = "vcsa.local.lab"
    user     = "administrator@vsphere.local"
    password = "SuperPassw0rd!"
  }
}

variable "vms" {
  type = map(object({
    vCPU             = number
    vMEM             = number
    disksize         = number
    thin_provisioned = string
    eagerly_scrub    = string
    folder           = string
    vmname           = string
    datastore        = string
    network          = string
    template         = string
    cluster          = string
    datacenter       = string
    hostname         = string
  }))
}
