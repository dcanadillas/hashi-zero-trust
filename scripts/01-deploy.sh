#!/bin/bash

# You can change these values if you want to customize your namespaces
export CONSUL_NS="consul"
export VAULT_NS="vault"
export WAYPOINT_NS="waypoint"
export VAULT_KEYS_FILE="vault_keys-$(date +%s)"
# SCRIPTPATH="$(dirname "$(realpath "$0")")"
SCRIPTPATH="$(cd $(dirname $0); pwd)"
# VAULT_VALUES="../hashicorp_values/vault-values-persistent.yaml"
# CONSUL_VALUES="../hashicorp_values/consul-values.yaml"
# WAYPOINT_VALUES="../hashicorp_values/waypoint-values.yaml"
if [ -z $MINIKUBE_PROFILE ];then
  export MINIKUBE_PROFILE="hashikube"
fi

if [ -z "$1" ];then
  VAULT_VALUES="../hashicorp_values/vault-values-persistent.yaml"
else
  VAULT_VALUES="$1"
fi


if [ -z "$2" ];then
  CONSUL_VALUES="../hashicorp_values/consul-values.yaml"
else
  CONSUL_VALUES="$2"
fi

if [ -z "$3" ];then
  WAYPOINT_VALUES="../hashicorp_values/waypoint-values.yaml"
else
  WAYPOINT_VALUES="$3"
fi


if hash kubectl;then
  echo -e "Your cluster connected is: \n"
  kubectl cluster-info
else
  echo "Please install kubectl to connect to to your cluster..."
  exit 1
fi

read -p "Continue? ..."

# A function to check if the Helm package is installed on the namespace
helm_not_installed () {
  HELMAPP="$(helm list -n $2 -o json | jq --arg NAME $1 -r '.[] | select( .name == $NAME ) | .name')"
  # echo $HELMAPP
  if [ "$HELMAPP" == "$1" ];then
    echo -e "\nHelm chart $1 already installed in namespace $2...\n"
    # Returning an Exit 1 code error it the chart is already installed
    return 1
  else
    # Returning a 0 valid code if the helm is not installed
    echo -e "\nHelm \"$1\" not installed yet...\n"
    return 0
  fi
}

# A function to check that Vault pods are running but not ready
vault_running () {
  # Let's create a code to check Vault running container statuses with a timeout of ~120s
  sleep 2
  if [[ -z $(kubectl get po -n $VAULT_NS -l component=server -o json | jq -r '.items[].metadata.name') ]];then
    echo -e "\nThere are no Vault pods..."
    exit 1
  fi

  counter=0
  while true
  do 
    counter=$((counter+1))
    echo "Waiting for pods running:  ${counter}s"
    if [ $counter -gt 120 ];then
      echo -e "\nTimeout to wait for Vault running pods. Check the logs...\n"
      break
    fi
    # We search for all "Running "
    kubectl get po -n vault -l component=server -o json | jq -r '.items[].status.phase' | grep -qv Running
    if (($? == 1));then 
      echo  -e "\nAll Vault pods are in \"Running\" state\n"
      break
    fi
    sleep 1
  done
}

# A function to unseal Vault based on the Unseal Key stored in a K8s secret "vault-init-log"
unseal_vault () {
  echo -e "\nUnsealing Vault from the Unseal Key in \"vault-init-log\" secret ====> \n"
  local VAULT_PODS=($(kubectl get po -n $VAULT_NS -l component=server -o json | jq -r '.items[].metadata.name'))
  local UNSEAL_KEY=$(kubectl get secret vault-init-log -n $VAULT_NS -o jsonpath={.data.unseal_key} | base64 -d)
  for i in ${VAULT_PODS[@]};do
    kubectl exec $i -n $VAULT_NS -- vault operator unseal $UNSEAL_KEY
    sleep 20
  done
}


# A function to install Vault using Helm and initializing it (Root Token and Unseal Key stored in "vault-init-log" secret)
install_vault () {
  kubectl apply -f - <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $VAULT_NS
EOF

  echo -e "\nInstalling Vault with Helm ====> \n"

  helm install vault -n $VAULT_NS -f $VAULT_VALUES hashicorp/vault

  sleep 2

  kubectl wait --for=condition=initialized po -l app.kubernetes.io/name=vault -n $VAULT_NS

  # Checking that Vault containers pods are in Running state (Ready state is not valid because it will be Ready when Vault is initialized)
  vault_running

  # We are saving the init Recovery Keys and Root Token in a variable that we can use (Only for development reasons!!)
  INITIALIZED="$(kubectl exec -ti vault-0 -n $VAULT_NS -- sh -c "vault status -format=json" | jq .initialized)"
  if [ "$INITIALIZED" == "true" ];then
    echo -e "\nVault is already initialized\n"
  else
    echo -e "\nInitializing Vault..."
    kubectl exec -ti vault-0 -n $VAULT_NS -- vault operator init -format json -key-shares 1 -key-threshold 1 > /tmp/$VAULT_KEYS_FILE
    # export MYVAULT_INIT=($(kubectl exec vault-0 -n $VAULT_NS -ti -- vault operator init -format json -key-shares 1 -key-threshold 1 | jq -r '.root_token + " " + .unseal_keys_b64[0]'))
    export MYVAULT_INIT=($(jq -r '.root_token + " " + .unseal_keys_b64[0]' /tmp/$VAULT_KEYS_FILE))
  fi
  
  echo "Unsealing values: ${MYVAULT_INIT[@]}"

  # Let's put the keys and root token in a file. But this should be deleted because we are creating a K8s secret
  cat - << EOF > /tmp/vault-init-$(date +%s).log
recovery_keys: $(echo ${MYVAULT_INIT[0]})
root_token: $(echo ${MYVAULT_INIT[1]})
EOF

  # Creating a Kubernetes secret in Vault namespace with the Root Token and Recovery keys (again... only for dev reasons)
  # kubectl create secret generic -n $VAULT_KNS vault-init-log \
  #   --from-literal="root_token=$(echo ${MYVAULT_INIT[0]})" \
  #   --from-literal="recovery_keys=$(${MYVAULT_INIT[1]})"

  # Let's use a Kubernetes manifest, so it updates the secret if exists

  echo -e "\nKubernetes secret with Root Token and Unseal Key ====> \n"
  kubectl apply -f - << EOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-init-log
  namespace: $VAULT_NS
type: Opaque
data:
  root_token: $(echo ${MYVAULT_INIT[0]} | base64)
  unseal_key: $(echo ${MYVAULT_INIT[1]} | base64)
EOF
  # if [ "$1" == "Minikube" ];then
  #   VAULT_HOST="$(minikube -ip -p $MINIKUBE_PROFILE)"
  #   VAULT_PORT=$VAULT_NODEPORT
  # else
  #   VAULT_HOST="$(kubectl get svc/vault-ui -n vault -o jsonpath={.status.loadBalancer.ingress[].ip})"
  #   VAULT_PORT=$VAULT_LBPORT
  # fi
    
  # echo -e "\nVault should be reachable at http://$VAULT_HOST:$VAULT_PORT\n"
  # echo -e "\nexport VAULT_ADDR=\"http://$VAULT_HOST:$VAULT_PORT\"\n"
  # export VAULT_ADDR="http://$VAULT_HOST:$VAULT_PORT"
}

# A function to install Consul with Helm
install_consul () {
  echo -e "\nInstalling consul using consul values provided ====> \n"
# kubectl create ns $CONSUL_NS
  kubectl apply -f - <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $CONSUL_NS
EOF

  # Installing API Gateways CRDs
  kubectl apply --kustomize="github.com/hashicorp/consul-api-gateway/config/crd?ref=v0.1.0"

  kubectl create secret generic consul-acl-bootstrap-token --from-literal="token=C0nsulR0cks" -n $CONSUL_NS
  helm install consul -f $CONSUL_VALUES -n $CONSUL_NS hashicorp/consul
}

# A function to install Waypoint
install_waypoint () {
  echo -e "\nInstalling Waypoint with Helm ====> \n"
# kubectl create ns $WAYPOINT_NS
  kubectl apply -f - <<-EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $WAYPOINT_NS
EOF
  helm install waypoint -n $WAYPOINT_NS -f $WAYPOINT_VALUES hashicorp/waypoint
  sleep 5
  echo "... Let's wait to bootstrap Waypoint..."
  kubectl wait --for=condition=complete --timeout=60s job -n $WAYPOINT_NS --all
}

echo -e "\nAdding HashiCorp Helm repos ====> \n"
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update



# echo -e "\nInstalling Vault in development mode ====> \n"
# #kubectl create ns $VAULT_NS
# kubectl apply -f - <<-EOF
# apiVersion: v1
# kind: Namespace
# metadata:
#   name: $VAULT_NS
# EOF
# helm install vault -n $VAULT_NS --set server.dev.enabled=true hashicorp/vault 

# Install Vault
if helm_not_installed vault $VAULT_NS;then
  install_vault
  # Follwing line is only to check for a development Vault (so only check in the first vault-0 pod)
  echo -e "\nVault installed. Let's unseal Vault..."
  SEALED="$(kubectl exec vault-0 -n $VAULT_NS -- vault status -format json | jq -r .sealed)"
  if [ "$SEALED" == "false" ];then
    echo -e "\nVault is already unsealed\n"
  else
    unseal_vault
  fi
  
else
  echo -e "\n...Vault Helm chart is alreay installed...\n"
  echo -e "Consider on doing a manual upgrade with: \n"
  echo -e "\thelm upgrade vault -n $VAULT_NS -f $VAULT_VALUES hashicorp/vault\n"
fi

# Install Consul
if helm_not_installed consul $CONSUL_NS;then
  install_consul
else
  echo -e "\n...Consul Helm chart is alreay installed...\n"
  echo -e "Consider on doing a manual upgrade with: \n"
  echo -e "\thelm upgrade consul -n $CONSUL_NS -f $CONSUL_VALUES hashicorp/waypoint\n"
fi

# Install Waypoint
if helm_not_installed waypoint $WAYPOINT_NS;then
  install_waypoint
else
  echo -e "\n...Waypoint Helm chart is alreay installed...\n"
  echo -e "Consider on doing a manual upgrade with: \n"
  echo -e "\thelm upgrade waypoint -n $WAYPOINT_NS -f $WAYPOINT_VALUES hashicorp/waypoint\n"
fi


VAULT_HOST="$(kubectl get svc/vault-ui -n $VAULT_NS -o jsonpath={.status.loadBalancer.ingress[].ip})"
WAYPOINT_HOST="$(kubectl get svc/waypoint-ui -n $WAYPOINT_NS -o jsonpath={.status.loadBalancer.ingress[].ip})"
CONSUL_HOST="$(kubectl get svc/consul-ui -n $CONSUL_NS -o jsonpath={.status.loadBalancer.ingress[].ip})"


# echo -e "\nCreating Minikube Tunnel to create LoadBalancer IPs. Output to \"/tmp/tunnel.out\"... ====> \n"
# echo -e "You need sudo privileges for this, so you might be asked for password:  \n"
# sudo -u $USER nohup minikube tunnel -c -p $MINIKUBE_PROFILE > /tmp/tunnel.out &

sleep 5

echo -e "\nCreating \"apps\" namespace to deploy our microservices ====> \n"
kubectl create ns apps

echo -e "\nStatus of Consul ====> \n"
kubectl get po -n $CONSUL_NS

echo -e "\nStatus of Vault ====> \n"
kubectl get po -n $VAULT_NS

echo -e "\nStatus of Waypoint ====> \n"
kubectl get po -n $WAYPOINT_NS

echo -e "\nDon't forget to do \"minikube tunnel\" to expose Load Balancers if using Minikube====> \n"
echo -e "\tnohup minikube tunnel -c -p $MINIKUBE_PROFILE > /tmp/tunnel.out &\n\n"
### minikube tunnel -c -p $MINIKUBE_PROFILE  &> /tmp/tunnel.out &

echo -e "\n\nACCESS URLs:\n"
echo -e "\n\t=--> Consul UI: https://$(kubectl get svc consul-ui -n $CONSUL_NS -o jsonpath={.status.loadBalancer.ingress[0].ip})\n"
echo -e "\n\t=--> Vault UI: http://$(kubectl get svc vault-ui -n $VAULT_NS -o jsonpath={.status.loadBalancer.ingress[0].ip}):8200\n"
echo -e "\n\t=--> Waypoint UI: https://$(kubectl get svc waypoint-ui -n $WAYPOINT_NS -o jsonpath={.status.loadBalancer.ingress[0].ip})\n"


echo $VAULT_VALUES