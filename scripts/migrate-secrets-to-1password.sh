#!/usr/bin/env bash

# migrate-secrets-to-1password.sh
# Migrates SOPS-encrypted secrets to 1Password vault
#
# Prerequisites:
# - 1Password CLI (op) installed and authenticated
# - sops CLI installed
# - yq installed
# - Age key available for SOPS decryption

set -euo pipefail

# Configuration
VAULT_NAME="${VAULT_NAME:-Homelab-Prod}"  # Can override with env var

# Set SOPS_AGE_KEY_FILE if not already set
if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
    if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
        export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
    elif [[ -f "age.key" ]]; then
        export SOPS_AGE_KEY_FILE="$(pwd)/age.key"
    else
        log_error "Age key not found. Set SOPS_AGE_KEY_FILE environment variable."
        exit 1
    fi
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v op &> /dev/null; then
        log_error "1Password CLI (op) not found. Install from: https://developer.1password.com/docs/cli"
        exit 1
    fi

    if ! command -v sops &> /dev/null; then
        log_error "sops not found"
        exit 1
    fi

    if ! command -v yq &> /dev/null; then
        log_error "yq not found"
        exit 1
    fi

    # Check if authenticated to 1Password
    if ! op vault list &> /dev/null; then
        log_error "Not authenticated to 1Password. Run: op signin"
        exit 1
    fi

    log_info "✓ All prerequisites met"
}

# Create vault if it doesn't exist
ensure_vault() {
    local vault_name="$1"

    if op vault get "$vault_name" &> /dev/null; then
        log_info "✓ Vault '$vault_name' already exists"
    else
        log_info "Creating vault '$vault_name'..."
        op vault create "$vault_name"
        log_info "✓ Vault '$vault_name' created"
    fi
}

# Migrate a single SOPS secret to 1Password
# Usage: migrate_secret <sops-file> <1password-item-name> <category>
migrate_secret() {
    local sops_file="$1"
    local item_name="$2"
    local category="${3:-password}"  # password, login, database, etc.

    log_info "Migrating: $sops_file → $item_name"

    # Decrypt SOPS file
    local decrypted
    if ! decrypted=$(sops -d "$sops_file" 2>&1); then
        log_error "Failed to decrypt $sops_file"
        log_error "$decrypted"
        return 1
    fi

    # Extract stringData fields
    local fields
    fields=$(echo "$decrypted" | yq eval '.stringData | to_entries | .[] | .key + "=" + .value' -)

    if [[ -z "$fields" ]]; then
        log_warn "No stringData found in $sops_file"
        return 1
    fi

    # Build op create command
    local op_cmd="op item create --vault=\"$VAULT_NAME\" --category=\"$category\" --title=\"$item_name\""

    # Add each field
    while IFS='=' read -r key value; do
        # Escape special characters in value
        value=$(echo "$value" | sed 's/"/\\"/g')
        op_cmd="$op_cmd \"$key[password]=$value\""
    done <<< "$fields"

    # Execute op command
    log_info "Creating 1Password item..."
    if eval "$op_cmd" &> /dev/null; then
        log_info "✓ Successfully migrated $item_name"
        echo "$sops_file" >> .migrated-secrets.log
        return 0
    else
        log_error "Failed to create 1Password item for $item_name"
        return 1
    fi
}

# Create ExternalSecret YAML
create_external_secret() {
    local namespace="$1"
    local secret_name="$2"
    local op_item_name="$3"
    local output_file="$4"

    cat > "$output_file" <<EOF
---
# yaml-language-server: \$schema=https://kubernetes-schemas.pages.dev/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: $secret_name
  namespace: $namespace
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: onepassword
  target:
    name: $secret_name
    template:
      engineVersion: v2
  dataFrom:
    - extract:
        key: $op_item_name
EOF

    log_info "✓ Created ExternalSecret: $output_file"
}

# Main migration function
main() {
    log_info "Starting SOPS to 1Password migration"
    log_info "Target vault: $VAULT_NAME"
    echo

    check_prerequisites
    ensure_vault "$VAULT_NAME"

    echo
    log_info "Ready to migrate secrets. Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_warn "Migration cancelled"
        exit 0
    fi

    # Migration targets
    declare -A SECRETS=(
        # Format: ["sops-file"]="1password-item-name|category|namespace"
        ["kubernetes/apps/observability/grafana/app/secret.sops.yaml"]="grafana-admin|password|observability"
        ["kubernetes/apps/productivity/paperless/app/secret-passwords.sops.yaml"]="paperless-passwords|password|productivity"
        ["kubernetes/apps/productivity/paperless/app/secret-values.sops.yaml"]="paperless-secret-values|password|productivity"
        ["kubernetes/apps/productivity/webtrees/app/secret.sops.yaml"]="webtrees-admin|password|productivity"
        ["kubernetes/apps/productivity/webtrees/db/secret.sops.yaml"]="webtrees-mariadb|database|productivity"
        ["kubernetes/apps/default/gitlab-runner/app/secret.sops.yaml"]="gitlab-runner|password|default"
        ["kubernetes/apps/default/gitlab-runner2/app/secret.sops.yaml"]="gitlab-runner2|password|default"
        ["kubernetes/apps/tools/headscale/app/secrets.sops.yaml"]="headscale|password|tools"
    )

    local success_count=0
    local fail_count=0

    for sops_file in "${!SECRETS[@]}"; do
        if [[ ! -f "$sops_file" ]]; then
            log_warn "File not found: $sops_file (skipping)"
            continue
        fi

        IFS='|' read -r item_name category namespace <<< "${SECRETS[$sops_file]}"

        echo
        log_info "========================================="
        log_info "Processing: $item_name"
        log_info "========================================="

        if migrate_secret "$sops_file" "$item_name" "$category"; then
            ((success_count++))

            # Create ExternalSecret
            local dir=$(dirname "$sops_file")
            local externalsecret_file="$dir/externalsecret.yaml"
            local secret_name=$(basename "$sops_file" .sops.yaml)

            create_external_secret "$namespace" "$secret_name" "$item_name" "$externalsecret_file"

            log_info "✓ Migration complete for $item_name"
        else
            ((fail_count++))
            log_error "✗ Migration failed for $item_name"
        fi
    done

    echo
    log_info "========================================="
    log_info "Migration Summary"
    log_info "========================================="
    log_info "Success: $success_count"
    log_info "Failed: $fail_count"

    if [[ -f .migrated-secrets.log ]]; then
        echo
        log_info "Migrated files logged to: .migrated-secrets.log"
        log_warn "Remember to:"
        log_warn "1. Test the ExternalSecrets in your cluster"
        log_warn "2. Remove SOPS files after verification: git rm <file>"
        log_warn "3. Update .sops.yaml if needed"
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
