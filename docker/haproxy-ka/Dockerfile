FROM haproxy:3.0.30-alpine
USER root
# Keepalived (VRRP) runs next to HAProxy in the same container, so the floating IP
# only sits on a node where HAProxy is actually running.
RUN apk add --no-cache keepalived \
 && mkdir -p /etc/keepalived
COPY entrypoint.sh /entrypoint-ka.sh
COPY chk_haproxy.sh /usr/local/bin/chk_haproxy.sh
RUN chmod 0755 /usr/local/bin/chk_haproxy.sh
ENTRYPOINT ["/bin/sh", "/entrypoint-ka.sh"]
