#!/usr/bin/env bash
_step_counter=0
step() {
        _step_counter=$(( _step_counter + 1 ))
        printf '\n\033[1;36m%d) %s\033[0m\n' $_step_counter "$@" >&2  # bold cyan
}

if ! kubectl get nodes | grep k3s > /dev/null; then
    echo "Fatal error"
    exit 1
fi

export KUBECONFIG=~/iCloudDrive/Allgemein/kubectl/homelab.yaml
OLDIFS=$IFS
rm -f ~/iCloudDrive/Allgemein/backup/kubernetes/*
cd ~/git/k8s-homelab/hacks

for line in $(cat backup.txt); do
IFS='|'
read -a strarr <<< "${line}"
POD=$(kubectl get pods -l ${strarr[1]} -n ${strarr[0]} --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') # --field-selector 'status.phase==Running')
NAME=$(echo ${strarr[1]}--${strarr[2]} | tr '=' '-' | tr '/' '-')
echo ""
echo "Namespace ${strarr[0]} / Pod $POD / Folder ${strarr[2]}"
cat ~/iCloudDrive/Allgemein/backup/kubernetes/${NAME}.tar.gz | kubectl exec $POD -n ${strarr[0]} -- tar -xzf - -C "${strarr[2]}"
sleep 2
kubectl delete pod $POD -n ${strarr[0]}
#kubectl -n ${strarr[0]} cp $POD:${strarr[2]} backup/${NAME}/
done

IFS=${OLDIFS}
