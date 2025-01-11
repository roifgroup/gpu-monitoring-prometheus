#!/bin/bash
set -x
sudo systemctl stop nvidia_gpu_exporter node_exporter
sudo systemctl disable nvidia_gpu_exporter node_exporter
sudo rm -rf /usr/bin/nvidia_gpu_exporter /usr/bin/node_exporter /etc/systemd/system/node_exporter.service /etc/systemd/system/nvidia_gpu_exporter.service /etc/node_exporter
sudo userdel nvidia_gpu_exporter
sudo systemctl daemon-reload
