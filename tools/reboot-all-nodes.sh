#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

export KUBECONFIG=~/iCloudDrive/Allgemein/kubectl/homelab.yaml

for i in $(kubectl get nodes -o name | cut -d'/' -f2); do
  step "Update SSH Host-Key for ${i}"
  ssh-keygen -R ${i}; ssh-keygen -R `dig +short ${i}`; ssh-keyscan -t rsa ${i},`dig +short ${i}` >> ~/.ssh/known_hosts

  step "Drain ${i}"
  kubectl drain --ignore-daemonsets --delete-emptydir-data --force ${i}

  step "Reboot ${i}"
  ssh ${i} -l ansible "reboot"

  step "Uncordon ${i}"
  sleep 5
  kubectl uncordon ${i}

  step "Sleep for 1 minute"
  sleep 60
done

cd ${_pwd}
