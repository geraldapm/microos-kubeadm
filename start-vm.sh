#!/bin/bash

PATH=$PATH:$(pwd)

source hostlist.sh

# Define the VM names array
vms=($(echo "$hostlist" | awk '{print $2}'))

### Define the default directory gen
CURRENT_DIR=$(pwd)

IMAGE_DIR=$CURRENT_DIR/images
TEMPLATE_DISK_FILE="$IMAGE_DIR/openSUSE-MicroOS.x86_64-ContainerHost-kvm-and-xen.qcow2"
IGNITION_DIR=$CURRENT_DIR/ignition

### VM Specs
VCPU=2
MEMORY_MB=2048
NETWORK_IFACE=virbr0


for vm in ${vms[*]}; do 
    IP_ADDR="$(echo "$hostlist" | grep $vm | awk '{print $1}')"
    CIDR="$(echo $IP_SUBNET | cut -d'/' -f2)"

    echo "Starting VM $vm with IP Address $IP_ADDR/$CIDR gateway $IP_GATEWAY"

if [[ $1 == "--provision" ]];
then
    qemu-img create -f qcow2 -F qcow2 -b $TEMPLATE_DISK_FILE $IMAGE_DIR/$vm.qcow2 20G

    virt-install \
    --name=$vm \
    --ram=$MEMORY_MB \
    --vcpus=$VCPU \
    --import \
    --disk path=$IMAGE_DIR/$vm.qcow2,device=disk,bus=virtio \
    --os-variant opensuse-unknown \
    --network bridge=$NETWORK_IFACE,model=virtio \
    --graphics vnc,listen=0.0.0.0 --noautoconsole \
    --sysinfo type=fwcfg,entry0.name="opt/com.coreos/config",entry0.file="$IGNITION_DIR/$vm.ign"

    # give delay so that the first controlplane always boot first
    sleep 10s
else
    virsh start $vm
fi


done

> $HOME/.ssh/known_hosts
