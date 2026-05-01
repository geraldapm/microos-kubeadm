#!/bin/bash

CURRENT_DIR=$(pwd)

source hostlist.sh

# Define the VM names array
vms=($(echo "$hostlist" | awk '{print $2}'))

for vm in ${vms[*]}; do
    echo "Power Off VM $vm"
    virsh destroy $vm
    virt-xml $vm --edit --sysinfo remove_entry=all
    if [[ $1 == "--destroy" ]];
    then
    echo "Cleanup VM $vm"
    virsh undefine $vm --remove-all-storage

    fi
done