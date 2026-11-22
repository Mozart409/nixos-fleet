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
# dir defaults to <repo root>/.sbom. Counted per host from vulns.csv, skipping
# whitelisted rows and deduped by vuln_id+package (the same finding can appear
# several times, e.g. perl 5.42.3 and 5.42.3-env; max severity and max scanner
# count win). Severity buckets by CVSS score: critical >= 9, high >= 7, medium
# >= 4, low below, unknown = empty or non-numeric. Findings are split by how
# many of grype, OSV and vulnix found them: confirmed (2+ scanners) and single
# (one scanner, mostly NVD range noise). Only hosts with scan.ok count; a
# missing vulns.csv after a good scan means zero findings.
#
# The push labels every nixos_vulnerabilities sample with
# confirmed="true"|"false" next to host and severity.
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

# Print ten numbers for one vulns.csv (zeros if absent): "critical high medium
# low unknown" for confirmed findings (2+ scanners), then the same five for
# single-scanner findings.
count_file() {
  if [ ! -f "$1" ]; then
    echo "0 0 0 0 0 0 0 0 0 0"
    return
  fi
  awk -F, '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        hd = $i; gsub(/"/, "", hd)
        if (hd == "vuln_id") id = i
        if (hd == "package") pk = i
        if (hd == "severity") s = i
        if (hd == "sum") n = i
        if (hd == "whitelist") w = i
      }
      next
    }
    NF == 0 { next }
    {
      if (w) { x = $w; gsub(/"/, "", x); if (x == "True") next }
      k = ""
      if (id) { x = $id; gsub(/"/, "", x); k = x }
      if (pk) { x = $pk; gsub(/"/, "", x); k = k SUBSEP x }
      v = ""
      if (s) { v = $s; gsub(/"/, "", v) }
      v = (v ~ /^[0-9]+(\.[0-9]+)?$/) ? v + 0 : -1
      q = 0
      if (n) { x = $n; gsub(/"/, "", x); q = x + 0 }
      if (!(k in sev) || v > sev[k]) sev[k] = v
      if (!(k in sum) || q > sum[k]) sum[k] = q
    }
    END {
      for (k in sev) {
        g = (sum[k] >= 2) ? 0 : 5
        v = sev[k]
        if (v < 0) cnt[g + 4]++
        else if (v >= 9) cnt[g]++
        else if (v >= 7) cnt[g + 1]++
        else if (v >= 4) cnt[g + 2]++
        else cnt[g + 3]++
      }
      for (i = 0; i < 10; i++) printf "%d%s", cnt[i], (i < 9 ? " " : "\n")
    }
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
  echo "counts: findings confirmed by 2+ scanners, deduped by vuln_id+package; single = found by one scanner only"
  printf '%-20s %8s %6s %6s %5s %8s %6s\n' host critical high medium low unknown single
  found=0
  while IFS= read -r host; do
    found=1
    read -r c h m l u sc sh sm sl su < <(count_file "$dir/$host/vulns.csv")
    printf '%-20s %8s %6s %6s %5s %8s %6s\n' "$host" "$c" "$h" "$m" "$l" "$u" "$((sc + sh + sm + sl + su))"
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
  counts=$(count_file "$dir/$host/vulns.csv" | tr ' ' '\t')
  rows+=$(printf '%s\t%s\t%s' "$host" "$counts" "$(stat -c %Y "$dir/$host/scan.ok")")$'\n'
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
             $r[] as $x | range(0; 10) as $i | {
               asInt: $x[$i + 1],
               timeUnixNano: $now,
               attributes: [
                 {key: "host", value: {stringValue: $x[0]}},
                 {key: "severity", value: {stringValue: $sev[$i % 5]}},
                 {key: "confirmed", value: {stringValue: (if $i < 5 then "true" else "false" end)}}
               ]
             }
           ]}},
          {name: "nixos_vuln_scan_timestamp_seconds",
           gauge: {dataPoints: [
             $r[] | {
               asInt: .[11],
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
