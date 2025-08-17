#!/bin/bash

# Script to convert app-template applications to values.yaml + ConfigMap pattern
# Usage: ./convert-app-template.sh

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

# Function to check if app is app-template
is_app_template() {
    local helmrelease_file="$1"
    if [[ -f "$helmrelease_file" ]] && grep -q "chart: app-template" "$helmrelease_file"; then
        return 0
    fi
    return 1
}

# Function to check if app already has values.yaml
has_values_file() {
    local app_dir="$1"
    [[ -f "$app_dir/values.yaml" ]]
}

# Function to get app name from helmrelease
get_app_name() {
    local helmrelease_file="$1"
    # Extract app name from &app anchor or metadata.name
    local app_name
    app_name=$(yq eval '.metadata.name' "$helmrelease_file" 2>/dev/null || echo "")
    if [[ -z "$app_name" ]]; then
        app_name=$(basename "$(dirname "$helmrelease_file")")
    fi
    echo "$app_name"
}

# Function to get chart version
get_chart_version() {
    local helmrelease_file="$1"
    yq eval '.spec.chart.spec.version' "$helmrelease_file" 2>/dev/null || echo "3.7.3"
}

# Function to create values.yaml from helmrelease
create_values_file() {
    local helmrelease_file="$1"
    local values_file="$2"
    local chart_version="$3"
    
    log_info "Creating values.yaml for $(dirname "$values_file")"
    
    # Create values.yaml with schema header
    cat > "$values_file" << EOF
# yaml-language-server: \$schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template-${chart_version}/charts/other/app-template/values.schema.json

EOF
    
    # Extract values section and append to file
    if yq eval '.spec.values' "$helmrelease_file" >/dev/null 2>&1; then
        yq eval '.spec.values' "$helmrelease_file" >> "$values_file"
    else
        log_warning "No values section found in $helmrelease_file"
    fi
}

# Function to update kustomization.yaml
update_kustomization() {
    local kustomization_file="$1"
    local app_name="$2"
    
    log_info "Updating kustomization.yaml for $app_name"
    
    if [[ ! -f "$kustomization_file" ]]; then
        log_warning "No kustomization.yaml found, creating one"
        cat > "$kustomization_file" << EOF
---
# yaml-language-server: \$schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./helmrelease.yaml
EOF
    fi
    
    # Check if configMapGenerator already exists
    if ! yq eval '.configMapGenerator' "$kustomization_file" >/dev/null 2>&1; then
        # Add configMapGenerator section
        yq eval -i '.configMapGenerator = []' "$kustomization_file"
    fi
    
    # Add our configMap if it doesn't exist
    local configmap_exists
    configmap_exists=$(yq eval ".configMapGenerator[] | select(.name == \"${app_name}-values\") | length" "$kustomization_file" 2>/dev/null || echo "0")
    
    if [[ "$configmap_exists" == "0" ]]; then
        yq eval -i ".configMapGenerator += [{\"name\": \"${app_name}-values\", \"files\": [\"values.yaml\"]}]" "$kustomization_file"
    fi
    
    # Ensure generatorOptions.disableNameSuffixHash is true
    yq eval -i '.generatorOptions.disableNameSuffixHash = true' "$kustomization_file"
}

# Function to update helmrelease.yaml
update_helmrelease() {
    local helmrelease_file="$1"
    local app_name="$2"
    
    log_info "Updating helmrelease.yaml for $app_name"
    
    # Replace values with valuesFrom
    yq eval -i 'del(.spec.values)' "$helmrelease_file"
    yq eval -i ".spec.valuesFrom = [{\"kind\": \"ConfigMap\", \"name\": \"${app_name}-values\", \"valuesKey\": \"values.yaml\"}]" "$helmrelease_file"
}

# Function to convert a single app
convert_app() {
    local app_dir="$1"
    local helmrelease_file="$app_dir/helmrelease.yaml"
    local values_file="$app_dir/values.yaml"
    local kustomization_file="$app_dir/kustomization.yaml"
    
    # Skip if not app-template
    if ! is_app_template "$helmrelease_file"; then
        return 0
    fi
    
    # Skip if already has values.yaml
    if has_values_file "$app_dir"; then
        log_info "Skipping $app_dir - already has values.yaml"
        return 0
    fi
    
    local app_name
    app_name=$(get_app_name "$helmrelease_file")
    local chart_version
    chart_version=$(get_chart_version "$helmrelease_file")
    
    log_info "Converting app-template application: $app_name"
    log_info "  Directory: $app_dir"
    log_info "  Chart version: $chart_version"
    
    # Create values.yaml
    create_values_file "$helmrelease_file" "$values_file" "$chart_version"
    
    # Update kustomization.yaml
    update_kustomization "$kustomization_file" "$app_name"
    
    # Update helmrelease.yaml
    update_helmrelease "$helmrelease_file" "$app_name"
    
    log_success "Converted $app_name successfully"
}

# Main function
main() {
    log_info "Starting app-template conversion script"
    
    # Check if yq is available
    if ! command -v yq &> /dev/null; then
        log_error "yq is required but not installed. Please install yq first."
        exit 1
    fi
    
    # Find all app-template applications
    local converted=0
    local skipped=0
    
    log_info "Scanning for app-template applications..."
    
    # Find helmrelease files in app directories
    while IFS= read -r -d '' helmrelease_file; do
        app_dir=$(dirname "$helmrelease_file")
        
        if is_app_template "$helmrelease_file" && ! has_values_file "$app_dir"; then
            convert_app "$app_dir"
            ((converted++))
        else
            ((skipped++))
        fi
    done < <(find kubernetes/apps -name "helmrelease.yaml" -print0)
    
    # Also check some special cases (non-app directories)
    special_dirs=(
        "kubernetes/apps/network/external/cloudflared"
        "kubernetes/apps/network/external/openvpn"
        "kubernetes/apps/security/external-secrets/secretstores/onepassword"
    )
    
    for dir in "${special_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            helmrelease_file="$dir/helmrelease.yaml"
            if is_app_template "$helmrelease_file" && ! has_values_file "$dir"; then
                convert_app "$dir"
                ((converted++))
            else
                ((skipped++))
            fi
        fi
    done
    
    log_success "Conversion complete!"
    log_info "  Converted: $converted applications"
    log_info "  Skipped: $skipped applications (already converted or not app-template)"
    
    if [[ $converted -gt 0 ]]; then
        log_info ""
        log_info "Next steps:"
        log_info "1. Review the generated values.yaml files"
        log_info "2. Test with: kubectl apply --dry-run=client -k <app-directory>"
        log_info "3. Commit the changes"
        log_info "4. The new PR validation workflow will check schema compliance"
    fi
}

# Run main function
main "$@"