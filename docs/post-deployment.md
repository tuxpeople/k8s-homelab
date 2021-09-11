# Things to do after the initial deployment

## Update webhook address for fluxcdbot:

1. Open Telegram
2. Send /start to the bot to get the webhook-url
3. Perform following while using the webhook-url from above:

```shell
WEBHOOKURL="http://fluxcdbot.flux-system.svc.cluster.local:8080/api/v1/webhook/XXXXXXXXXXXXXXX/YYYYYYYYYYYYYYYYYYYYYYYYY"
CERTIFICATE="./cluster/certificate.pem"
OUTPUTFILE="./cluster/base/flux-system/notifications/telegram-address.yaml"
cd ~/git/k8s-homelab
echo "---" > ${OUTPUTFILE}
kubectl -n flux-system create secret generic telegram-address --from-literal=address=${WEBHOOKURL} --dry-run=client -o yaml | kubeseal --cert ${CERTIFICATE} -o yaml >> ${OUTPUTFILE}
git commit -m "Update webhook-url" ${OUTPUTFILE}
git push
```
        Note: XXXXXXXX and YYYYYYY from above are also reflected in the `fluxcdbot` PV folder structure

## Configure `code-server`

1.) Drop ssh key in to `/config/.ssh`

2.) Then open a terminal from the top menu and set github username and email via the following commands:
```
git config --global user.name "username"
git config --global user.email "email address"
```
3.) Clone git repos into `/config/workspace/` if needed

## Configure `wallabag`

Default login is `wallabag:wallabag`. Change credentials.

## Configure `paperless`

Log into paperless container and run `gosu paperless python3 manage.py createsuperuser` to create user.

## Default credentials for `mealie`
As descreibed [here](https://hay-kot.github.io/mealie/documentation/admin/user-management/), the default username and password are `changeme@email.com` and `MyPassword`.

## Configure `gaps`

Either restore pvc content, or do the following:

1. Go to `Settings` -> `TMDB` and enter the API key (v3 auth) -> `save`.
2. Go to `Settings` -> `Plex` and enter the Plex IP Address `192.168.8.80` and the Plex Token -> `add`.


## Get token of SA for kubernetes dashboard

`kubectl -n networking get secret $(kubectl -n networking get sa/kubernetes-dashboard-admin -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"`