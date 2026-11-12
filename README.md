# HA Edge Platform

A hands-on high-availability edge: Nginx terminates TLS and applies routing and rate limits, two HAProxy load balancers share a floating IP with Keepalived (VRRP), and three app instances sit behind them with active health checks. Every failure mode is tested, not assumed: CI kills an app instance, then a whole load balancer, and checks that traffic keeps flowing. Runs with Docker Compose.

Maintained by nrobertio.

## What this demonstrates

- TLS termination at the edge: TLS 1.2/1.3 only, HSTS, HTTP to HTTPS redirect, unknown hosts rejected (421).
- Load balancing: HAProxy round robin over three instances, active health checks, retry and redispatch.
- App failover: stop an instance and traffic keeps flowing with zero failed requests; it rejoins after health checks.
- Load balancer failover: two HAProxy nodes with Keepalived (VRRP, unicast). Kill HAProxy on the active node and the floating IP moves to the peer, with no split brain.
- Routing and rate limits: host and path routing (`/api/`), a strict API limit returning 429.
- Load test: k6 ramps to 40 requests per second through the full edge, with thresholds on errors (<1%) and p95 latency (<300 ms).

## Architecture

```
client --HTTPS--> nginx (TLS, redirect, routing, rate limit)
                    |-- /      --> VIP 172.30.0.100 (VRRP)
                    |                 |-- lb1 HAProxy (active)  --\
                    |                 |-- lb2 HAProxy (standby) ---+--> app1 | app2 | app3
                    |-- /api/  --> api
```

## Run it

Easiest: open the repo in GitHub Codespaces (Code > Codespaces > Create codespace). Docker and the lab certificates are set up automatically. Locally you need Docker and openssl.

```
bash scripts/gen-certs.sh          # local lab CA + cert for app.local.test (not committed)
docker compose up -d --build --wait
bash scripts/test-edge.sh          # TLS, redirect, load balancing, app failover, rate limit
bash scripts/load-test.sh          # k6 through the whole edge
bash scripts/lb-failover-drill.sh  # kill the active load balancer, VIP moves
docker compose down -v
```

All ports are bound to 127.0.0.1. The HAProxy stats pages (8404 for lb1, 8405 for lb2) have no authentication, so they must stay local.

Design decisions and trade-offs: [docs/PROJECT.md](docs/PROJECT.md).

## Roadmap

- [x] TLS edge, routing, rate limiting
- [x] HAProxy pool with health checks, app failover and recovery tests
- [x] Two load balancers with Keepalived VRRP floating IP, failover drill
- [x] k6 load test with thresholds
- [ ] Real certificates with ACME (Let's Encrypt staging) and renewal
- [ ] Metrics: HAProxy Prometheus endpoint and a dashboard

## License

MIT. See LICENSE.
