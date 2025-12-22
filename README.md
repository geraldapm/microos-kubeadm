# K3s MicroOS provisioning with Ignition way

This repository contains the quick way to deploy a K3s basic HA cluster with OpenSUSE MicroOS. It is intended to be recycleable and minimizing the requirement to intervene manually during K3s installation. Just sit down, grab some drinks, and enjoy the process. Easily creatable and destroyable K3s cluster.

## Prerequisites

- An Installed Linux System with KVM capabilities
- MicroOS cloud image with qcow2 format. Download it from there -> https://get.opensuse.org/microos. NOTE: Do not use container host image because it contains podman and K3s does not using podman as its CNI (make it simple and clean).
- Butane binary executable to convert butane definition into ignition file. Download it from there -> https://github.com/coreos/butane/releases

## Preparing

- Copy butane-ssh.yaml.example to butane-ssh.yaml and edit its contents

```bash
    ### Enable inter-node ssh to copy kubeadm join token
    - path: /root/.ssh/id_rsa
      mode: 0600
      overwrite: true
      contents:
        inline: |-
          -----BEGIN OPENSSH PRIVATE KEY-----
          abcdefg.....
```

- Start the template VMs

```bash
bash template-microos.sh
```

- After all installation sequence completed, Reinitialize the ignition config

```bash
sudo sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ ignition.firstboot=1"/' /etc/default/grub
sudo transactional-update grub.cfg
```

- Power Off the VM. It is now ready to serve as template VM for our Kubernees Nodes

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

- Use with your needs, feel free to play with the K8s kubeadm Cluster.

## Cleanup

Poweroff the VMs

```bash
bash stop-microos.sh
```

Poweroff and cleanup all the VMs data

```bash
bash stop-microos.sh --destroy
```

TODO: Automate kubeadm provisioning

- manual provisioning
  First controlplane

```bash
kubeadm init --control-plane-endpoint=192.168.122.99 --apiserver-advertise-address=192.168.122.101 --apiserver-cert-extra-sans=192.168.122.101,192.168.122.99 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 --node-name "${HOSTNAME}" --ignore-preflight-errors Swap

```
