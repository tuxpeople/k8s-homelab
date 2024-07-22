# Talos
## Upgrade Talos

```shell
LATEST_TALOS=`curl --silent -qI https://github.com/siderolabs/talos/releases/latest | awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}'`
for NODE in `kubectl get nodes -o wide --no-headers | grep -v ${LATEST_TALOS} | awk '{ print $1}'`
do
  node=${NODE} image=factory.talos.dev/installer/a28d86375cf9debe952efbcbe8e2886cf0a174b1f4dd733512600a40334977d7:${LATEST_TALOS} task talos:upgrade
  sleep 10
done
```
