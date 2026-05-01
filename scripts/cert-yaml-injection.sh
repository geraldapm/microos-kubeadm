#!/bin/bash
set -e
cert_dir=./certs

CURRENT_DIR=$(pwd)
BUTANE_AUTOGEN_DIR=${BUTANE_AUTOGEN_DIR:="$CURRENT_DIR/butane-autogen"} 

mkdir -p $BUTANE_AUTOGEN_DIR

output_controlplane_yaml="$BUTANE_AUTOGEN_DIR/butane-certk8s.yaml"
output_worker_yaml="$BUTANE_AUTOGEN_DIR/butane-tokenk8s.yaml"
indent="          "

# Encode certificates for YAML
ca_crt=$(sed "s/^/${indent}/" "$cert_dir/kubernetes-ca.crt")
ca_key=$(sed "s/^/${indent}/" "$cert_dir/kubernetes-ca.key")
front_proxy_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca.crt")
front_proxy_ca_key=$(sed "s/^/${indent}/" "$cert_dir/front-proxy-ca.key")
sa_key=$(sed "s/^/${indent}/" "$cert_dir/service-accounts.key")
sa_pub=$(sed "s/^/${indent}/" "$cert_dir/service-accounts.crt")
etcd_ca_crt=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca.crt")
etcd_ca_key=$(sed "s/^/${indent}/" "$cert_dir/etcd-ca.key")

# Compute CA hash
ca_hash="sha256:$(openssl x509 -pubkey -in "$cert_dir/kubernetes-ca.crt" | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
encoded_base64_ca_hash=$(echo -n "$ca_hash" | base64 -w 0)

# Get token hash
token=$(echo "$(tr -dc 'a-z0-9' < /dev/urandom | head -c 6).$(tr -dc 'a-z0-9' < /dev/urandom | head -c 16)")
encoded_token=$(echo -n "$token" | base64)

# Write the header to the output YAML file
cat > "$output_controlplane_yaml" <<-EOF
variant: fcos
version: 1.5.0
storage:
  files:
    - path: /etc/kubernetes/pki/ca.crt
      contents:
        inline: |
$ca_crt
    - path: /etc/kubernetes/pki/ca.key
      contents:
        inline: |
$ca_key
    - path: /etc/kubernetes/pki/front-proxy-ca.crt
      contents:
        inline: |
$front_proxy_ca_crt
    - path: /etc/kubernetes/pki/front-proxy-ca.key
      contents:
        inline: |
$front_proxy_ca_key
    - path: /etc/kubernetes/pki/sa.key
      contents:
        inline: |
$sa_key
    - path: /etc/kubernetes/pki/sa.pub
      contents:
        inline: |
$sa_pub
    - path: /etc/kubernetes/pki/etcd/ca.crt
      contents:
        inline: |
$etcd_ca_crt
    - path: /etc/kubernetes/pki/etcd/ca.key
      contents:
        inline: |
$etcd_ca_key
    - path: /etc/kubernetes/certs.conf
      contents:
        inline: |
            K8S_TOKEN='$token'
            K8S_HASH='$ca_hash'
EOF

# Write the header to the output YAML file
cat > "$output_worker_yaml" <<-EOF
variant: fcos
version: 1.5.0
storage:
  files:
    - path: /etc/kubernetes/certs.conf
      contents:
        inline: |
            K8S_TOKEN='$token'
            K8S_HASH='$ca_hash'
EOF

echo "Kubernetes certificates have been generated successfully!"
echo "YAML file '$output_controlplane_yaml' and '$output_worker_yaml' has been successfully overwritten!"