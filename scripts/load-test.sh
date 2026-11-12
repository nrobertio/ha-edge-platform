#!/usr/bin/env bash
# Run the k6 load test in a container on the edge network (no local install).
set -euo pipefail
cd "$(dirname "$0")/.."
docker run --rm -i --network ha-edge-platform_edge \
  --add-host app.local.test:"$(docker compose exec -T nginx sh -c "hostname -i" | awk '{print $1}')" \
  -e BASE_URL=https://app.local.test \
  grafana/k6:0.54.0 run --quiet - < loadtest/edge.js
