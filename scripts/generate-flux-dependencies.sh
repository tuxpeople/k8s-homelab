#!/usr/bin/env bash

# Flux Dependencies Generator
# Generates DOT and PNG visualizations of Flux Kustomization dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCS_DIR="${REPO_ROOT}/docs"
PYTHON_SCRIPT="${SCRIPT_DIR}/generate-flux-dot.py"

DOT_FILE="${DOCS_DIR}/flux-dependencies.dot"
PNG_FILE="${DOCS_DIR}/flux-dependencies.png"

echo "🔍 Generating Flux Kustomization dependency graph..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if Python script exists
if [[ ! -f "${PYTHON_SCRIPT}" ]]; then
    echo "❌ Error: Python script not found at ${PYTHON_SCRIPT}"
    exit 1
fi

# Check cluster access
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Cannot connect to Kubernetes cluster"
    echo "   Make sure your kubeconfig is configured correctly"
    exit 1
fi

# Generate DOT file
echo "📝 Generating DOT file..."
if kubectl get kustomizations.kustomize.toolkit.fluxcd.io -A -o yaml | python3 "${PYTHON_SCRIPT}" > "${DOT_FILE}"; then
    echo "✅ DOT file generated: ${DOT_FILE}"
else
    echo "❌ Error: Failed to generate DOT file"
    exit 1
fi

# Generate PNG from DOT
if command -v dot &> /dev/null; then
    echo "🎨 Generating PNG visualization..."
    if dot -Tpng "${DOT_FILE}" -o "${PNG_FILE}"; then
        echo "✅ PNG file generated: ${PNG_FILE}"

        # Show file sizes
        DOT_SIZE=$(ls -lh "${DOT_FILE}" | awk '{print $5}')
        PNG_SIZE=$(ls -lh "${PNG_FILE}" | awk '{print $5}')
        echo ""
        echo "📊 Generated files:"
        echo "   - ${DOT_FILE} (${DOT_SIZE})"
        echo "   - ${PNG_FILE} (${PNG_SIZE})"
    else
        echo "❌ Error: Failed to generate PNG file"
        exit 1
    fi
else
    echo "⚠️  Warning: Graphviz 'dot' command not found"
    echo "   DOT file generated, but PNG could not be created"
    echo "   Install Graphviz to enable PNG generation:"
    echo "     - macOS: brew install graphviz"
    echo "     - Linux: apt-get install graphviz"
    echo "   Or use online converter: https://dreampuf.github.io/GraphvizOnline/"
    echo ""
    echo "📊 Generated files:"
    echo "   - ${DOT_FILE}"
fi

echo ""
echo "✨ Done!"
