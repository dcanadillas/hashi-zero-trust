#!/bin/bash

export VAULT_KNS="vault"
export CONSUL_KNS="consul"
export WAYPOINT_KNS="waypoint"

echo -e "\nYou are using Kubernetes context: \"$(kubectl config current-context)\"\n"
kubectl cluster-info
kubectl get ns

echo -e "\nWe are going to delete  Vault, Consul and Waypoint deployments in the following namespaces: $VAULT_KNS, $CONSUL_KNS, $WAYPOINT_KNS\n"
read -p "Are you sure? (Ctrl-C to Cancel)..."

echo -e "\nDeleting any previous Consul CRDs first in \"apps\" namespace..."
# kubectl delete -f ./consul-crds/ -n apps
# Order is important to avoid Kubernetes objects termination loops
kubectl delete serviceintentions -n apps --all
kubectl delete ingressgateways -n apps --all
kubectl delete servicedefaults -n apps --all

echo -e "\nUninstalling Vault...\n"
helm uninstall vault -n $VAULT_KNS
kubectl delete pvc -n $VAULT_KNS --all

echo -e "\nUninstalling Consul...\n"
helm uninstall consul -n $CONSUL_KNS
kubectl delete pvc -n $CONSUL_KNS --all

echo -e "\nUninstalling Waypoint...\n"
helm uninstall waypoint -n $WAYPOINT_KNS
kubectl delete pvc -n $WAYPOINT_KNS --all

echo -e "\nDeleting namespaces...\n"
kubectl delete ns apps $VAULT_KNS $CONSUL_KNS $WAYPOINT_KNS

echo -e "\nDeleting \"context-zerotrust\" Waypoint context...\n"
waypoint context delete context-zerotrust
