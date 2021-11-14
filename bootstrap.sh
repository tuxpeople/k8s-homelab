#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

. provision/infrastructure/settings.env

step "Pull the git repo"
git pull

step "Ensure Ansible dependencies are installed"
ansible-galaxy install -r provision/ansible/requirements.yml --ignore-errors

step "Create VMs"
ssh lab1 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node1"
ssh lab2 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node2"
ssh lab3 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node3"
ssh lab4 -l root "kvm-install-vm create -t ${NODE_OS} -a -c ${MASTER_CPU} -m ${MASTER_MEM} -d ${OS_DISK} -y -u ansible k3s-node-a"

step "Sleep 30s and allow VMs to boot"
sleep 30

ssh lab1 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node1"
ssh lab2 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node2"
ssh lab3 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node3"
ssh lab4 -l root "kvm-install-vm attach-disk -d ${DATA_DISK} -t ${DATA_DRIVE} k3s-node-a"

step "Update SSH Host-Keys"
for i in k3s-node1 k3s-node2 k3s-node3 k3s-node-a; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
done

# step "Install Python 3.8 on RHEL/CENTOS"
# for i in k3s-node1 k3s-node2 k3s-node3 k3s-node-a; do
#   ssh $i -l ansible "sudo yum -y install python38"
# done

step "Prepare pre-commit"
brew install pre-commit
pre-commit install

# Change into ansible dir
cd provision/ansible

step "Run the playbooks"
ansible-playbook -i inventory/cluster.list playbooks/ubuntu-prepare.yml
ansible-playbook -i inventory/cluster.list playbooks/k3s-install.yml

cd ${_pwd}
