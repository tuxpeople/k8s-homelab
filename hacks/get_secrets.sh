#!/bin/bash
for SECRET in $(kubectl get sealedsecrets.bitnami.com -A | grep -v NAME |  awk '{ print $1"|"$2}')
do
    NAMESPACE=$(echo ${SECRET} | cut -d'|' -f1)
    NAME=$(echo ${SECRET} | cut -d'|' -f2)
    kubectl get secret -n $NAMESPACE $NAME -o yaml | ksd | kubectl neat -o yaml> secrets/$NAMESPACE-$NAME.yaml
done
