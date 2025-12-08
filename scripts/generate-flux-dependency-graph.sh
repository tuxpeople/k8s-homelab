#!/usr/bin/env bash
# shellcheck disable=SC2312

# Generate Mermaid dependency graph for Flux Kustomizations
# This script parses all ks.yaml files and creates a visual dependency graph

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPS_DIR="${REPO_ROOT}/kubernetes/apps"
OUTPUT_FILE="${REPO_ROOT}/docs/flux-dependency-graph.md"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Generating Flux Kustomization dependency graph...${NC}"

# Ensure docs directory exists
mkdir -p "${REPO_ROOT}/docs"

# Start building the markdown file
cat >"${OUTPUT_FILE}" <<'EOF'
# Flux Kustomization Dependency Graph

This document visualizes the dependencies between Flux Kustomizations in the cluster.

**Last Updated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Dependency Graph

```mermaid
flowchart LR
EOF

# Find all ks.yaml files and parse them
declare -A nodes
declare -A edges

while IFS= read -r ks_file; do
    # Parse the YAML file to extract name and dependencies
    # Get the Kustomization name(s) from the file
    kustomization_names=$(yq eval '.metadata.name' "${ks_file}" 2>/dev/null | grep -v "^null$" | grep -v "^---$" || true)

    # Skip if no kustomization names found
    [[ -z "${kustomization_names}" ]] && continue

    # Process each kustomization in the file (some files have multiple)
    while IFS= read -r kust_name; do
        # Skip empty or null values
        [[ -z "${kust_name}" || "${kust_name}" == "null" ]] && continue

        # Get namespace for this specific kustomization
        kust_namespace=$(yq eval "select(.metadata.name == \"${kust_name}\") | .metadata.namespace" "${ks_file}" 2>/dev/null | head -1)

        # Create node ID
        node_id="${kust_namespace}/${kust_name}"
        nodes["${node_id}"]="${kust_namespace}"

        # Extract dependencies for this kustomization
        deps=$(yq eval "select(.metadata.name == \"${kust_name}\") | .spec.dependsOn[].name" "${ks_file}" 2>/dev/null || true)
        dep_namespaces=$(yq eval "select(.metadata.name == \"${kust_name}\") | .spec.dependsOn[].namespace" "${ks_file}" 2>/dev/null || true)

        # Process dependencies
        if [[ -n "${deps}" ]]; then
            # Convert to arrays
            mapfile -t dep_array <<< "${deps}"
            mapfile -t dep_ns_array <<< "${dep_namespaces}"

            # Create edges for each dependency
            for i in "${!dep_array[@]}"; do
                dep_name="${dep_array[$i]}"
                dep_ns="${dep_ns_array[$i]}"
                dep_node_id="${dep_ns}/${dep_name}"

                # Store edge
                edge_key="${dep_node_id}::${node_id}"
                edges["${edge_key}"]=1
            done
        fi
    done <<< "${kustomization_names}"
done < <(find "${APPS_DIR}" -name "ks.yaml" -type f | sort)

# Collect nodes that are actually used in dependencies
declare -A used_nodes
for edge_key in "${!edges[@]}"; do
    source="${edge_key%%::*}"
    target="${edge_key##*::}"

    # Only track nodes that exist and are connected
    if [[ -n "${nodes[${source}]:-}" && -n "${nodes[${target}]:-}" ]]; then
        used_nodes["${source}"]=1
        used_nodes["${target}"]=1
    fi
done

# Write only nodes that have dependencies
echo -e "\n    %% Node definitions" >>"${OUTPUT_FILE}"
for node_id in $(echo "${!used_nodes[@]}" | tr ' ' '\n' | sort); do
    # Escape node ID by replacing / and - with _
    node_id_escaped="${node_id//\//_}"
    node_id_escaped="${node_id_escaped//-/_}"
    echo "    ${node_id_escaped}[\"${node_id}\"]" >>"${OUTPUT_FILE}"
done
echo "" >>"${OUTPUT_FILE}"

# Generate edges
echo "    %% Dependencies" >>"${OUTPUT_FILE}"
for edge_key in "${!edges[@]}"; do
    source="${edge_key%%::*}"
    target="${edge_key##*::}"

    # Only create edge if both source and target nodes exist
    if [[ -n "${nodes[${source}]:-}" && -n "${nodes[${target}]:-}" ]]; then
        # Escape source and target IDs
        source_escaped="${source//\//_}"
        source_escaped="${source_escaped//-/_}"
        target_escaped="${target//\//_}"
        target_escaped="${target_escaped//-/_}"
        echo "    ${source_escaped} --> ${target_escaped}" >>"${OUTPUT_FILE}"
    fi
done

# Close mermaid block
cat >>"${OUTPUT_FILE}" <<'EOF'
```

## Legend

- **Nodes**: Flux Kustomizations (labeled with namespace/name)
- **Arrows**: Dependency relationships (A --> B means B depends on A)

## Statistics

EOF

# Generate statistics
total_kustomizations=${#nodes[@]}
connected_kustomizations=${#used_nodes[@]}
total_dependencies=${#edges[@]}

cat >>"${OUTPUT_FILE}" <<EOF
- **Total Kustomizations**: ${total_kustomizations}
- **Kustomizations with Dependencies**: ${connected_kustomizations}
- **Total Dependencies**: ${total_dependencies}

## Common Dependency Targets

The most common dependencies across all Kustomizations:

EOF

# Count how many Kustomizations depend on each target
declare -A dep_counts
for edge_key in "${!edges[@]}"; do
    source="${edge_key%%::*}"
    target="${edge_key##*::}"

    # Only count if both source and target nodes exist
    if [[ -n "${nodes[${source}]:-}" && -n "${nodes[${target}]:-}" ]]; then
        dep_target="${edge_key%%::*}"
        if [[ -n "${dep_counts[${dep_target}]:-}" ]]; then
            ((dep_counts["${dep_target}"]++))
        else
            dep_counts["${dep_target}"]=1
        fi
    fi
done

# Sort and display top dependencies
echo "| Dependency | Dependent Count |" >>"${OUTPUT_FILE}"
echo "|------------|-----------------|" >>"${OUTPUT_FILE}"
if [[ ${#dep_counts[@]} -gt 0 ]]; then
    for dep in "${!dep_counts[@]}"; do
        echo "${dep} ${dep_counts[${dep}]}"
    done | sort -k2 -rn | head -10 | while read -r dep count; do
        dep_name="${dep#*/}"
        echo "| \`${dep}\` | ${count} |" >>"${OUTPUT_FILE}"
    done
else
    echo "| N/A | 0 |" >>"${OUTPUT_FILE}"
fi

cat >>"${OUTPUT_FILE}" <<'EOF'

---

*This graph is automatically generated by `scripts/generate-flux-dependency-graph.sh`*

*To regenerate: `./scripts/generate-flux-dependency-graph.sh`*
EOF

echo -e "${GREEN}✓ Dependency graph generated successfully!${NC}"
echo -e "${GREEN}  Output: ${OUTPUT_FILE}${NC}"
echo -e "${BLUE}  Total Kustomizations: ${total_kustomizations}${NC}"
echo -e "${BLUE}  Total Dependencies: ${total_dependencies}${NC}"
