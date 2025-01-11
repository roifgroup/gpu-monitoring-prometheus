#!/bin/bash

# Const
NODE_EXPORTER_PORT=9100
GPU_EXPORTER_PORT=9835

[ $# -ne 1 ] && echo -e "Error: No argument provided, enter in the following syntax:\n ./add_gpu_system 192.168.1.30" && exit 0

sudo yq e '.scrape_configs[] |= select(.job_name == "gpus") |= (.static_configs[0].targets += "'"$1:$GPU_EXPORTER_PORT"'")' -i prometheus/prometheus.yml
sudo yq e '.scrape_configs[] |= select(.job_name == "nodes") |= (.static_configs[0].targets += "'"$1:$NODE_EXPORTER_PORT"'")' -i prometheus/prometheus.yml

docker restart prometheus
