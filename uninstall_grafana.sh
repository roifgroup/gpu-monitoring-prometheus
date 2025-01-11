#!/bin/bash

docker compose down -v

for i in *.cnf *.csr grafana prometheus ca.key node_exporter_installer web-config.yml grafana_ssl; do
  sudo rm -rf "$i"
done
