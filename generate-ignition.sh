#!/bin/bash

PATH=$PATH:$(pwd)

source hostlist.sh

# Define the VM names array
vms=($(echo "$hostlist" | awk '{print $2}'))

### Define the first controlplane IP to init the kubeadm cluster
IP_RANGE_CONTROLPLANE1=192.168.122.101

### Define the default directory gen
CURRENT_DIR=$(pwd)

BUTANE_AUTOGEN_DIR=$CURRENT_DIR/butane-autogen
BUTANE_STATIC_DIR=$CURRENT_DIR/butane-config
BUTANE_GENERATED_DIR=$CURRENT_DIR/butane-generated
IGNITION_DIR=$CURRENT_DIR/ignition

### POD and service CIDR
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

### Versioning used in the provisioning scripts
K8S_VERSION="v1.35.4"
CRIO_VERSION="v1.35.2"
CALICO_VERSION="v3.31.5"
CILIUM_VERSION="1.19.3"
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

if [[ $1 == "--generate-cert" ]];
then
# create the generated butane directory
mkdir -p $BUTANE_GENERATED_DIR $IGNITION_DIR

### Generate kubernetes certs
bash ./scripts/gencert.sh

### Generate cert butane config
bash ./scripts/cert-yaml-injection.sh

### Generate ssh butane config
bash ./scripts/ssh-generator.sh

### Generate haproxy butane config
floating_ip=$IP_FLOATING hostlist="$hostlist" bash ./scripts/haproxy-generator.sh
fi

### Kubeadm configuration command
KUBEADM_PRESTART_COMMAND='/var/opt/bin/kubeadm config images pull'
KUBEADM_INIT_COMMAND='/var/opt/bin/kubeadm init --upload-certs --config /etc/kubernetes/kubeadm-config.yaml'
KUBEADM_CONTROLPLANE_JOIN_COMMAND='/var/opt/bin/kubeadm join ${APISERVER_ENDPOINT} --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt --config /etc/kubernetes/kubeadm-config.yaml'
KUBEADM_WORKER_JOIN_COMMAND='/var/opt/bin/kubeadm join ${APISERVER_ENDPOINT} --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt --config /etc/kubernetes/kubeadm-config.yaml'

cert_dir="$CURRENT_DIR/certs"

# Compute CA hash
ca_hash="sha256:$(openssl x509 -pubkey -in "$cert_dir/kubernetes-ca.crt" | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
encoded_base64_ca_hash=$(echo -n "$ca_hash" | base64 -w 0)

# Get token hash
token=$(echo "$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6).$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)")
encoded_token=$(echo -n "$token" | base64)

for vm in ${vms[*]}; do 
    IP_ADDR="$(echo "$hostlist" | grep $vm | awk '{print $1}')"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    echo "Generating ignition config for VM $vm with IP Address $IP_ADDR/$CIDR gateway $IP_GATEWAY"

    # Set node role to controlplane/worker
    K8S_SERVER_STRING="controlplane"
    K8S_MODE="controlplane"

    if [[ "$vm" == *"$K8S_SERVER_STRING"*  ]]; then
    echo "Generating ignition config for $vm as kubernetes $K8S_MODE node"
    else
    K8S_MODE="worker"
    echo "Generating ignition config for $vm as kubernetes $K8S_MODE node"
    fi

    if [[ "$IP_ADDR" == "$IP_RANGE_CONTROLPLANE1" ]]; then
 ### Change butane-calico.yaml to butane-cilium.yaml to change the CNI preference
        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-common.yaml \
                        | sed "s+###IP_GATEWAY###+$IP_GATEWAY+g" \
                        | sed "s+/###CIDR###+/$CIDR+g" \
                        | sed "s+###HOSTNAME###+$vm+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-ssh.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-crio.yaml \
                        | sed "s+###CRIO_VERSION###+$CRIO_VERSION+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-keepalived.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###KEEPALIVED_PRIORITY###+200+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-haproxy.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeconfig.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-certk8s.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_VERSION###+$K8S_VERSION+g" \
                        | sed "s+###FIRSTNODE_IP###+$IP_RANGE_CONTROLPLANE1+g" \
                        | sed "s+###KUBEADM_PRESTART###+$KUBEADM_PRESTART_COMMAND+g" \
                        | sed "s+###KUBEADM_MODE###+$KUBEADM_INIT_COMMAND+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm-init-config.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_TOKEN###+$token+g" \
                        | sed "s+###K8S_CERTHASH###+$ca_hash+g" \
                        | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                        | sed "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-calico.yaml \
                        | sed "s+###CALICO_VERSION###+$CALICO_VERSION+g" \
                        | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                        | butane)
EOF

## When changing to calico CNI (requires kube-proxy to enabled first then it will be disabled by calico when changing to eBPF):
                # - inline: |-
                #     $(cat $BUTANE_STATIC_DIR/butane-calico.yaml \
                #         | sed "s+###CALICO_VERSION###+$CALICO_VERSION+g" \
                #         | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                #         | butane)

### change to cilium cni
                # - inline: |-
                #     $(cat $BUTANE_STATIC_DIR/butane-cilium.yaml \
                #         | sed "s+###CILIUM_CLI_VERSION###+$CILIUM_CLI_VERSION+g" \
                #         | sed "s+###CILIUM_VERSION###+$CILIUM_VERSION+g" \
                #         | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                #         | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                #         | butane)

     elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-common.yaml \
                        | sed "s+###IP_GATEWAY###+$IP_GATEWAY+g" \
                        | sed "s+/###CIDR###+/$CIDR+g" \
                        | sed "s+###HOSTNAME###+$vm+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-ssh.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-crio.yaml \
                        | sed "s+###CRIO_VERSION###+$CRIO_VERSION+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-keepalived.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###KEEPALIVED_PRIORITY###+100+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-haproxy.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeconfig.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-certk8s.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_VERSION###+$K8S_VERSION+g" \
                        | sed "s+###FIRSTNODE_IP###+$IP_RANGE_CONTROLPLANE1+g" \
                        | sed "s+###KUBEADM_PRESTART###+$KUBEADM_PRESTART_COMMAND+g" \
                        | sed "s+###KUBEADM_MODE###+$KUBEADM_CONTROLPLANE_JOIN_COMMAND+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm-controlplane-config.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_TOKEN###+$token+g" \
                        | sed "s+###K8S_CERTHASH###+$ca_hash+g" \
                        | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                        | sed "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
EOF
    else
        KUBEADM_PRESTART_COMMAND='/var/opt/bin/kubeadm version'
        cat << EOF > $BUTANE_GENERATED_DIR/butane-$vm.yaml
        variant: fcos
        version: 1.5.0
        ignition:
            config:
                merge:
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-common.yaml \
                        | sed "s+###IP_GATEWAY###+$IP_GATEWAY+g" \
                        | sed "s+/###CIDR###+/$CIDR+g" \
                        | sed "s+###HOSTNAME###+$vm+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-ssh.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-crio.yaml \
                        | sed "s+###CRIO_VERSION###+$CRIO_VERSION+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_AUTOGEN_DIR/butane-tokenk8s.yaml \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_VERSION###+$K8S_VERSION+g" \
                        | sed "s+###FIRSTNODE_IP###+$IP_RANGE_CONTROLPLANE1+g" \
                        | sed "s+###KUBEADM_PRESTART###+$KUBEADM_PRESTART_COMMAND+g" \
                        | sed "s+###KUBEADM_MODE###+$KUBEADM_WORKER_JOIN_COMMAND+g" \
                        | butane)
                - inline: |-
                    $(cat $BUTANE_STATIC_DIR/butane-kubeadm-worker-config.yaml \
                        | sed "s+###FLOATINGIP###+$IP_FLOATING+g" \
                        | sed "s+###K8S_TOKEN###+$token+g" \
                        | sed "s+###K8S_CERTHASH###+$ca_hash+g" \
                        | sed "s+###POD_CIDR###+$POD_CIDR+g" \
                        | sed "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" \
                        | sed "s+###IP_ADDRESS###+$IP_ADDR+g" \
                        | butane)
EOF
    fi

    # Generate ignition file from compiled butane files
    butane --pretty $BUTANE_GENERATED_DIR/butane-$vm.yaml > $IGNITION_DIR/$vm.ign

    #Remove unused butane generated file
    rm -f $BUTANE_GENERATED_DIR/butane-$vm.yaml
done