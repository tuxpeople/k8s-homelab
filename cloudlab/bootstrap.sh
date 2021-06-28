#!/usr/bin/env bash

export TF_VAR_client_id=$(/usr/bin/security find-generic-password -w -a "johnnyappleseed" -l "aks-client-id")
export TF_VAR_client_secret=$(/usr/bin/security find-generic-password -w -a "johnnyappleseed" -l "aks-client-secret")

cd terraform

tfenv use 0.15.3

terraform fmt
terraform init
terraform validate
terraform plan -out=out.plan
terraform apply -auto-approve out.plan 

rm -f out.plan

echo "$(terraform output kube_config)" | grep -v EOT > ~/iCloudDrive/Allgemein/kubectl/azurek8s

export KUBECONFIG=~/iCloudDrive/Allgemein/kubectl/azurek8s

kubectl get nodes