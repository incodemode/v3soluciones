#!/usr/bin/env bash
set -euo pipefail

base_url="${1:?base URL is required}"
server_ip="${2:?server IP is required}"
expected_version="${3:?expected version is required}"
links_file="${4:-links.txt}"
host="${base_url#*://}"
host="${host%%/*}"

curl_args=(--silent --show-error --fail --resolve "${host}:443:${server_ip}")

actual_version="$(curl "${curl_args[@]}" \
  -H 'Cache-Control: no-cache' \
  "${base_url}/version.txt")"

if [[ "$actual_version" != "$expected_version" ]]; then
  echo "Version mismatch: expected '$expected_version', received '$actual_version'" >&2
  exit 1
fi

curl "${curl_args[@]}" \
  -H 'Cache-Control: no-cache' \
  "${base_url}/" | grep -Fq "deployment-version: ${expected_version}"

dermapedia_headers="$(curl --silent --show-error --resolve "${host}:443:${server_ip}" \
  --output /dev/null --dump-header - "${base_url}/enlace/congreso-dermapedia" | tr -d '\r')"
dermapedia_status="$(printf '%s\n' "$dermapedia_headers" | awk 'NR == 1 {print $2}')"
dermapedia_type="$(printf '%s\n' "$dermapedia_headers" | awk 'BEGIN{IGNORECASE=1} /^Content-Type:/ {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')"
dermapedia_cache="$(printf '%s\n' "$dermapedia_headers" | awk 'BEGIN{IGNORECASE=1} /^Cache-Control:/ {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')"

[[ "$dermapedia_status" == "200" ]] || { echo "Dermapedia returned HTTP $dermapedia_status, expected 200" >&2; exit 1; }
[[ "$dermapedia_type" == text/html* ]] || { echo "Dermapedia returned '$dermapedia_type', expected text/html" >&2; exit 1; }
[[ "$dermapedia_cache" == *no-store* && "$dermapedia_cache" == *no-cache* ]] || {
  echo "Dermapedia is missing no-store/no-cache headers" >&2
  exit 1
}

while IFS=' ' read -r path expected_location extra; do
  [[ -z "$path" || "$path" == \#* ]] && continue
  [[ -z "${extra:-}" ]] || { echo "Invalid links entry: $path $expected_location $extra" >&2; exit 1; }

  headers="$(curl --silent --show-error --resolve "${host}:443:${server_ip}" \
    --output /dev/null --dump-header - "${base_url}${path}" | tr -d '\r')"

  status="$(printf '%s\n' "$headers" | awk 'NR == 1 {print $2}')"
  location="$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^Location:/ {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')"
  cache_control="$(printf '%s\n' "$headers" | awk 'BEGIN{IGNORECASE=1} /^Cache-Control:/ {sub(/^[^:]+:[[:space:]]*/, ""); print; exit}')"

  [[ "$status" == "302" ]] || { echo "$path returned HTTP $status, expected 302" >&2; exit 1; }
  [[ "$location" == "$expected_location" ]] || { echo "$path redirected to '$location', expected '$expected_location'" >&2; exit 1; }
  [[ "$cache_control" == *no-store* && "$cache_control" == *no-cache* ]] || {
    echo "$path is missing no-store/no-cache headers" >&2
    exit 1
  }
done < "$links_file"

echo "Deployment $expected_version passed version, Dermapedia, and redirect checks."
