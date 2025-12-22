#!/bin/bash

vms=(
    "gpmcontrolplane1"
    "gpmcontrolplane2"
    "gpmcontrolplane3"
    "gpmworker1"
    "gpmworker2"
)

CURRENT_DIR=$(pwd)

TEMPLATE_DISK_FILE="$CURRENT_DIR/gpmtemplate.qcow2"

VCPU=2
MEMORY_MB=2048
NETWORK_IFACE=virbr0

POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

IP_SUBNET=192.168.122.0/24
IP_RANGE_START=100
IP_RANGE_CONTROLPLANE1=101

### Dynamic provisioning
IP_GATEWAY="$(echo $IP_SUBNET | cut -d. -f1-3).1"
IP_FLOATING="$(echo $IP_SUBNET | cut -d. -f1-3).99"

for vm in ${vms[*]}; do 
    cp --update=none $TEMPLATE_DISK_FILE $vm.qcow2

    IP_ADDR="$(echo $IP_SUBNET | cut -d. -f1-3).$(($IP_RANGE_START+1))"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    IP_RANGE_START=$((IP_RANGE_START + 1))

    echo "Starting VM $vm with IP Address $IP_ADDR/$CIDR gateway $IP_GATEWAY"


    K8S_SERVER_STRING="controlplane"
    K8S_MODE="controlplane"
    if [[ "$vm" == *"$K8S_SERVER_STRING"*  ]]; then
    echo "Starting $vm as kubernetes $K8S_MODE node"
    else
    K8S_MODE="worker"
    echo "Starting $vm as kubernetes $K8S_MODE node"
    fi

    sed -i "s+###IP_GATEWAY###+$IP_GATEWAY+g" butane-common.yaml
    sed -i "s+/###CIDR###+/$CIDR+g" butane-common.yaml
    sed -i "s+###HOSTNAME###+$vm+g" butane-common.yaml
    sed -i "s+###IP_ADDRESS###+$IP_ADDR+g" butane-common.yaml


    if (( IP_RANGE_START == IP_RANGE_CONTROLPLANE1 )); then
        sed -i 's+###KUBEADM_MODE###+systemctl enable --now keepalived; /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-init.yaml; kubeadm token create --print-join-command --certificate-key "\$\(kubeadm init phase upload-certs --upload-certs | tail -n 1\)" > /tmp/controlplane-join.sh; kubeadm token create --print-join-command > /tmp/worker-join.sh+g' butane-kubeadm.yaml 
    elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        sed -i 's+###KUBEADM_MODE###+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/controlplane-join.sh /tmp/controlplane-join.sh ;echo "\$\(cat /tmp/controlplane-join.sh\) -v=5" | sudo PATH=/usr/local/bin bash; systemctl enable --now keepalived+g' butane-kubeadm.yaml 
    else
        sed -i 's+###KUBEADM_MODE###+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/worker-join.sh; echo "\$\(cat /tmp/controlplane-join.sh\) -v=5" | sudo PATH=/usr/local/bin bash+g' butane-kubeadm.yaml 
    fi

    sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" butane-keepalived.yaml

    sed -i "s+###POD_CIDR###+$POD_CIDR+g" butane-kubeadm.yaml
    sed -i "s+###SERVICE_CIDR###+$SERVICE_CIDR+g" butane-kubeadm.yaml
    sed -i "s+###FLOATINGIP###+$IP_FLOATING+g" butane-kubeadm.yaml

    if [[ "$K8S_MODE" == "controlplane"  ]]; then
    cat << EOF > butane-$vm.yaml
    variant: fcos
    version: 1.5.0
    ignition:
        config:
            merge:
            - inline: |-
                $(./butane ./butane-ssh.yaml)
            - inline: |-
                $(./butane ./butane-common.yaml)
            - inline: |-
                $(./butane ./butane-kubeadm.yaml)
            - inline: |-
                $(./butane ./butane-keepalived.yaml)
EOF
    else
    cat << EOF > butane-$vm.yaml
    variant: fcos
    version: 1.5.0
    ignition:
        config:
            merge:
            - inline: |-
                $(./butane ./butane-common.yaml)
            - inline: |-
                $(./butane ./butane-ssh.yaml)
            - inline: |-
                $(./butane ./butane-kubeadm.yaml)
EOF
    fi
    ./butane butane-$vm.yaml > $vm.ign
    rm -f butane-$vm.yaml

    sed -i "s+/$CIDR+/###CIDR###+g" butane-common.yaml
    sed -i "s+$vm+###HOSTNAME###+g" butane-common.yaml
    sed -i "s+$IP_ADDR+###IP_ADDRESS###+g" butane-common.yaml
    sed -i "s+$IP_GATEWAY+###IP_GATEWAY###+g" butane-common.yaml

    sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" butane-keepalived.yaml

    sed -i "s+$POD_CIDR+###POD_CIDR###+g" butane-kubeadm.yaml
    sed -i "s+$SERVICE_CIDR+###SERVICE_CIDR###+g" butane-kubeadm.yaml
    sed -i "s+$IP_FLOATING+###FLOATINGIP###+g" butane-kubeadm.yaml

    if (( IP_RANGE_START == IP_RANGE_CONTROLPLANE1 )); then
        sed -i 's+systemctl enable --now keepalived; /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-init.yaml; kubeadm token create --print-join-command --certificate-key "$(kubeadm init phase upload-certs --upload-certs | tail -n 1)" > /tmp/controlplane-join.sh; kubeadm token create --print-join-command > /tmp/worker-join.sh+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    elif [[ "$K8S_MODE" == "controlplane"  ]]; then
        sed -i 's+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/controlplane-join.sh /tmp/controlplane-join.sh ;echo "$(cat /tmp/controlplane-join.sh) -v=5" | sudo PATH=/usr/local/bin bash; systemctl enable --now keepalived+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    else
        sed -i 's+scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@###FLOATINGIP###:/tmp/worker-join.sh; echo "$(cat /tmp/controlplane-join.sh) -v=5" | sudo PATH=/usr/local/bin bash+###KUBEADM_MODE###+g' butane-kubeadm.yaml 
    fi

    virt-install \
    --name=$vm \
    --ram=$MEMORY_MB \
    --vcpus=$VCPU \
    --import \
    --disk path=$vm.qcow2,device=disk,bus=virtio \
    --os-variant opensuse-unknown \
    --network bridge=$NETWORK_IFACE,model=virtio \
    --graphics vnc,listen=0.0.0.0 --noautoconsole \
    --sysinfo type=fwcfg,entry0.name="opt/com.coreos/config",entry0.file="$CURRENT_DIR/$vm.ign"

    virsh start $vm

    # rm -f $vm.ign
done

## Cleanup ssh known_hosts as the nodes will be provisioed back-forth
> ~/.ssh/known_hosts



