#!/bin/bash

[ -d grafana ] && echo "Already installed" && exit 0

YQ_VERSION=4.44.6
sudo curl -sfL https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_amd64 -o /usr/bin/yq
sudo chmod +x /usr/bin/yq

# Constants
PROM_PASSWORD=prometheus

# Cert details
COUNTRY=IL
STATE=Israel
CITY=Tel-Aviv
ORG=RoifGroup
OU=IT

# Gen password for prometheus
pip3 install bcrypt 2>&1 >/dev/null
BCRYPT_PROM_PASS=$(python3 -c "import bcrypt; print(bcrypt.hashpw(b'$PROM_PASSWORD', bcrypt.gensalt()).decode())")

mkdir grafana grafana_ssl prometheus

# Create CA
cat <<EOF >san.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORG
OU = $OU
CN = example

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = example
EOF

cat <<EOF >node_exporter.cnf
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $COUNTRY
ST = $STATE
L = $CITY
O = $ORG
OU = $OU
CN = node_exporter

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = node_exporter
EOF

openssl genrsa -out ca.key 4096
sed 's/example/prometheus-ca/g' san.cnf >ca.cnf
openssl req -new -x509 -key ca.key -out prometheus/ca.crt -days 3650 -config ca.cnf

# Create Prom certificate
openssl genrsa -out prometheus/prometheus.key 4096
sed 's/example/prometheus/g' san.cnf >prometheus.cnf
openssl req -new -key prometheus/prometheus.key -out prometheus.csr -config prometheus.cnf
openssl x509 -req -in prometheus.csr -CA prometheus/ca.crt -CAkey ca.key -CAcreateserial -out prometheus/prometheus.crt -days 3650 -extfile prometheus.cnf -extensions v3_req

# Create grafana certificate
openssl genrsa -out grafana_ssl/grafana.key 4096
sed 's/example/grafana/g' san.cnf >grafana.cnf
openssl req -new -key grafana_ssl/grafana.key -out grafana.csr -config grafana.cnf
openssl x509 -req -in grafana.csr -CA prometheus/ca.crt -CAkey ca.key -CAcreateserial -out grafana_ssl/grafana.crt -days 3650 -extfile grafana.cnf -extensions v3_req

# Create Node Exporter certificate
mkdir -p node_exporter_installer
openssl genrsa -out node_exporter_installer/node_exporter.key 4096
openssl req -new -key node_exporter_installer/node_exporter.key -out node_exporter.csr -config node_exporter.cnf
openssl x509 -req -in node_exporter.csr -CA prometheus/ca.crt -CAkey ca.key -CAcreateserial -out node_exporter_installer/node_exporter.crt -days 3650 -extfile node_exporter.cnf -extensions v3_req

CA=$(cat prometheus/ca.crt | sed 's/^/      /')

cat <<EOF >prometheus/prometheus.yml
global:
  scrape_interval: 15s
  scrape_timeout: 10s
  evaluation_interval: 15s
alerting:
  alertmanagers:
  - static_configs:
    - targets: []
    scheme: http
    timeout: 10s
    api_version: v2
scrape_configs:
- job_name: prometheus
  honor_timestamps: true
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  tls_config:
    ca_file: '/etc/prometheus/ca.crt'
    cert_file: '/etc/prometheus/prometheus.crt'
    key_file: '/etc/prometheus/prometheus.key'
    server_name: 'prometheus'
  basic_auth:
    username: 'admin'
    password: '$PROM_PASSWORD'
  static_configs:
  - targets:
    - localhost:9090
- job_name: nodes
  honor_timestamps: true
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  tls_config:
    ca_file: '/etc/prometheus/ca.crt'
    cert_file: '/etc/prometheus/prometheus.crt'
    key_file: '/etc/prometheus/prometheus.key'
    server_name: 'node_exporter'
  static_configs:
  - targets:
    - 10.200.0.80:9100
- job_name: gpus
  honor_timestamps: true
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  tls_config:
    ca_file: '/etc/prometheus/ca.crt'
    cert_file: '/etc/prometheus/prometheus.crt'
    key_file: '/etc/prometheus/prometheus.key'
    server_name: 'node_exporter'
  static_configs:
  - targets:
    - 10.200.0.80:9835
EOF

cat <<EOF >prometheus/web-config.yml
tls_server_config:
  cert_file: prometheus.crt
  key_file: prometheus.key
  client_ca_file: ca.crt
  client_auth_type: VerifyClientCertIfGiven
basic_auth_users:
  admin: $BCRYPT_PROM_PASS
EOF

cat <<EOF >grafana/datasource.yml
apiVersion: 1

datasources:
- name: Prometheus
  type: prometheus
  url: https://prometheus:9090 
  basicAuth: true
  basicAuthUser: admin
  basicAuthPassword: $PROM_PASSWORD
  jsonData:
    tlsAuthWithCACert: true
  secureJsonData:
    tlsCACert: |
$CA
    basicAuthPassword: $PROM_PASSWORD
  isDefault: true
  access: proxy
  editable: true
EOF

sudo chown 0:0 -R grafana
sudo chown 65534:65534 -R prometheus
sudo chown 472:0 -R grafana_ssl/*
cp prometheus/ca.crt node_exporter_installer/

docker compose up -d
