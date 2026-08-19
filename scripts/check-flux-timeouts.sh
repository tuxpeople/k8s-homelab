#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
buffer_seconds="${FLUX_TIMEOUT_BUFFER_SECONDS:-60}"
failures=0
checked=0

duration_to_seconds() {
  local remaining="$1"
  local total=0
  local value unit

  while [[ -n "${remaining}" ]]; do
    if [[ "${remaining}" =~ ^([0-9]+)(h|m|s)(.*)$ ]]; then
      value="${BASH_REMATCH[1]}"
      unit="${BASH_REMATCH[2]}"
      remaining="${BASH_REMATCH[3]}"
      case "${unit}" in
        h) total=$((total + value * 3600)) ;;
        m) total=$((total + value * 60)) ;;
        s) total=$((total + value)) ;;
      esac
    else
      return 1
    fi
  done

  printf '%s\n' "${total}"
}

command -v yq >/dev/null 2>&1 || {
  echo "ERROR: yq v4 is required" >&2
  exit 2
}

echo "Checking Flux Kustomization timeouts against HelmRelease timeouts..."

while IFS= read -r ks_file; do
  while IFS=$'\t' read -r ks_namespace ks_name ks_path ks_timeout; do
    [[ -n "${ks_name}" && -n "${ks_path}" ]] || continue

    app_path="${repo_root}/${ks_path#./}"
    if [[ ! -d "${app_path}" ]]; then
      echo "ERROR: ${ks_namespace}/${ks_name}: path does not exist: ${ks_path}" >&2
      failures=$((failures + 1))
      continue
    fi

    if ! ks_seconds="$(duration_to_seconds "${ks_timeout}")"; then
      echo "ERROR: ${ks_namespace}/${ks_name}: unsupported timeout '${ks_timeout}'" >&2
      failures=$((failures + 1))
      continue
    fi

    while IFS= read -r manifest; do
      while IFS=$'\t' read -r hr_namespace hr_name hr_timeout; do
        [[ -n "${hr_name}" ]] || continue
        checked=$((checked + 1))

        if ! hr_seconds="$(duration_to_seconds "${hr_timeout}")"; then
          echo "ERROR: ${hr_namespace}/${hr_name}: unsupported timeout '${hr_timeout}'" >&2
          failures=$((failures + 1))
          continue
        fi

        required_seconds=$((hr_seconds + buffer_seconds))
        if ((ks_seconds < required_seconds)); then
          echo "ERROR: ${ks_namespace}/${ks_name} (${ks_timeout}) wraps HelmRelease ${hr_namespace}/${hr_name} (${hr_timeout}); require at least ${required_seconds}s including ${buffer_seconds}s buffer" >&2
          failures=$((failures + 1))
        fi
      done < <(
        yq eval --no-colors --unwrapScalar --output-format=tsv \
          'select(.kind == "HelmRelease") | [.metadata.namespace // "(targetNamespace)", .metadata.name, .spec.timeout // "5m"]' \
          "${manifest}"
      )
    done < <(find "${app_path}" -type f \( -name '*.yaml' -o -name '*.yml' \) -print | sort)
  done < <(
    yq eval --no-colors --unwrapScalar --output-format=tsv \
      'select(.kind == "Kustomization" and .apiVersion == "kustomize.toolkit.fluxcd.io/v1" and .spec.wait == true) | [.metadata.namespace // "default", .metadata.name, .spec.path, .spec.timeout // .spec.interval]' \
      "${ks_file}"
  )
done < <(find "${repo_root}/kubernetes/apps" -name ks.yaml -type f -print | sort)

if ((failures > 0)); then
  echo "Found ${failures} timeout inconsistency/inconsistencies across ${checked} HelmRelease(s)." >&2
  exit 1
fi

echo "All ${checked} HelmRelease timeout relationships are consistent."
