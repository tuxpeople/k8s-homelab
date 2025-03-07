#!/usr/bin/env bash

FOLDERS="kubernetes/flux/meta/repositories/oci kubernetes/flux/meta/repositories/helm kubernetes/flux/meta/repositories/git"

_pwd="$(pwd)"
_basedir="${_pwd}/$(dirname $(which ${0}))"

cd ${_basedir} && cd $(git rev-parse --show-toplevel)

#https://stackoverflow.com/a/11165642

comm -13 <(grep SECRET_ kubernetes/components/common/cluster-secrets.sops.yaml | awk '{print $1}' | cut -d':' -f1 | sort -u) <(grep -r \${SECRET_ | cut -d'$' -f2 | cut -d'{' -f2 | cut -d'}' -f1 | cut -d'/' -f1 | sort -u | grep -v Binary)
