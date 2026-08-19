#!/usr/bin/env bash
set -Eeuo pipefail

GENERATE_ONLY=false

case "${1:-}" in
  "") ;;
  --generate-only) GENERATE_ONLY=true ;;
  *)
    echo "Usage: $0 [--generate-only]" >&2
    exit 2
    ;;
esac

ROOT_DIR="$(git rev-parse --show-toplevel)"
HELMRELEASE_FILE="${ROOT_DIR}/kubernetes/apps/security/kyverno/app/helmrelease.yaml"
CRD_FILE="${ROOT_DIR}/kubernetes/apps/security/kyverno/crds/crds.yaml"
CHART_VERSION="$(yq '.spec.chart.spec.version' "${HELMRELEASE_FILE}")"
TEMP_CRD_FILE="$(mktemp)"
trap 'rm -f "${TEMP_CRD_FILE}"' EXIT

helm template kyverno-crds oci://ghcr.io/kyverno/charts/kyverno \
  --version "${CHART_VERSION}" \
  | yq eval '. | select(.kind == "CustomResourceDefinition")' \
  > "${TEMP_CRD_FILE}"

mv "${TEMP_CRD_FILE}" "${CRD_FILE}"

if [[ "${GENERATE_ONLY}" == true ]]; then
  exit 0
fi

CURRENT_BRANCH="$(git -C "${ROOT_DIR}" branch --show-current)"

if [[ -z "${CURRENT_BRANCH}" ]]; then
  echo "Cannot commit generated CRDs from a detached HEAD." >&2
  exit 1
fi

git -C "${ROOT_DIR}" add -- "${CRD_FILE}"

if git -C "${ROOT_DIR}" diff --cached --quiet -- "${CRD_FILE}"; then
  echo "Kyverno CRDs are already up to date for chart ${CHART_VERSION}."
  exit 0
fi

git -C "${ROOT_DIR}" commit --only \
  -m "chore(kyverno): generate CRDs for chart ${CHART_VERSION}" \
  -- "${CRD_FILE}"
git -C "${ROOT_DIR}" push origin "${CURRENT_BRANCH}"
