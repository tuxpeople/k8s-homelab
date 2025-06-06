#!/usr/bin/env bash

FOLDERS=(
  "kubernetes/flux/meta/repositories/oci"
  "kubernetes/flux/meta/repositories/helm"
  "kubernetes/flux/meta/repositories/git"
)

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname "$0")"

cd "${_basedir}" && cd "$(git rev-parse --show-toplevel)"

_gitdir="$(git rev-parse --show-toplevel)"

# https://github.com/lyz-code/yamlfix/blob/main/docs/index.md#configure-environment-prefix
export YAMLFIX_SEQUENCE_STYLE="block_style"

for i in "${FOLDERS[@]}"; do
  cd "${i}"
  f=$(ls -1 | grep -v kustomization.yaml)
  if [[ -n "${f}" ]]; then
  cat <<EOF > kustomization.yaml
# yaml-language-server: \$schema=https://json.schemastore.org/kustomization
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
EOF
  for k in ${f}; do
    kustomize edit add resource "./${k}"
  done
  #gawk -i inplace 'NR==1{print "# yaml-language-server: $schema=https://json.schemastore.org/kustomization"}1' kustomization.yaml
  yamlfix kustomization.yaml
  cd ${_gitdir}
  else
  cat <<EOF > kustomization.yaml
# yaml-language-server: \$schema=https://json.schemastore.org/kustomization
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: []
EOF
  fi
  cd ${_gitdir}
done

cd ${_gitdir}

for d in $(for i in $(find kubernetes/apps -name ks.yaml); do echo "$i" | rev | cut -d/ -f3- | rev; done | sort -u); do
  cd "${d}"
  # rm -f kustomization.yaml
  # kustomize create --autodetect
  cat <<EOF > kustomization.yaml
# yaml-language-server: \$schema=https://json.schemastore.org/kustomization
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
  namespace: $(basename "${d}")
components:
  - ../../components/common
EOF
  for k in */ks.yaml; do
    kustomize edit add resource "./${k}"
  done
  #gawk -i inplace 'NR==1{print "# yaml-language-server: $schema=https://json.schemastore.org/kustomization"}1' kustomization.yaml
  yamlfix kustomization.yaml
  cd ${_gitdir}
done
