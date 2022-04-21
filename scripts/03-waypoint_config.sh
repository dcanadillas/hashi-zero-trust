#!/bin/bash
export VAULT_NS=vault
# export VAULT_TOKEN=root
export VAULT_TOKEN=$(kubectl get secret vault-init-log -n $VAULT_NS -o jsonpath={.data.root_token} | base64 -d)

waypoint context delete context-zerotrust

WAYPOINT_TOKEN="$(kubectl get secret waypoint-server-token -n waypoint -o jsonpath={.data.token} | base64 -d)"
WAYPOINT_IP="$(kubectl get po -l app.kubernetes.io/instance=waypoint -l component=server -n waypoint -o jsonpath={.items[0].status.hostIP})"
WAYPOINT_LBIP="$(kubectl get svc -n waypoint waypoint-ui -o jsonpath='{.status.loadBalancer.ingress[*].ip}')"
# The following IP get is considering we are working with a One Node cluster!!
# WAYPOINT_IP="$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')"
WAYPOINT_NODEPORT="$(kubectl get svc -n waypoint waypoint-ui -o jsonpath='{.spec.ports[?(@.name=="grpc")].nodePort}')"
WAYPOINT_LBPORT="$(kubectl get svc -n waypoint waypoint-ui -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')"
waypoint context create -server-addr $WAYPOINT_LBIP:$WAYPOINT_LBPORT \
-server-auth-token "$WAYPOINT_TOKEN" \
-server-require-auth=true \
-server-tls=true \
-server-tls-skip-verify=true \
context-zerotrust

echo -e "Using context \"context-zerotrust\" created\n"

waypoint context use context-zerotrust

waypoint context verify

echo -e "===> Initializing project...\n"



waypoint config source-set \
-type=vault \
-config="addr=http://vault.vault:8200" \
-config="auth_method=kubernetes" \
-config="auth_method_mount_path=auth/kubernetes" \
-config="kubernetes_role=waypoint" \
-config="skip_verify=true" \
-config="namespace=root"

echo -e "\n ===> Creating a token to login into the UI: \n"
echo -e "\t Token: $(waypoint user token) \n"


# waypoint config source-set \
# -type=vault \
# -config="addr=http://vault.vault:8200" \
# # -config="token=$VAULT_TOKEN" \
# -config="skip_verify=true" \
# -config="namespace=root" \
# -config="auth_method=kubernetes" \
# -config="kubernetes_role=waypoint"