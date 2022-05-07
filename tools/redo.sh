#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

. ./provision/infrastructure/settings.env

step "Recreate k3s-node1.lab"
ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node1.lab"
kubectl delete nodes k3s-node1.lab
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node1.lab; ssh-keygen -R `dig +short k3s-node1.lab`; ssh-keyscan -t rsa k3s-node1.lab,`dig +short k3s-node1.lab` >> ~/.ssh/known_hosts
#ssh k3s-node1.lab -l ansible "sudo yum -y install python38"
ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1.lab"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node1.lab
ansible-playbook -i provision/ansible/inventory/hosts.yml -l k3s-node1.lab provision/ansible/playbooks/ubuntu-prepare.yml
ansible-playbook -i provision/ansible/inventory/hosts.yml provision/ansible/playbooks/k3s-install.yml

step "Sleep 120s"
sleep 120

step "Recreate k3s-node2.lab"
ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node2.lab"
kubectl delete nodes k3s-node2.lab
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node2.lab; ssh-keygen -R `dig +short k3s-node2.lab`; ssh-keyscan -t rsa k3s-node2.lab,`dig +short k3s-node2.lab` >> ~/.ssh/known_hosts
#ssh k3s-node2.lab -l ansible "sudo yum -y install python38"
ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2.lab"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node2.lab
ansible-playbook -i provision/ansible/inventory/hosts.yml -l k3s-node2.lab provision/ansible/playbooks/ubuntu-prepare.yml
ansible-playbook -i provision/ansible/inventory/hosts.yml provision/ansible/playbooks/k3s-install.yml

step "Sleep 120s"
sleep 120

step "Recreate k3s-node3.lab"
ssh lab3 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node3.lab"
kubectl delete nodes k3s-node3.lab
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node3.lab; ssh-keygen -R `dig +short k3s-node3.lab`; ssh-keyscan -t rsa k3s-node3.lab,`dig +short k3s-node3.lab` >> ~/.ssh/known_hosts
#ssh k3s-node3.lab -l ansible "sudo yum -y install python38"
ssh lab3 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3.lab"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node3.lab
ansible-playbook -i provision/ansible/inventory/hosts.yml -l k3s-node3.lab provision/ansible/playbooks/ubuntu-prepare.yml
ansible-playbook -i provision/ansible/inventory/hosts.yml provision/ansible/playbooks/k3s-install.yml

cd ${_pwd}
