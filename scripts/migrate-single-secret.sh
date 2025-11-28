#!/usr/bin/env bash

# migrate-single-secret.sh
# Interactive script to migrate a single SOPS secret to 1Password
#
# Usage: ./migrate-single-secret.sh <sops-file> <1password-item-name> [vault-name]
#
# Example:
#   ./migrate-single-secret.sh kubernetes/apps/observability/grafana/app/secret.sops.yaml grafana-admin Homelab-Prod

set -euo pipefail

# Set SOPS_AGE_KEY_FILE if not already set
if [[ -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
    if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
        export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
    elif [[ -f "age.key" ]]; then
        export SOPS_AGE_KEY_FILE="$(pwd)/age.key"
    else
        echo "Error: Age key not found. Set SOPS_AGE_KEY_FILE environment variable."
        exit 1
    fi
fi

SOPS_FILE="${1:-}"
ITEM_NAME="${2:-}"
VAULT_NAME="${3:-Homelab-Prod}"

if [[ -z "$SOPS_FILE" ]] || [[ -z "$ITEM_NAME" ]]; then
    echo "Usage: $0 <sops-file> <1password-item-name> [vault-name]"
    echo
    echo "Example:"
    echo "  $0 kubernetes/apps/observability/grafana/app/secret.sops.yaml grafana-admin Homelab-Prod"
    exit 1
fi

if [[ ! -f "$SOPS_FILE" ]]; then
    echo "Error: File not found: $SOPS_FILE"
    exit 1
fi

echo "==================================="
echo "SOPS to 1Password Migration"
echo "==================================="
echo "SOPS file:  $SOPS_FILE"
echo "Item name:  $ITEM_NAME"
echo "Vault:      $VAULT_NAME"
echo

# Step 1: Decrypt SOPS file
echo "Step 1: Decrypting SOPS file..."
DECRYPTED=$(sops -d "$SOPS_FILE")

# Step 2: Extract fields
echo "Step 2: Extracting secret fields..."
echo "$DECRYPTED" | yq eval '.stringData' -

echo
echo "Step 3: Creating 1Password item..."
echo "Fields to migrate:"
echo "$DECRYPTED" | yq eval '.stringData | to_entries | .[] | "  - " + .key' -

echo
read -p "Continue with migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled"
    exit 0
fi

# Step 4: Create 1Password item with all fields
echo "Creating item in 1Password..."

# Extract each field and add to op command
FIELDS=$(echo "$DECRYPTED" | yq eval '.stringData | to_entries | .[] | .key + "|||" + .value' -)

# Build op item create command
OP_CMD="op item create --vault=\"$VAULT_NAME\" --category=password --title=\"$ITEM_NAME\""

while IFS='|||' read -r key value; do
    OP_CMD="$OP_CMD \"$key[password]=$value\""
done <<< "$FIELDS"

# Execute
if eval "$OP_CMD"; then
    echo "✓ Successfully created 1Password item: $ITEM_NAME"
    echo
    echo "Next steps:"
    echo "1. Create ExternalSecret YAML"
    echo "2. Test in cluster"
    echo "3. Remove SOPS file after verification"
else
    echo "✗ Failed to create 1Password item"
    exit 1
fi
