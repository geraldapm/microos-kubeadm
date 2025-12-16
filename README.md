# K3s MicroOS provisioning with Ignition way

This repository contains the quick way to deploy a K3s basic HA cluster with OpenSUSE MicroOS. It is intended to be recycleable and minimizing the requirement to intervene manually during K3s installation. Just sit down, grab some drinks, and enjoy the process. Easily creatable and destroyable K3s cluster.

## Prerequisites

- An Installed Linux System with KVM capabilities
- MicroOS cloud image with qcow2 format. Download it from there -> https://get.opensuse.org/microos. NOTE: Do not use container host image because it contains podman and K3s does not using podman as its CNI (make it simple and clean).
- Butane binary executable to convert butane definition into ignition file. Download it from there -> https://github.com/coreos/butane/releases

## Installing

- Copy the downloaded qcow2 file to working directory.
- Copy the downloaded butane binary executable into working directory
- Edit the following env from scripts [./start-microos.sh](./start-microos.sh)

```bash
# Change the hostname and node count. Note that the provisioning will be sequential.
vms=(
    "gpmcontrolplane1"
    "gpmcontrolplane2"
    "gpmcontrolplane3"
    "gpmworker1"
    "gpmworker2"
)

# MicroOS cloud image file path
TEMPLATE_DISK_FILE="$CURRENT_DIR/opensuse-microos.qcow2"

# Modify CPU, Memory, and network interface. It is homogenous for all node. Change depending on needs.
VCPU=2
MEMORY_MB=2048
NETWORK_IFACE=virbr0

# Default POD CIDR & Service CIDR
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/12

# Default IP Network Range from KVM
IP_SUBNET=192.168.122.0/24
IP_RANGE_START=100
IP_RANGE_CONTROLPLANE1=101

# K3s provisioning token. Change depending on needs.
K3S_TOKEN="K3S_SECRET_TOKEN"
```

- Edit the following env from scripts [./stop-microos.sh](./stop-microos.sh)

```bash
### Change the hostname and node count
vms=(
    "gpmcontrolplane1"
    "gpmcontrolplane2"
    "gpmcontrolplane3"
    "gpmworker1"
    "gpmworker2"
)
```

- Start the VMs

```bash
bash start-microos.sh
```

- Wait for about 10 minutes to ensure that the cluster is fully provisioned.
- Verify installation (default root password is "12345")

```bash
ssh root@<controlplanenode> k3s kubectl get node
```

- Copy kubeconfig to local if needed (requires kubectl)

```bash
# Setup kubeconfig
mkdir -p ~/.kube
scp root@<controlplanenode>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
chown -R $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

sed -i "s/127.0.0.1/$IP_FLOATING/" ~/.kube/config
```

- Optional: Install headlamp dashboard

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/headlamp/main/kubernetes-headlamp.yaml

kubectl -n kube-system create serviceaccount headlamp-admin
kubectl create clusterrolebinding headlamp-admin --serviceaccount=kube-system:headlamp-admin --clusterrole=cluster-admin

cat << EOF | kubectl apply -f -
kind: Service
apiVersion: v1
metadata:
  name: headlamp-nodeport
  namespace: kube-system
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 4466
      nodePort: 30009
  selector:
    k8s-app: headlamp
EOF

## Generate headlamp-admin token to enable login into headlamp web
kubectl create token headlamp-admin -n kube-system

## Access web with http://<controlplanenode>:30009
```

- Use with your needs, feel free to play with the K3s Cluster.

## Cleanup

Poweroff the VMs

```bash
bash stop-microos.sh
```

Poweroff and cleanup all the VMs data

```bash
bash stop-microos.sh --destroy
```

## Troubleshooting

Here are the procedures to troubleshoot the installations:

- Reset k3s installation

```bash
rm -f /usr/local/bin/k3s
systemctl restart install-k3s
```

### Control-plane (k3s-server) node

- Check for installation status

```bash
# Check package installation status. It is usually long because MicroOS will start fetching some repositories metadata
systemctl status install-k3s
systemctl status install-k3s-selinux
systemctl status install-keepalived

# Check the floating IP status
systemctl status keepalived
ip addr
```

- Check for k3s cluster

```bash
k3s kubectl get node
systemctl status k3s-server
```

### Worker (k3s-agent) node

- Check for installation status

```bash
# Check package installation status. It is usually long because MicroOS will start fetching some repositories metadata
systemctl status install-k3s
systemctl status install-k3s-selinux
```

- Check for k3s cluster state

```bash
systemctl status k3s-agent
```
