#!/usr/bin/env bash
# Local lab CA and a server certificate for app.local.test. Short-lived, never committed.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p certs
openssl req -x509 -newkey rsa:2048 -nodes -days 30 \
  -keyout certs/ca.key -out certs/ca.crt -subj "/CN=ha-edge-lab CA" 2>/dev/null
openssl req -newkey rsa:2048 -nodes \
  -keyout certs/server.key -out certs/server.csr -subj "/CN=app.local.test" 2>/dev/null
printf 'subjectAltName=DNS:app.local.test\nextendedKeyUsage=serverAuth\n' > certs/ext.cnf
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial \
  -days 30 -extfile certs/ext.cnf -out certs/server.crt 2>/dev/null
chmod 0644 certs/server.crt certs/server.key
echo "certs written to ./certs (CA: certs/ca.crt)"
