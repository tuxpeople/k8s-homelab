#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

step "Recreate k3s-node1"
ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node1"
kubectl delete nodes k3s-node1
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node1; ssh-keygen -R `dig +short k3s-node1`; ssh-keyscan -t rsa k3s-node1,`dig +short k3s-node1` >> ~/.ssh/known_hosts
#ssh k3s-node1 -l ansible "sudo yum -y install python38"
ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node1
ansible-playbook -i inventories/hosts.yml plays/init.yaml
ansible-playbook -i inventories/hosts.yml plays/base.yaml
ansible-playbook -i inventories/hosts.yml plays/k3s_cluster.yaml

step "Recreate k3s-node2"
ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node2"
kubectl delete nodes k3s-node2
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node2; ssh-keygen -R `dig +short k3s-node2`; ssh-keyscan -t rsa k3s-node2,`dig +short k3s-node2` >> ~/.ssh/known_hosts
#ssh k3s-node2 -l ansible "sudo yum -y install python38"
ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node2
ansible-playbook -i inventories/hosts.yml plays/init.yaml
ansible-playbook -i inventories/hosts.yml plays/base.yaml
ansible-playbook -i inventories/hosts.yml plays/k3s_cluster.yaml

step "Recreate k3s-node3"
ssh lab3 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node3"
kubectl delete nodes k3s-node3
step "Sleep 30s and allow VM to boot"
sleep 30
ssh-keygen -R k3s-node2; ssh-keygen -R `dig +short k3s-node2`; ssh-keyscan -t rsa k3s-node2,`dig +short k3s-node2` >> ~/.ssh/known_hosts
#ssh k3s-node2 -l ansible "sudo yum -y install python38"
ssh lab3 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3"
step "Run the playbooks"
rm -rf .cache/facts/k3s-node3
ansible-playbook -i inventories/hosts.yml plays/init.yaml
ansible-playbook -i inventories/hosts.yml plays/base.yaml
ansible-playbook -i inventories/hosts.yml plays/k3s_cluster.yaml
ansible-playbook -i inventories/hosts.yml plays/k3s_cluster.yaml

cd ${_pwd}
