#!/bin/bash
set -euo pipefail

URL="${url:-}"
DNS="${dns:-}"
RESOLVER_ENDPOINT="${resolver_endpoint:-}"
THREADS=2
OUT_DEVNULL_DIR="/"
OUT_DEVNULL="dev/null"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

if [[ -n "$DNS" ]]; then
  echo "nameserver $DNS" > /etc/resolv.conf || true
  log "DNS 设置为 $DNS"
fi

resolve_final_url_and_headers() {
  local resp
  resp="$(curl -sS -X POST \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$URL\"}" \
    "$RESOLVER_ENDPOINT")" || return 1

  local final_url
  final_url="$(echo "$resp" | jq -r '.url')"
  [[ "$final_url" == "null" || -z "$final_url" ]] && return 1
  echo "$final_url" > /tmp/effective.url

  rm -f /tmp/headers.txt
  echo "$resp" | jq -r '.headers | to_entries[] | "\(.key): \(.value)"' > /tmp/headers.txt
  [[ -s /tmp/headers.txt && -s /tmp/effective.url ]]
}

headers_args_from_file() {
  local file="$1"
  local args=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && args+=( --header="$line" )
  done < "$file"
  echo "${args[@]}"
}

do_download_once() {
  if ! resolve_final_url_and_headers; then
    log "解析失败，等待重试..."
    sleep 3
    return 1
  fi
  local final_url
  final_url="$(cat /tmp/effective.url)"
  local header_args
  header_args=($(headers_args_from_file /tmp/headers.txt))

  log "开始下载 -> $final_url"
  aria2c \
    --dir="$OUT_DEVNULL_DIR" \
    --out="$OUT_DEVNULL" \
    --file-allocation=none \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --summary-interval=1 \
    --max-connection-per-server="$THREADS" \
    --split="$THREADS" \
    --min-split-size=1M \
    --retry-wait=2 \
    --max-tries=0 \
    --timeout=60 \
    "${header_args[@]}" \
    -- "$final_url"
}

while true; do
  do_download_once || true
  sleep 1
done