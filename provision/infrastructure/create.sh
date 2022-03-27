#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

. settings.env

step "Create VMs"
ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:E5:DB:22:E2:BB" k3s-node1"
ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:7B:49:C3:1C:A9" k3s-node2"
ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:CA:08:F4:41:F3" k3s-node3"

step "Sleep 30s and allow VMs to boot"
sleep 30

ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1"
ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2"
ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3"

step "Update SSH Host-Keys"
for i in k3s-node1 k3s-node2 k3s-node3; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
done
