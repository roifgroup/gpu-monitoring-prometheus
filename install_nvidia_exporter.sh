#!/bin/bash

set -x

NODE_EXPORTER_VERSION=1.8.2
GPU_EXPORTER_VERSION=1.2.1

[ -f /usr/bin/nvidia_gpu_exporter ] && echo "Exporter already installed" && exit 0

curl https://github.com/utkuozdemir/nvidia_gpu_exporter/releases/download/v${GPU_EXPORTER_VERSION}/nvidia_gpu_exporter_${GPU_EXPORTER_VERSION}_linux_x86_64.tar.gz -OsfL
sudo tar -C /usr/bin/ -xvzf nvidia_gpu_exporter_${GPU_EXPORTER_VERSION}_linux_x86_64.tar.gz nvidia_gpu_exporter
rm nvidia_gpu_exporter_${GPU_EXPORTER_VERSION}_linux_x86_64.tar.gz

curl https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz -OsfL
tar -xvzf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter
sudo mv node_exporter-$NODE_EXPORTER_VERSION.linux-amd64/node_exporter /usr/bin/
rm -rf node_exporter-$NODE_EXPORTER_VERSION.linux-amd64.tar.gz node_exporter-$NODE_EXPORTER_VERSION.linux-amd64

sudo useradd --system --no-create-home --shell /usr/sbin/nologin nvidia_gpu_exporter

cat <<EOF >nvidia_gpu_exporter.service
[Unit]
Description=Nvidia GPU Exporter
After=network-online.target

[Service]
Type=simple

User=nvidia_gpu_exporter
Group=nvidia_gpu_exporter

ExecStart=/usr/bin/nvidia_gpu_exporter --web.config.file=/etc/node_exporter/web-config.yml

SyslogIdentifier=nvidia_gpu_exporter

Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF >node_exporter.service
[Unit]
Description=Node Exporter
After=network-online.target

[Service]
Type=simple

User=nvidia_gpu_exporter
Group=nvidia_gpu_exporter

ExecStart=/usr/bin/node_exporter --web.config.file=/etc/node_exporter/web-config.yml

SyslogIdentifier=node_exporter

Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir -p /etc/node_exporter
cat <<EOF >web-config.yml
tls_server_config:
  cert_file: "/etc/node_exporter/node_exporter.crt"
  key_file: "/etc/node_exporter/node_exporter.key"
  client_ca_file: "/etc/node_exporter/ca.crt"
  client_auth_type: "RequireAndVerifyClientCert"
EOF

sudo cp web-config.yml node_exporter_installer/node_exporter.* node_exporter_installer/ca.crt /etc/node_exporter/
sudo chown -R nvidia_gpu_exporter: /etc/node_exporter
sudo chmod -R 440 /etc/node_exporter/*

sudo mv nvidia_gpu_exporter.service node_exporter.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia_gpu_exporter node_exporter
