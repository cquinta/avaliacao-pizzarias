FROM grafana/grafana:latest

USER root

RUN apk add --no-cache curl

COPY provisioning/dashboards/dashboards.yml /etc/grafana/provisioning/dashboards/dashboards.yml

RUN mkdir -p /var/lib/grafana/dashboards && \
    for id in 14282 1860 23120; do \
      curl -fsSL "https://grafana.com/api/dashboards/${id}/revisions/latest/download" \
        -o "/var/lib/grafana/dashboards/${id}.json"; \
    done

USER grafana
