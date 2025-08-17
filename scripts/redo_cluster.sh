#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

# Ensure we're in the right directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# Set KUBECONFIG for all operations
export KUBECONFIG="$REPO_ROOT/kubeconfig"

log "Starting cluster reset and redeploy..."

log "Step 1: Resetting Talos cluster (first attempt)"
if ! task talos:reset; then
    warn "First reset failed, trying second reset"
    if ! task talos:reset; then
        error "Both reset attempts failed"
    fi
fi

log "Step 2: Waiting 5 minutes for nodes to fully reset"
sleep 300

log "Step 3: Bootstrapping Talos cluster"
if ! task bootstrap:talos; then
    error "Talos bootstrap failed"
fi

log "Step 4: Waiting 1 minute for cluster to stabilize"
sleep 60

log "Step 5: Verifying cluster is ready"
timeout=300
counter=0
while ! kubectl get nodes &>/dev/null; do
    if [ $counter -ge $timeout ]; then
        error "Cluster not ready after $timeout seconds"
    fi
    log "Waiting for cluster to be accessible... ($counter/$timeout)"
    sleep 10
    counter=$((counter + 10))
done

log "Step 6: Bootstrapping applications"
if ! task bootstrap:apps; then
    error "App bootstrap failed"
fi

log "Step 7: Waiting for critical components"
log "Waiting for Flux to be ready..."
kubectl wait --for=condition=Ready pods -l app=source-controller -n flux-system --timeout=300s
kubectl wait --for=condition=Ready pods -l app=kustomize-controller -n flux-system --timeout=300s

log "✅ Cluster redeploy completed successfully!"
log "🔍 Checking cluster status:"
kubectl get nodes
kubectl get pods -n flux-system
