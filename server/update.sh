#!/usr/bin/env bash
ansible-galaxy install -r requirements.yaml --ignore-errors

# run the playbooks
ansible-playbook -i inventories/cluster.list plays/init.yaml
ansible-playbook -i inventories/cluster.list plays/base.yaml
ansible-playbook -i inventories/cluster.list plays/loadbalancer_setup.yaml
ansible-playbook -i inventories/cluster.list plays/k3s_cluster.yaml
ansible-playbook -i inventories/cluster.list plays/flux.yaml
ansible-playbook -i inventories/cluster.list plays/loadbalancer.yaml
