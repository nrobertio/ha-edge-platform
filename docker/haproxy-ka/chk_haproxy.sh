#!/bin/sh
# Keepalived track script: healthy only while an HAProxy process exists.
pidof haproxy >/dev/null
