#!/bin/bash

PATH=$PATH:$(pwd)

source hostlist.sh

# Define the VM names array
vms=($(echo "$hostlist" | awk '{print $2}'))

### Define the default directory gen
CURRENT_DIR=$(pwd)
IGNITION_DIR=$CURRENT_DIR/ignition

for vm in ${vms[*]}; do
    echo "Reset ignition config for VM $vm"
    rm -f $IGNITION_DIR/$vm.ign
done

if [[ $1 == "--destroy" ]]; then rm -rf $CURRENT_DIR/{certs,butane-autogen,rootca,butane-generated,ignition}; fi
