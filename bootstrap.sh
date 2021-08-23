#!/usr/bin/env bash
ansible-galaxy install -r server/requirements.yaml --ignore-errors

# Create VMs
ssh lab1 -l root "kvm-install-vm create -a -c 2 -m 2048 -d 40 -y -u ansible k3s-lb1"
ssh lab2 -l root "kvm-install-vm create -a -c 2 -m 2048 -d 40 -y -u ansible k3s-lb2"
ssh lab1 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 40 -y -u ansible k3s-node1"
ssh lab2 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 40 -y -u ansible k3s-node2"
ssh lab2 -l root "kvm-install-vm create -a -c 4 -m 8192 -d 40 -y -u ansible k3s-node3"

# Wait for VMs to boot
sleep 30

for i in k3s-lb1 k3s-lb2 k3s-node1 k3s-node2 k3s-node3; do
  ssh-keygen -R $i; ssh-keygen -R `dig +short $i`; ssh-keyscan -t rsa $i,`dig +short $i` >> ~/.ssh/known_hosts
  ssh $i -l ansible "sudo yum -y install python38"
done

# Change into ansible dir
cd server

# Delete facts cache
rm -rf .cache

# run the playbooks
ansible-playbook -i inventories/cluster.list plays/init.yaml
ansible-playbook -i inventories/cluster.list plays/base.yaml
ansible-playbook -i inventories/cluster.list plays/loadbalancer_init.yaml
ansible-playbook -i inventories/cluster.list plays/k3s_cluster.yaml
ansible-playbook -i inventories/cluster.list plays/flux.yaml
ansible-playbook -i inventories/cluster.list plays/loadbalancer_finish.yaml
