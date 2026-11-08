#!/bin/sh
GATEWAY=$(ip route | awk '/default/ {print $3}')
sed -i "s/DOCKER_HOST_GATEWAY/${GATEWAY}/g" /etc/prometheus/prometheus.yml
exec /bin/prometheus "$@"
