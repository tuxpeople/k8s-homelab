data "vsphere_datacenter" "this" {
  for_each = var.vms

  name = each.value.datacenter
}

data "vsphere_compute_cluster" "this" {
  for_each = var.vms

  name          = each.value.cluster
  datacenter_id = data.vsphere_datacenter.this[each.key].id
}

data "vsphere_datastore" "this" {
  for_each = var.vms

  name          = each.value.datastore
  datacenter_id = data.vsphere_datacenter.this[each.key].id
}

data "vsphere_network" "this" {
  for_each = var.vms

  name          = each.value.network
  datacenter_id = data.vsphere_datacenter.this[each.key].id
}


data "vsphere_virtual_machine" "template" {
  for_each = var.vms

  name          = each.value.template
  datacenter_id = data.vsphere_datacenter.this[each.key].id
}
