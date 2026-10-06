#!/bin/sh
# keepalived health check: this node keeps the VIP only while its AdGuard answers.
dig @127.0.0.1 google.com +time=1 +tries=1 >/dev/null 2>&1
