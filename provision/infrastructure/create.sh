#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

. settings.env

ssh root@192.168.8.11 "qm stop 701; qm destroy 701"
ssh root@192.168.8.12 "qm stop 702; qm destroy 702"
ssh root@192.168.8.13 "qm stop 703; qm destroy 703"

step "Create VMs"
# ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:E5:DB:22:E2:BB" k3s-node1.lab"
# ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:7B:49:C3:1C:A9" k3s-node2.lab"
# ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible -M "12:CA:08:F4:41:F3" k3s-node3.lab"

ssh root@192.168.8.11 "qm clone 9000 701 --full --name k3s-node1.lab; qm set 701 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 701 --ipconfig0 ip=192.168.8.101/24,gw=192.168.8.1; qm resize 701 scsi0 ${OS_DISK}G; qm set 701 --onboot=1; qm start 701"
ssh root@192.168.8.11 "qm clone 9000 702 --full --name k3s-node2.lab; qm set 702 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 702 --ipconfig0 ip=192.168.8.102/24,gw=192.168.8.1; qm migrate 702 pve2"
ssh root@192.168.8.11 "qm clone 9000 703 --full --name k3s-node3.lab; qm set 703 --memory ${MASTER_MEM} --sockets 2 --cores 2; qm set 703 --ipconfig0 ip=192.168.8.103/24,gw=192.168.8.1; qm migrate 703 pve3"

ssh root@192.168.8.12 "qm resize 702 scsi0 ${OS_DISK}G; qm set 702 --onboot=1; qm start 702"
ssh root@192.168.8.13 "qm resize 703 scsi0 ${OS_DISK}G; qm set 703 --onboot=1; qm start 703"

step "Sleep 60s and allow VMs to boot and do cloud-init"
sleep 60

# ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1.lab"
# ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2.lab"
# ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3.lab"

step "Update SSH Host-Keys"
for i in k3s-node1.lab k3s-node2.lab k3s-node3.lab; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
done
