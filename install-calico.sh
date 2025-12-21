#!/bin/bash

CALICO_VERSION="v3.31.1"

# Subnet of primary IP Address installed on node
SUBNET=192.168.122.0/24

# Pod CIDR range
POD_CIDR=10.244.0.0/16

# install Tigera Operator
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/operator-crds.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/tigera-operator.yaml

# Enable ebpf resource
# kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/$CALICO_VERSION/manifests/custom-resources-bpf.yaml

# Get current subnet interface
local_interface=$(ip route | grep $SUBNET | awk '{print $3'} | head -n 1)

# Use current kube-proxy aware dataplane
cat <<EOF | kubectl apply -f -
# This section includes base Calico installation configuration.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.Installation
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  flexVolumePath: /usr/local/libexec/kubernetes/kubelet-plugins/volume/exec/
  # Configures Calico networking.
  calicoNetwork:
    # Uncomment to enable BPF Dataplane, Requires disabling kube-proxy
    #linuxDataplane: BPF
    linuxDataplane: Iptables
    bgp: Disabled
    bpfNetworkBootstrap: Disabled
    kubeProxyManagement: Disabled

### Select the main subnet IP interface because vagrant has 2 distict network interfaces
    nodeAddressAutodetectionV4:
      interface: "${local_interface}"

    ipPools:
      - name: default-ipv4-ippool
        blockSize: 26
        cidr: ${POD_CIDR}
        encapsulation: VXLANCrossSubnet
        natOutgoing: Enabled
        nodeSelector: all()

---
# This section configures the Calico API server.
# For more information, see: https://docs.tigera.io/calico/latest/reference/installation/api#operator.tigera.io/v1.APIServer
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}

---
# Configures the Calico Goldmane flow aggregator.
apiVersion: operator.tigera.io/v1
kind: Goldmane
metadata:
  name: default

---
# Configures the Calico Whisker observability UI.
apiVersion: operator.tigera.io/v1
kind: Whisker
metadata:
  name: default
EOF