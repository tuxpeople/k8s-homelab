#!/usr/bin/env bash
ansible-galaxy install -r requirements.yml --ignore-errors

# run the playbooks
ansible-playbook -i inventories/cluster.list plays/init.yaml
ansible-playbook -i inventories/cluster.list plays/base.yaml
ansible-playbook -i inventories/cluster.list plays/k3s_cluster.yml
ansible-playbook -i inventories/cluster.list plays/flux.yml
