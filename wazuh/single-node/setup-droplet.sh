#!/usr/bin/env bash
# Bootstrap script for a fresh Ubuntu DigitalOcean droplet to run the
# Wazuh single-node Docker stack. Run as root (or with sudo) once,
# right after the droplet is created.
#
# Usage: sudo bash setup-droplet.sh

set -euo pipefail

echo "==> Updating package index"
apt-get update -y

echo "==> Installing prerequisites"
apt-get install -y ca-certificates curl gnupg ufw

echo "==> Installing Docker Engine + Compose plugin"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "Docker already installed, skipping."
fi

echo "==> Setting vm.max_map_count for the Wazuh indexer (OpenSearch requirement)"
if ! grep -q "^vm.max_map_count" /etc/sysctl.conf 2>/dev/null; then
  echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -w vm.max_map_count=262144

echo "==> Configuring firewall (UFW)"
ufw allow OpenSSH
ufw allow 443/tcp     # Wazuh dashboard (web UI)
ufw allow 1514/tcp    # Agent data
ufw allow 1515/tcp    # Agent enrollment
ufw allow 514/udp     # Syslog collection (only needed if you forward syslog to Wazuh)
# Intentionally NOT opening 9200 (indexer) or 55000 (API) to the public internet.
# Access those locally on the droplet, or over a VPN/SSH tunnel, if you need them.
ufw --force enable

echo "==> Done. Log out and back in (or run 'newgrp docker') if 'docker' commands require sudo."
echo "==> Next: cd into this directory and follow DIGITALOCEAN_DEPLOY.md"
