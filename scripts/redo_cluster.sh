task talos:reset
task talos:reset
sleep 300
bash -c "cd /Volumes/development/github/tuxpeople/k8s-homelab; export KUBECONFIG=$(pwd)/kubeconfig; task bootstrap:talos"
sleep 60
bash -c "cd /Volumes/development/github/tuxpeople/k8s-homelab; export KUBECONFIG=$(pwd)/kubeconfig; task bootstrap:apps"
