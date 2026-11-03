# HA Edge Platform

A hands-on high-availability edge: Nginx terminates TLS and applies routing and rate limits, HAProxy load balances three app instances with active health checks, and failures are tested, not assumed. Runs with Docker Compose and is verified end to end in CI.

Maintained by nrobertio.

## What this demonstrates

- TLS termination at the edge: TLS 1.2/1.3 only, HSTS, HTTP to HTTPS redirect, unknown hosts rejected (421).
- Load balancing: HAProxy round robin over three instances, active health checks (`/health`), retry and redispatch on connection failure.
- Failover: stop an instance and traffic keeps flowing with zero failed requests; start it again and it rejoins after health checks.
- Routing: host-based (`app.local.test`) and path-based (`/api/` to a separate service).
- Rate limiting: a generous limit for the site, a strict one for the API, returning 429.

## Architecture

```
client --HTTPS--> nginx (TLS, redirect, routing, rate limit)
                    |-- /      --> haproxy (round robin, health checks) --> app1 | app2 | app3
                    |-- /api/  --> api
```

## Run it

Easiest: open the repo in GitHub Codespaces (Code > Codespaces > Create codespace). Docker and the lab certificates are set up automatically. Locally you need Docker and openssl.

```
bash scripts/gen-certs.sh        # local lab CA + cert for app.local.test (not committed)
docker compose up -d --wait
bash scripts/test-edge.sh        # TLS, redirect, load balancing, failover, rate limit
docker compose down -v
```

Try it by hand:

```
curl --cacert certs/ca.crt --resolve app.local.test:8443:127.0.0.1 https://app.local.test:8443/
docker compose stop app2         # watch the HAProxy stats page: http://127.0.0.1:8404/stats
```

All ports are bound to 127.0.0.1. The stats page has no authentication, so it must stay local.

## Roadmap

- [x] TLS edge, routing, rate limiting
- [x] HAProxy pool with health checks, failover and recovery tests in CI
- [ ] Two load balancers with Keepalived (VRRP floating IP): kill the active one, traffic moves
- [ ] Real certificates with ACME (Let's Encrypt staging) and renewal
- [ ] Load test with k6 to find the limits of the pool
- [ ] docs/PROJECT.md: design decisions and trade-offs

## License

MIT. See LICENSE.