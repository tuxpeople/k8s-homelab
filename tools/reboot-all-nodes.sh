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

step "Disable monitoring"
MONITORS=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -H "Cache-Control: no-cache" -d "api_key=${SECRET}&format=json&logs=1" "https://api.uptimerobot.com/v2/getMonitors" | jq '.monitors[].id')
SECRET=$(kubectl -n flux-system get secrets cluster-secrets -o go-template='{{ .data.SECRET_UPTIMEROBOT_APIKEY | base64decode }}')
for i in $(echo ${MONITORS}); do
  sleep 10
  curl -X POST -H "Cache-Control: no-cache" -H "Content-Type: application/x-www-form-urlencoded" -d "api_key=${SECRET}&format=json&id=${i}&status=0" "https://api.uptimerobot.com/v2/editMonitor"
  echo
done

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

step "Pause for 2 minutes before enabeling monitoring"

step "Enable monitoring"
for i in $(echo ${MONITORS}); do
  curl -X POST -H "Cache-Control: no-cache" -H "Content-Type: application/x-www-form-urlencoded" -d "api_key=${SECRET}&format=json&id=${i}&status=1" "https://api.uptimerobot.com/v2/editMonitor"
  echo
  sleep 10
done

cd ${_pwd}
