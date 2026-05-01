# Kubeadm MicroOS provisioning with Ignition way

This repository contains the quick way to deploy a Kubeadm basic HA cluster with OpenSUSE MicroOS. It is intended to be recycleable and minimizing the requirement to intervene manually during Kubeadm installation. Just sit down, grab some drinks, and enjoy the process. Easily creatable and destroyable Kubeadm cluster.

## Prerequisites

- An Installed Linux System with KVM capabilities
- MicroOS cloud image with qcow2 format. Download it from there -> https://get.opensuse.org/microos. NOTE: Usese container host image because it contains podman and it will be used as runtime for keepalived and haproxy for virtual IP HA mode.
- Butane binary executable to convert butane definition into ignition file. Download it from there -> https://github.com/coreos/butane/releases and install with this command

```bash
wget -c https://github.com/coreos/butane/releases/download/v0.25.1/butane-x86_64-unknown-linux-gnu -O butane
chmod +x butane
```

- Allocatable IP Addresses for each vms
- FAST Internet connection for downloading required binaries

## Environments

3 Control Plane Nodes and 2 Worker Nodes installed with Flatcar Linux and Kubernetes v1.35 cluster with Calico CNI v3.31.5. The spec is 2 vCPU, 2GB Memory and 20GB Stoage (in rootfs). It also has the Floating IP for kubernetes api server reachability and enabling High-Availability. Edit the subnet, ip and hostnames in file [hostlist.sh](./hostlist.sh)

```
floatingip 192.168.122.100

gpmcontrolplane1 192.168.122.101
gpmcontrolplane2 192.168.122.102
gpmcontrolplane3 192.168.122.103
gpmworker1 192.168.122.104
gpmworker2 192.168.122.105
```

## Pre-provisioning

1. Ensure that the latest image is downloaded and inside into the Linux Hypervisor.

2. Generate ignition scripts and other resources with this command:

```shell
bash generate-ignition.sh --generate-cert
```

3. When needed, you can delete all ignition scripts and other resources with this command:

```shell
bash reset-ignition.sh --destroy
```

## Provisioning

Provision the VMs with this command:

```shell
bash start-vm.sh --provision
```

When needed, you can stop the VM with this command:

```shell
bash stop-vm.sh
```

and starting it once again with this command:

```shell
bash start-vm.sh
```

## Cleanup

If you need to stop the VMs and deleting all provisioned VMs, use this command

```shell
bash stop-vm.sh --destroy
```
