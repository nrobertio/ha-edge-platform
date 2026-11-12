#!/usr/bin/env bash
# Load balancer failover drill: find who holds the floating IP, kill HAProxy there,
# check the VIP moves to the peer and traffic keeps flowing.
set -euo pipefail
cd "$(dirname "$0")/.."

VIP=172.30.0.100
URL="https://app.local.test:8443"
C=(curl -s --max-time 3 --cacert certs/ca.crt --resolve app.local.test:8443:127.0.0.1)
pass() { echo "OK   $*"; }
fail() { echo "FAIL $*"; exit 1; }
holder() {
  local lb
  for lb in lb1 lb2; do
    if docker compose exec -T "$lb" ip -4 addr show eth0 2>/dev/null | grep -q "inet ${VIP}/"; then echo "$lb"; return; fi
  done
  echo none
}

active=none
for _ in $(seq 1 30); do active=$(holder); [ "$active" != "none" ] && break; sleep 1; done
[ "$active" != "none" ] || fail "no load balancer holds the VIP ${VIP}"
pass "VIP ${VIP} held by ${active}"

if [ "$active" = "lb1" ]; then peer=lb2; else peer=lb1; fi
docker compose exec -T "$active" pkill haproxy
start=$(date +%s)

moved=no
for _ in $(seq 1 20); do
  if [ "$(holder)" = "$peer" ]; then moved=yes; break; fi
  sleep 1
done
[ "$moved" = "yes" ] || fail "VIP did not move to ${peer}"
pass "HAProxy killed on ${active}: VIP moved to ${peer} in about $(( $(date +%s) - start ))s"

errors=0
for _ in $(seq 1 30); do
  code=$("${C[@]}" -o /dev/null -w '%{http_code}' "$URL/" || echo 000)
  [ "$code" = "200" ] || errors=$((errors + 1))
done
[ "$errors" = "0" ] || fail "${errors} of 30 requests failed after failover"
pass "30 requests through the VIP after failover, zero errors"

dual=0
for lb in lb1 lb2; do
  if docker compose exec -T "$lb" ip -4 addr show eth0 | grep -q "inet ${VIP}/"; then dual=$((dual + 1)); fi
done
[ "$dual" = "1" ] || fail "split brain: VIP present on ${dual} nodes"
pass "VIP on exactly one node (no split brain)"
