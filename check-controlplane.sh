#!/bin/bash

vms=(
    "gpmcontrolplane1"
    "gpmcontrolplane2"
    "gpmcontrolplane3"
    "gpmworker1"
    "gpmworker2"
)

CURRENT_DIR=$(pwd)

POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

IP_SUBNET=192.168.122.0/24
IP_RANGE_START=100
IP_RANGE_CONTROLPLANE1=101

### Dynamic provisioning
IP_GATEWAY="$(echo $IP_SUBNET | cut -d. -f1-3).1"
IP_FLOATING="$(echo $IP_SUBNET | cut -d. -f1-3).99"

for vm in ${vms[*]}; do 

    IP_ADDR="$(echo $IP_SUBNET | cut -d. -f1-3).$(($IP_RANGE_START+1))"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    IP_RANGE_START=$((IP_RANGE_START + 1))

    K8S_SERVER_STRING="controlplane"
    K8S_MODE="server"
    if [[ "$vm" == *"$K8S_SERVER_STRING"*  ]]; then
    echo "Checking $vm as kubernetes controlplane node"
    else
    echo "Checking $vm as kubernetes worker node"
    K8S_MODE="agent"
    fi

    if [[ "$K8S_MODE" == "server"  ]]; then
        ssh root@${IP_ADDR} kubeadm version
        ssh root@${IP_ADDR} systemctl status keepalived --no-pager
    else
        ssh root@${IP_ADDR} kubeadm version
    fi
done


echo "Waiting for Kubernetes API server to be ready..."
until curl -sk https://${IP_FLOATING}:6443/readyz; do
  echo "API server not ready yet. Retrying in 2 seconds..."
  sleep 2
done
echo -e "\nAPI server is now READY."