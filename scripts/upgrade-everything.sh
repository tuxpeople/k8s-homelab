CONFIGFILE="${BASEDIR}/kubernetes/bootstrap/talos/talconfig.yaml"

[ -f ${CONFIGFILE} ] || exit 1

export controller=192.168.13.10
talosImageURL=$(grep talosImageURL ${BASEDIR}/kubernetes/bootstrap/talos/talconfig.yaml | awk '{ print $2 }' | head -1)
k8sVersion=$(grep kubernetesVersion ${BASEDIR}/kubernetes/bootstrap/talos/talconfig.yaml | awk '{ print $2 }')
talosVersion=$(grep talosVersion ${BASEDIR}/kubernetes/bootstrap/talos/talconfig.yaml | awk '{ print $2 }')
export image=${talosImageURL}:${talosVersion}
export to=${k8sVersion}
node_loop=$(kubectl get nodes -o wide --no-headers | grep -v $talosVersion |  awk '{ print $6 }' | tr '\n' ' ' | sed '$s/ $/\n/')

[ ! -z "$talosImageURL" ] || exit 1
[ ! -z "$k8sVersion" ] || exit 1
[ ! -z "$talosVersion" ] || exit 1

echo Updating Talos to ${talosVersion} if neccessary in 10s
sleep 10

for n in $node_loop
do
    node=$n task talos:upgrade
done

nodesWithOldReleaseShouldBe=0
nodesWithOldReleaseAre=$(kubectl get nodes -o wide --no-headers | grep -v ${talosVersion} | wc -l)

if [[ $nodesWithOldReleaseAre -ne $nodesWithOldReleaseShouldBe ]]
   then
       echo "Not all nodes have been upgraded. Exiting now"
       exit 1
fi

echo Updating Kubernetes to ${k8sVersion} if neccessary in 10s
sleep 10

nodesWithOldReleaseAre=$(kubectl get nodes -o wide --no-headers | grep -v ${k8sVersion} | wc -l)
if [[ $nodesWithOldReleaseAre -eq $nodesWithOldReleaseShouldBe ]]
   then
       echo "Not all nodes have been upgraded. Exiting now"
       exit 1
fi

task talos:upgrade-k8s
