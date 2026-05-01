#!/bin/bash

### Define IP Subnet for CIDR assignment including floating IP and gateway IP

IP_SUBNET=192.168.122.0/24

### Set IP Subnet Gateway
IP_GATEWAY="$(echo $IP_SUBNET | cut -d. -f1-3).1"

### Define the Virtual IP or Floating IP
IP_FLOATING="$(echo $IP_SUBNET | cut -d. -f1-3).99"

### Define cluster member list
### Ensure that the hostname has "wontrol" and "worker" inside for node role filtering
hostlist=$(cat <<EOF
192.168.122.101     gpmcontrolplane1
192.168.122.102     gpmcontrolplane2
192.168.122.103     gpmcontrolplane3
192.168.122.104     gpmworker1    
192.168.122.105     gpmworker2
EOF
)
