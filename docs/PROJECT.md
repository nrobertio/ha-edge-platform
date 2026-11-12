# HA Edge Platform: project write-up

## Why this exists

"Highly available" is easy to draw and easy to get wrong. Every layer needs an answer to one question: what happens when this piece dies? This lab answers it for the app instances and for the load balancer itself, and proves the answers in CI on every push.

## Layers

1. Nginx edge: TLS termination, redirect to HTTPS, HSTS, host and path routing, per-client rate limits. Unknown hosts get 421 so a misrouted request is never served by accident.
2. Floating IP: lb1 and lb2 run Keepalived. One holds the virtual IP 172.30.0.100. Nginx only knows the VIP, so a load balancer failure is invisible to it.
3. HAProxy pool: round robin over three app instances, health checks every 2 seconds, two failures to mark down and two successes to mark up. `option redispatch` with retries moves a failed connection to another server instead of returning an error.

## Design decisions

- Health checks in two places: HAProxy checks the apps; Keepalived checks HAProxy with a track script. Without the track script, Keepalived would keep the VIP on a node whose HAProxy is dead, which is a classic failure.
- Unicast VRRP: cloud and container networks often drop multicast, so the peers are listed explicitly.
- `nopreempt` on both nodes: when the failed node comes back, the VIP stays where it is. This avoids a second, unnecessary failover. The trade-off is that the higher-priority node is not automatically preferred again.
- Static addresses for lb1, lb2 and the VIP, and dynamic addresses limited to the upper half of the subnet, so Docker can never hand the VIP to another container.
- Different rate limits for site and API: the API is cheaper to abuse, so it gets a strict limit with a small burst.
- Self-signed lab CA, short-lived and never committed: the test verifies the full chain against the CA instead of using `--insecure`.

## Design notes and trade-offs

- Split brain: if the two nodes cannot see each other, both can take the VIP. The drill checks the VIP is on exactly one node. In production you also watch for duplicate ARP and keep the VRRP link reliable.
- Failover time: about 2 to 3 seconds here (advert interval 1s, fall 2). Faster settings mean quicker failover but more risk of flapping on a busy network.
- In AWS, a floating IP on a subnet does not work the same way. The managed equivalent is an ALB or NLB across availability zones, which does health checks and failover for you. Keepalived still fits on-prem sites and hybrid edges.
- Load test thresholds encode the target (p95 under 300 ms, under 1% errors), so a regression fails CI instead of being noticed by users.

## What I would add next

- ACME certificates with automatic renewal, and certificate expiry alerts.
- HAProxy Prometheus metrics and a dashboard for backend health, queue time and error rate.
- A load test while an app instance and a load balancer fail, to measure error rate during failover.
