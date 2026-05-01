#!/bin/bash
set -e

mkdir -p butane-autogen
output_yaml="butane-autogen/butane-ssh.yaml"
indent="          "

ssh_privkey_raw=$(cat ~/.ssh/id_rsa)

ssh_privkey=$(echo "$ssh_privkey_raw" | sed "s/^/${indent}/")

# Write the header to the output YAML file
cat > "$output_yaml" <<-EOF
variant: fcos
version: 1.5.0
storage:
  files:
    - path: /root/.ssh/id_rsa
      contents:
        inline: |
$ssh_privkey
EOF

echo "SSH passwordless key have been generated successfully!"
echo "YAML file '$output_yaml' has been successfully overwritten!"