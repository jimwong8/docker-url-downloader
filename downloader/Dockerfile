FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl aria2 jq \
 && rm -rf /var/lib/apt/lists/*

ENV url="" \
    dns="" \
    resolver_endpoint=""

WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]