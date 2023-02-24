#!/bin/bash
helm repo add cilium https://helm.cilium.io/
helm repo update
mkdir /tmp/cilium
helm template cilium cilium/cilium --namespace kube-system --set kubeProxyReplacement=strict --set ipam.operator.clusterPoolIPv4PodCIDR="10.42.0.0/16" > /tmp/cilium/cilium-installation.yaml
cat <<EOF > /tmp/cilium/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
commonLabels:
  app.kubernetes.io/managed-by: Helm
  helm.toolkit.fluxcd.io/name: cilium
  helm.toolkit.fluxcd.io/namespace: kube-system
commonAnnotations:
  meta.helm.sh/release-name: cilium
  meta.helm.sh/release-namespace: kube-system
resources:
  - /tmp/cilium/cilium-installation.yaml
EOF
kubectl kustomize /tmp/cilium/ -o /Users/tdeutsch/git/k8s-homelab/provision/ansible/playbooks/templates/cilium-installation.yaml.j2
