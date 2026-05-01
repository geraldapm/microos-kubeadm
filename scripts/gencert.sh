#!/bin/bash

# This scripts/gencert.sh will generate necessary kubernetes certs as described below. Then it will be injected into the butane definition to support the kubernetes installation:
# Reference: https://kubernetes.io/docs/setup/best-practices/certificates/

# /etc/kubernetes/pki/ca.crt
# /etc/kubernetes/pki/ca.key
# /etc/kubernetes/pki/sa.key
# /etc/kubernetes/pki/sa.pub
# /etc/kubernetes/pki/front-proxy-ca.crt
# /etc/kubernetes/pki/front-proxy-ca.key
# /etc/kubernetes/pki/etcd/ca.crt
# /etc/kubernetes/pki/etcd/ca.key

# Create necessary directory and seed file text
mkdir -p certs rootca/crl
touch rootca/index.txt
echo 1000 > rootca/serial

# Root CA
{
  openssl genrsa -out rootca/ca.key 4096
  chmod 400 rootca/ca.key
  openssl req -x509 -new -sha512 -noenc \
    -key rootca/ca.key -days 7300 -section rootca\
    -config scripts/ca.conf \
    -out rootca/ca.crt
}

# kubernetes, etcd, and front-proxy CA Generate
kubeca=(
  "kubernetes-ca"
  "etcd-ca"
  "front-proxy-ca"
)

for cert in ${kubeca[*]}; do
  openssl genrsa -out certs/$cert.key 4096
  openssl req -new -key "certs/$cert.key" -sha256 \
      -config "scripts/ca.conf" -section $cert \
      -out "certs/$cert.csr"
  openssl ca -days 3653 -batch -in "certs/$cert.csr" \
      -config "scripts/ca.conf" -notext -out "certs/$cert.crt"
  openssl verify -CAfile "rootca/ca.crt" "certs/$cert.crt"

  # Generate certificate chain to be used as main CA for kubernetes
  cat certs/$cert.crt \
      rootca/ca.crt > certs/$cert-chain.crt
done

KUBERNETES_CA_CERT="certs/kubernetes-ca.crt"
KUBERNETES_CA_KEY="certs/kubernetes-ca.key"

### Generate Service account keypair
openssl genrsa -out "certs/service-accounts.key" 4096

openssl req -new -key "certs/service-accounts.key" -sha256 \
  -config "scripts/ca.conf" -section service-accounts \
  -out "certs/service-accounts.csr"
openssl x509 -req -days 3653 -in "certs/service-accounts.csr" \
  -copy_extensions copyall \
  -sha256 -CA $KUBERNETES_CA_CERT \
  -CAkey $KUBERNETES_CA_KEY \
  -CAcreateserial \
  -out "certs/service-accounts.crt"
openssl x509 -noout -text -in "certs/service-accounts.crt" | grep -A1 -iE "Subject:|Subject Alternative Name"