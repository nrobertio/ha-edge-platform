#!/usr/bin/env bash
# End-to-end checks: TLS, redirect, HSTS, load balancing, failover, recovery, rate limiting.
set -euo pipefail
cd "$(dirname "$0")/.."

URL="https://app.local.test:8443"
C=(curl -s --cacert certs/ca.crt --resolve app.local.test:8443:127.0.0.1)
pass() { echo "OK   $*"; }
fail() { echo "FAIL $*"; exit 1; }
backend() { "${C[@]}" "$URL/" | awk '/^Hostname:/{print $2}'; }

# wait for the edge
for _ in $(seq 1 30); do
  [ "$("${C[@]}" -o /dev/null -w '%{http_code}' "$URL/")" = "200" ] && break
  sleep 1
done
[ "$("${C[@]}" -o /dev/null -w '%{http_code}' "$URL/")" = "200" ] || fail "edge not serving 200"
pass "HTTPS 200 with a certificate verified against the lab CA"

code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Host: app.local.test' http://127.0.0.1:8080/)
[ "$code" = "301" ] || fail "HTTP did not redirect (got $code)"
pass "HTTP redirects to HTTPS"

"${C[@]}" -D - -o /dev/null "$URL/" | grep -qi '^strict-transport-security' || fail "HSTS header missing"
pass "HSTS header present"

code=$(curl -sk -o /dev/null -w '%{http_code}' --resolve other.test:8443:127.0.0.1 https://other.test:8443/)
[ "$code" = "421" ] || fail "unknown host not rejected (got $code)"
pass "unknown host rejected with 421"

seen=$(for _ in $(seq 1 30); do backend; done | sort -u | tr '\n' ' ')
[ "$seen" = "app1 app2 app3 " ] || fail "load balancing: saw [$seen]"
pass "round robin across app1 app2 app3"

docker compose stop app2 >/dev/null
sleep 6
for _ in $(seq 1 20); do
  [ "$("${C[@]}" -o /dev/null -w '%{http_code}' "$URL/")" = "200" ] || fail "request failed while app2 down"
done
seen=$(for _ in $(seq 1 20); do backend; done | sort -u | tr '\n' ' ')
[ "$seen" = "app1 app3 " ] || fail "app2 still receiving traffic: [$seen]"
pass "app2 down: 40 requests, zero errors, traffic only on app1 app3"

docker compose start app2 >/dev/null
back=no
for _ in $(seq 1 30); do
  if for _ in $(seq 1 6); do backend; done | grep -qx app2; then back=yes; break; fi
  sleep 1
done
[ "$back" = "yes" ] || fail "app2 did not rejoin the pool"
pass "app2 back: rejoined the pool after health checks"

api=$("${C[@]}" "$URL/api/" | awk '/^Hostname:/{print $2}')
[ "$api" = "api" ] || fail "path routing: /api/ went to [$api]"
pass "/api/ routed to the api service"

codes=$(for _ in $(seq 1 30); do "${C[@]}" -o /dev/null -w '%{http_code}\n' "$URL/api/"; done)
ok=$(echo "$codes" | awk '$1==200{n++} END{print n+0}')
limited=$(echo "$codes" | awk '$1==429{n++} END{print n+0}')
if [ "$ok" -lt 1 ] || [ "$limited" -lt 1 ]; then
  fail "rate limit: ${ok}x200 ${limited}x429"
fi
pass "rate limit on /api/: ${ok}x200, ${limited}x429"
