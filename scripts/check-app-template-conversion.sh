#!/bin/bash

# Script to verify app-template conversions are complete and correct
# Usage: ./check-app-template-conversion.sh

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_app() {
    local app_dir="$1"
    local helmrelease_file="$app_dir/helmrelease.yaml"
    local values_file="$app_dir/values.yaml"
    local kustomization_file="$app_dir/kustomization.yaml"

    # Skip if not app-template
    if [[ ! -f "$helmrelease_file" ]] || ! grep -q "chart: app-template" "$helmrelease_file"; then
        return 0
    fi

    local app_name
    app_name=$(yq eval '.metadata.name' "$helmrelease_file" 2>/dev/null || basename "$app_dir")

    echo "=== $app_name ==="
    echo "📁 $app_dir"

    # Check if has values.yaml
    if [[ ! -f "$values_file" ]]; then
        log_error "❌ Missing values.yaml"
        return 1
    fi

    # Check if values.yaml has schema header
    if ! head -1 "$values_file" | grep -q "yaml-language-server.*app-template"; then
        log_warning "⚠️  values.yaml missing schema header"
    else
        log_success "✅ values.yaml has schema header"
    fi

    # Check if kustomization.yaml has values configMap
    if [[ ! -f "$kustomization_file" ]]; then
        log_error "❌ Missing kustomization.yaml"
        return 1
    fi

    if ! grep -q "configMapGenerator" "$kustomization_file"; then
        log_error "❌ kustomization.yaml missing configMapGenerator"
        return 1
    fi

    if ! grep -q "${app_name}-values" "$kustomization_file"; then
        log_error "❌ kustomization.yaml missing ${app_name}-values configMap"
        return 1
    fi

    log_success "✅ kustomization.yaml has ${app_name}-values configMap"

    # Check if helmrelease.yaml uses valuesFrom
    if grep -q "^  values:" "$helmrelease_file"; then
        log_error "❌ helmrelease.yaml still has inline values (should use valuesFrom)"
        return 1
    fi

    if ! grep -q "valuesFrom" "$helmrelease_file"; then
        log_error "❌ helmrelease.yaml missing valuesFrom"
        return 1
    fi

    if ! grep -A5 "valuesFrom" "$helmrelease_file" | grep -q "${app_name}-values"; then
        log_error "❌ helmrelease.yaml valuesFrom doesn't reference ${app_name}-values"
        return 1
    fi

    log_success "✅ helmrelease.yaml uses valuesFrom with ${app_name}-values"

    echo ""
    return 0
}

main() {
    log_info "Checking app-template conversion status..."

    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log_error "yq is required but not installed. Please install yq first."
        exit 1
    fi

    local total=0
    local success=0
    local failed=0

    # Find all app-template applications
    while IFS= read -r -d '' helmrelease_file; do
        app_dir=$(dirname "$helmrelease_file")

        if [[ -f "$helmrelease_file" ]] && grep -q "chart: app-template" "$helmrelease_file"; then
            ((total++))
            if check_app "$app_dir"; then
                ((success++))
            else
                ((failed++))
            fi
        fi
    done < <(find kubernetes/apps -name "helmrelease.yaml" -print0)

    # Also check special cases
    special_dirs=(
        "kubernetes/apps/network/external/cloudflared"
        "kubernetes/apps/network/external/openvpn"
        "kubernetes/apps/security/external-secrets/secretstores/onepassword"
    )

    for dir in "${special_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            helmrelease_file="$dir/helmrelease.yaml"
            if [[ -f "$helmrelease_file" ]] && grep -q "chart: app-template" "$helmrelease_file"; then
                ((total++))
                if check_app "$dir"; then
                    ((success++))
                else
                    ((failed++))
                fi
            fi
        fi
    done

    echo "======================================"
    log_info "Summary:"
    log_info "  Total app-template apps: $total"
    log_success "  Successfully converted: $success"
    if [[ $failed -gt 0 ]]; then
        log_error "  Failed/incomplete: $failed"
        exit 1
    else
        log_success "🎉 All app-template applications properly converted!"
    fi
}

main "$@"
