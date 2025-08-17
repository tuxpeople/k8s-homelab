#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function main() {
    log info "Checking for missing secrets..."
    
    # Get to repository root
    local root_dir="$(git rev-parse --show-toplevel)"
    cd "$root_dir"
    
    # Extract defined secrets from SOPS file
    local defined_secrets
    defined_secrets=$(grep SECRET_ kubernetes/components/common/cluster-secrets.sops.yaml | \
        awk '{print $1}' | cut -d':' -f1 | sort -u)
    
    # Extract referenced secrets from all files
    local referenced_secrets
    referenced_secrets=$(grep -r '\${SECRET_' kubernetes/ 2>/dev/null | \
        grep -v Binary | \
        cut -d'$' -f2 | cut -d'{' -f2 | cut -d'}' -f1 | cut -d'/' -f1 | \
        sort -u)
    
    # Find missing secrets using comm
    local missing_secrets
    missing_secrets=$(comm -13 <(echo "$defined_secrets") <(echo "$referenced_secrets"))
    
    if [[ -n "$missing_secrets" ]]; then
        log warn "Found missing secrets:"
        echo "$missing_secrets" | while read -r secret; do
            log warn "Missing secret: $secret"
        done
        exit 1
    else
        log info "All referenced secrets are defined"
    fi
}

main "$@"
