#!/usr/bin/env bash

FOLDERS="kubernetes/flux/repositories/oci kubernetes/flux/repositories/helm kubernetes/flux/repositories/git"

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

_gitdir="$(git rev-parse --show-toplevel)"

# https://github.com/lyz-code/yamlfix/blob/main/docs/index.md#configure-environment-prefix
export YAMLFIX_SEQUENCE_STYLE="block_style"

for i in ${FOLDERS}; do
  cd ${i}
  f=$(ls -1 | grep -v kustomization.yaml)
  if [[ ! -z "${f}" ]]; then
    rm -f kustomization.yaml
    kustomize create --autodetect
    #gawk -i inplace 'NR==1{print "# yaml-language-server: $schema=https://json.schemastore.org/kustomization"}1' kustomization.yaml
    yamlfix kustomization.yaml
  fi
  cd ${_gitdir}
done

cd ${_gitdir}

for d in $(for i in $(find kubernetes -name ks.yaml); do echo $i | rev | cut -d/ -f3- | rev; done | sort -u); do
  cd ${d}
  rm -f kustomization.yaml
  kustomize create --autodetect
  for k in */ks.yaml; do
    kustomize edit add resource ${k}
  done
  #gawk -i inplace 'NR==1{print "# yaml-language-server: $schema=https://json.schemastore.org/kustomization"}1' kustomization.yaml
  yamlfix kustomization.yaml
  cd ${_gitdir}
done
