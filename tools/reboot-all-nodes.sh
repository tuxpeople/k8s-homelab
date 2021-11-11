#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

for i in k3s-node1 k3s-node2 k3s-node3 k3s-node-a; do
  step "Update SSH Host-Key for ${i}"
  ssh-keygen -R ${i}; ssh-keygen -R `dig +short ${i}`; ssh-keyscan -t rsa ${i},`dig +short ${i}` >> ~/.ssh/known_hosts

  step "Reboot ${i}"
  ssh ${i} -l root "reboot"

  step "Sleep for 1 minute"
  sleep 60
done

cd ${_pwd}
