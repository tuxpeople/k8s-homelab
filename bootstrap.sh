#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

step "Pull the git repo"
git pull

step "Ensure Ansible dependencies are installed"
ansible-galaxy install -r server/requirements.yaml --ignore-errors

step "Create VMs"
ssh lab1 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 50 -y -u ansible k3s-node1"
ssh lab2 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 50 -y -u ansible k3s-node2"
ssh lab3 -l root "kvm-install-vm create -t ubuntu2004 -a -c 4 -m 8192 -d 50 -y -u ansible k3s-node3"
ssh lab4 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 50 -y -u ansible k3s-node-a"

step "Sleep 30s and allow VMs to boot"
sleep 30

ssh lab1 -l root "kvm-install-vm attach-disk -d 80 -t vdc k3s-node1"
ssh lab2 -l root "kvm-install-vm attach-disk -d 80 -t vdc k3s-node2"
ssh lab3 -l root "kvm-install-vm attach-disk -d 80 -t vdc k3s-node3"
ssh lab4 -l root "kvm-install-vm attach-disk -d 80 -t vdc k3s-node-a"

step "Update SSH Host-Keys"
for i in k3s-node1 k3s-node2 k3s-node-a; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
  ssh $i -l ansible "sudo yum -y install python38"
done

step "Prepare pre-commit"
brew install pre-commit
pre-commit install

# Change into ansible dir
cd server

step "Prepare/Update KUBE-VIP"
curl -sL https://kube-vip.io/manifests/rbac.yaml > files/rbac.yaml
export VIP=192.168.8.222
export INTERFACE=eth0
curl -sL kube-vip.io/k3s | vipAddress=$VIP vipInterface=$INTERFACE sh > files/vip.yaml
git add files/vip.yaml files/rbac.yaml
git commit -s -S -m "Update kube-vip deployment"
git push

step "Delete facts cache"
rm -rf .cache

step "Run the playbooks"
ansible-playbook -i inventories/cluster.list plays/init.yaml
ansible-playbook -i inventories/cluster.list plays/base.yaml
ansible-playbook -i inventories/cluster.list plays/k3s_cluster.yaml
ansible-playbook -i inventories/cluster.list plays/flux.yaml
