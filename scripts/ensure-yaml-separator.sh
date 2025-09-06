#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${0}")/lib/common.sh"

function ensure_yaml_separators() {
    local target_dir="${1:-kubernetes}"

    check_cli find head gsed

    log info "Ensuring YAML separators in directory: $target_dir"

    local files_modified=0

    find "$target_dir" -type f -name '*.yaml' | while read -r file; do
        local first_line
        first_line=$(head -n 1 "$file" 2>/dev/null || true)

        if [[ "$first_line" != "---"* ]]; then
            if gsed -i '1i ---' "$file"; then
                log debug "Added YAML separator" "file=$file"
                ((files_modified++))
            else
                log warn "Failed to modify file" "file=$file"
            fi
        fi
    done

    log info "YAML separator check completed" "files_modified=$files_modified"
}

function main() {
    local target_dir="${1:-kubernetes}"
    ensure_yaml_separators "$target_dir"
}

main "$@"
