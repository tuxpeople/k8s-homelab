#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

. settings.env

step "Create VMs"
# ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:E5:DB:22:E2:BB" k3s-node1"
# ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:7B:49:C3:1C:A9" k3s-node2"
# ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:CA:08:F4:41:F3" k3s-node3"

ssh root@192.168.8.11 "qm clone 9000 701 --full --name k3s-node1; qm set 701 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 701 -net0 virtio=12:CA:08:F4:41:F3,bridge=vmbr0; qm resize 701 scsi0 ${OS_DISK}G; qm set 701 --onboot=1; qm start 701"
ssh root@192.168.8.12 "qm clone 9000 702 --full --name k3s-node2; qm set 702 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 702 -net0 virtio=12:7B:49:C3:1C:A9,bridge=vmbr0; qm resize 702 scsi0 ${OS_DISK}G; qm set 702 --onboot=1; qm start 702"
ssh root@192.168.8.13 "qm clone 9000 703 --full --name k3s-node3; qm set 703 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 703 -net0 virtio=12:CA:08:F4:41:F3,bridge=vmbr0; qm resize 703 scsi0 ${OS_DISK}G; qm set 703 --onboot=1; qm start 703"

step "Sleep 30s and allow VMs to boot"
sleep 30

step "Reboot VMs"
for h in 192.168.8.20{1..3}; do
  ssh ansible@${h} "sudo reboot"
done

step "Sleep 30s and allow VMs to boot"
sleep 30

# ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1"
# ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2"
# ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3"

step "Update SSH Host-Keys"
for i in k3s-node1 k3s-node2 k3s-node3; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
done

