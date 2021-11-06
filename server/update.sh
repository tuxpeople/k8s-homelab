#!/usr/bin/env bash

_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

step "Update flux"
brew upgrade flux

step "Ensure Ansible dependencies are installed"
ansible-galaxy install -r requirements.yaml --ignore-errors

step "Prepare/Update KUBE-VIP"
curl -sL https://kube-vip.io/manifests/rbac.yaml > files/rbac.yaml
export VIP=192.168.8.222
export INTERFACE=eth0
curl -sL kube-vip.io/k3s | vipAddress=$VIP vipInterface=$INTERFACE sh > files/vip.yaml
git add files/vip.yaml files/rbac.yaml
git commit -s -S -m "Update kube-vip deployment"
git push

step "Run the playbooks"
ansible-playbook -i inventories/cluster.list plays/init.yaml
ansible-playbook -i inventories/cluster.list plays/base.yaml
ansible-playbook -i inventories/cluster.list plays/k3s_cluster.yaml
ansible-playbook -i inventories/cluster.list plays/flux.yaml

sleep 20

git pull

step "Update cluster version in readme"
K3S_VERSION=$(kubectl --kubeconfig=/Users/tdeutsch/iCloudDrive/Allgemein/kubectl/homelab.yaml get nodes | grep node1 | awk '{ print $5 }' | cut -d'+' -f1)
sed -i "" "s/k3s-v[^0-9]*\(\([0-9]\.\)\{0,4\}[0-9][^.]\).*-orange/k3s-${K3S_VERSION}-orange/g" ../readme.md
git add ../readme.md
git commit -s -S -m "Update cluster version in readme"
git push
