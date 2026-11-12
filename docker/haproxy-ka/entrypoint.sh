#!/bin/sh
# Start HAProxy (single process) in the background, then Keepalived in the foreground.
# If HAProxy dies, the track script fails and the VIP moves to the peer.
set -eu
haproxy -db -f /usr/local/etc/haproxy/haproxy.cfg &
exec keepalived --dont-fork --log-console --vrrp -f /etc/keepalived/keepalived.conf
