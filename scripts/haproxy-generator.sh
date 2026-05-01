#!/bin/bash

CURRENT_DIR=$(pwd)
BUTANE_AUTOGEN_DIR=${BUTANE_AUTOGEN_DIR:="$CURRENT_DIR/butane-autogen"} 

mkdir -p $BUTANE_AUTOGEN_DIR

output_yaml="butane-autogen/butane-haproxy.yaml"
indent="          "

# floating_ip="192.168.122.100"

# ### Define the cluster member list. Ensure that the controlplane has "control" inside the hostname
# hostlist=$(cat <<EOF
# 192.168.122.101     gpmcontrolplane1
# 192.168.122.102     gpmcontrolplane2
# 192.168.122.103     gpmcontrolplane3
# 192.168.122.104     gpmworker1    
# 192.168.122.105     gpmworker2
# EOF
# )

controlplane_vm_ips=($(echo "$hostlist" | grep "control" | awk '{print $1}'))

haproxy_config_raw=$(cat <<EOF
# /etc/haproxy/haproxy.cfg
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    log stdout format raw local0
    daemon
#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 1
    timeout http-request    10s
    timeout queue           20s
    timeout connect         5s
    timeout client          35s
    timeout server          35s
    timeout http-keep-alive 10s
    timeout check           10s
#---------------------------------------------------------------------
# apiserver frontend which proxys to the control plane nodes
#---------------------------------------------------------------------
frontend apiserver
    bind $floating_ip:6444
    mode tcp
    option tcplog
    default_backend apiserverbackend
#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserverbackend
    mode tcp
    balance     roundrobin


EOF
)

for vm in ${!controlplane_vm_ips[@]}; do
haproxy_config_raw=$( cat <<EOF
$haproxy_config_raw
    server node-cp$(( $vm + 1 )) ${controlplane_vm_ips[$vm]}:6443 check verify none
EOF
)
done

# echo "$haproxy_config_raw"

haproxy_config=$(echo "$haproxy_config_raw" | sed "s/^/${indent}/")

# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
variant: fcos
version: 1.5.0
storage:
  files:
    - path: /etc/containers/systemd/haproxy.container
      contents:
        inline: |
          [Unit]
          Description=HAProxy Container
          Requires=keepalived.service
          After=keepalived.service

          [Container]
          Image=docker.io/library/haproxy:alpine
          AutoUpdate=registry
          Network=host
          Volume=/etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro

          [Service]
          Restart=always
          RestartSec=30

          [Install]
          WantedBy=multi-user.target default.target
    - path: /etc/haproxy/haproxy.cfg
      contents:
        inline: |
$haproxy_config
EOF

echo "Haproxy config have been generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"