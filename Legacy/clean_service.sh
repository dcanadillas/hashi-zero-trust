#!/bin/bash

export NS=$2
export SERVICE_NAME=$1

K8S_SERVICE="$(kubectl get svc -n $NS \
  -o go-template="{{ range .items}}{{ if eq .metadata.name \"$SERVICE_NAME\"}}{{.metadata.name}}{{end}}{{end}}")"

if [ -z "$K8S_SERVICE" ];then
  echo  "There is no service \"$SERVICE_NAME\". Doing nothing..."
  echo "$K8S_SERVICE"
  exit 0
else
  
  echo "Service \"$K8S_SERVICE\" already exists in namespace \"apps\". Deleting first..."
  kubectl delete svc/$K8S_SERVICE -n $NS
fi