#!/usr/bin/env bash
# Summarise and publish the fleet's vulnerability scans.
#
# `just vulns-fleet` runs vulnxscan per host into <dir>/<host>/ and touches
# <dir>/<host>/scan.ok on success. This script reads those results:
#
#   vulns-push.sh --summary [dir]   print a table of the open findings per host
#   vulns-push.sh [dir]             push the same counts to the OTLP/HTTP
#                                   endpoint as gauges (nixos_vulnerabilities,
#                                   nixos_vuln_scan_timestamp_seconds)
#
# dir defaults to <repo root>/.sbom. Counted per host from vulns.csv: rows by
# CVSS severity (critical >= 9, high >= 7, medium >= 4, low below, unknown =
# empty or non-numeric), skipping whitelisted rows. Only hosts with scan.ok
# count; a missing vulns.csv after a good scan means zero findings.
#
# Push auth: a bearer token read from $CREDENTIALS_DIRECTORY/otel-push-token
# (a systemd LoadCredential), else from the file named by $OTEL_PUSH_TOKEN_FILE.
set -euo pipefail

endpoint="https://otel.homelab.internal/v1/metrics"

mode=push
if [ "${1:-}" = "--summary" ]; then
  mode=summary
  shift
fi
dir="${1:-$(git rev-parse --show-toplevel)/.sbom}"

# Print "critical high medium low unknown" for one vulns.csv (zeros if absent).
count_file() {
  if [ ! -f "$1" ]; then
    echo "0 0 0 0 0"
    return
  fi
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        hd = $i; gsub(/"/, "", hd)
        if (hd == "severity") s = i
        if (hd == "whitelist") w = i
      }
      next
    }
    NF == 0 { next }
    {
      if (w) { x = $w; gsub(/"/, "", x); if (x == "True") next }
      v = ""
      if (s) { v = $s; gsub(/"/, "", v) }
      if (v !~ /^[0-9]+(\.[0-9]+)?$/) u++
      else if (v + 0 >= 9) c++
      else if (v + 0 >= 7) h++
      else if (v + 0 >= 4) m++
      else l++
    }
    END { printf "%d %d %d %d %d\n", c, h, m, l, u }
  ' "$1"
}

# Hosts with a successful scan, one name per line.
scanned_hosts() {
  local ok
  for ok in "$dir"/*/scan.ok; do
    [ -e "$ok" ] || continue
    basename "$(dirname "$ok")"
  done
}

if [ "$mode" = summary ]; then
  printf '%-20s %8s %6s %6s %5s %8s\n' host critical high medium low unknown
  found=0
  while IFS= read -r host; do
    found=1
    read -r c h m l u < <(count_file "$dir/$host/vulns.csv")
    printf '%-20s %8s %6s %6s %5s %8s\n' "$host" "$c" "$h" "$m" "$l" "$u"
  done < <(scanned_hosts)
  [ "$found" = 1 ] || echo "no successful scans under $dir"
  exit 0
fi

if [ -n "${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/otel-push-token" ]; then
  token_file="$CREDENTIALS_DIRECTORY/otel-push-token"
elif [ -n "${OTEL_PUSH_TOKEN_FILE:-}" ]; then
  token_file="$OTEL_PUSH_TOKEN_FILE"
else
  echo "vulns-push: no token: set \$CREDENTIALS_DIRECTORY (with otel-push-token) or \$OTEL_PUSH_TOKEN_FILE" >&2
  exit 1
fi
[ -r "$token_file" ] || { echo "vulns-push: cannot read token file $token_file" >&2; exit 1; }

rows=""
while IFS= read -r host; do
  read -r c h m l u < <(count_file "$dir/$host/vulns.csv")
  rows+=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s' "$host" "$c" "$h" "$m" "$l" "$u" "$(stat -c %Y "$dir/$host/scan.ok")")$'\n'
done < <(scanned_hosts)
[ -n "$rows" ] || { echo "vulns-push: no successful scans under $dir, nothing to push" >&2; exit 1; }

now_ns="$(date +%s)000000000"
payload=$(printf '%s' "$rows" | jq -Rn --arg inst "$(hostname)" --arg now "$now_ns" '
  [inputs | select(length > 0) | split("\t")] as $r
  | ["critical", "high", "medium", "low", "unknown"] as $sev
  | {resourceMetrics: [{
      resource: {attributes: [
        {key: "service.name", value: {stringValue: "vuln-scan"}},
        {key: "service.instance.id", value: {stringValue: $inst}}
      ]},
      scopeMetrics: [{
        scope: {name: "vulns-push"},
        metrics: [
          {name: "nixos_vulnerabilities",
           gauge: {dataPoints: [
             $r[] as $x | range(0; 5) as $i | {
               asInt: $x[$i + 1],
               timeUnixNano: $now,
               attributes: [
                 {key: "host", value: {stringValue: $x[0]}},
                 {key: "severity", value: {stringValue: $sev[$i]}}
               ]
             }
           ]}},
          {name: "nixos_vuln_scan_timestamp_seconds",
           gauge: {dataPoints: [
             $r[] | {
               asInt: .[6],
               timeUnixNano: $now,
               attributes: [{key: "host", value: {stringValue: .[0]}}]
             }
           ]}}
        ]
      }]
    }]}
')

# The token goes through a header file, not argv, so it stays out of `ps`.
headers=$(mktemp)
trap 'rm -f "$headers"' EXIT
chmod 600 "$headers"
{
  echo "Content-Type: application/json"
  printf 'Authorization: Bearer %s\n' "$(tr -d '\r\n' <"$token_file")"
} >"$headers"

printf '%s' "$payload" | curl --fail-with-body -sS -X POST -H "@$headers" --data-binary @- "$endpoint"
echo
echo "vulns-push: pushed $(printf '%s' "$rows" | grep -c .) host(s) to $endpoint"
