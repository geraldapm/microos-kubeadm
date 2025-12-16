#!/bin/bash

CURRENT_DIR=$(pwd)

vms=(
    "gpmcontrolplane1"
    "gpmcontrolplane2"
    "gpmcontrolplane3"
    "gpmworker1"
    "gpmworker2"
)

for vm in ${vms[*]}; do
    echo "Power Off VM $vm"
    virsh destroy $vm
    if [[ $1 == "--destroy" ]];
    then
    echo "Cleanup VM $vm"
    virsh undefine $vm --remove-all-storage
    fi
    rm -f $vm.ign
done