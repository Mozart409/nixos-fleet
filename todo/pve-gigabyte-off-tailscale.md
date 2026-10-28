# pve-gigabyte: step-ca TLS now, Tailscale off later

Move the Proxmox hypervisor (`pve-gigabyte`, `192.168.2.46`, bare-metal Debian,
not in this repo) off Tailscale. Phase A gives its web UI a step-ca
certificate on `pve-gigabyte.homelab.internal` while Tailscale keeps running
next to it. Phase B removes Tailscale from the host.

**Status 2026-10-28: Phase A done except the renewal check (A.4).** Caddy on
the host serves `https://pve-gigabyte.homelab.internal/` with a step-ca cert
(`200 0` from wotan), next to the old ts.net vhost. The dashboard links there
and otel probes the cert. Inventory: Caddy (apt) on :80/:443, pveproxy on
:8006, no `tailscale serve`, and `/etc/resolv.conf` is Tailscale's MagicDNS
(`100.100.100.100`), so B.2 is required before Phase B.

## What exists

- DNS: `pve-gigabyte.homelab.internal` A/PTR are served by `dns`
  (`lib/hosts.nix`, zones `legacyAndInternal` + `local`).
- The host has the Caddy and Tailscale apt repos (vault note PVE,
  2026-07-16). The old dashboard link
  `https://pve-gigabyte.dropbear-butterfly.ts.net/` had no port, so something
  on :443 fronts pveproxy (:8006), most likely Caddy with a Tailscale cert
  (or `tailscale serve`). Check before changing anything (A.0).
- step-ca: ACME provisioner `acme` at
  `https://ca.homelab.internal:8443/acme/acme/directory`, 30-day default
  certs (`hosts/ca/configuration.nix`). Root PEM in
  `modules/step-ca-trust.nix`.
- Monitoring: `pve-node` scrape on `pve-gigabyte.homelab.internal:9100`
  (`hosts/otel/configuration.nix`), already off Tailscale. No blackbox probe.
- OpenTofu: `TF_VAR_endpoint` in `iac/secrets.sops.env` (encrypted; may be
  the LAN IP or the MagicDNS name, see the `insecure = true` comment in
  `iac/main.tf`).
- Remote access without Tailscale on the host: `dns` advertises
  `192.168.2.0/24` as a subnet route (`hosts/dns/configuration.nix`), so tailnet
  clients still reach `192.168.2.46` once the host leaves the tailnet.

## Decision: Caddy on :443, not `pvenode acme` on :8006

Caddy is already installed and is the fleet's step-ca pattern: it renews at a
third of the lifetime (~day 20 of 30). Proxmox's own ACME renewal
(`pve-daily-update`) renews when the cert has **less than 30 days** left, so a
30-day step-ca cert would be re-ordered every day. A :443 vhost also fits the
`tls_cert` blackbox job, which probes `name:443`.

`pvenode acme` on :8006 stays an option (e.g. to drop `insecure = true` in
tofu). It needs the root in the system trust store (A.1) and either accepts
daily renewals or a second step-ca ACME provisioner with a 90-day
`defaultTLSCertDuration`.

## Phase A — step-ca cert alongside Tailscale (on the host)

- [x] **A.0 Inventory.** What serves :443 today, and does the host resolve
  `.homelab.internal`?

      ss -tlnp | grep -E ':(80|443|8006)\b'
      cat /etc/caddy/Caddyfile
      tailscale serve status
      cat /etc/resolv.conf
      getent hosts ca.homelab.internal pve-gigabyte.homelab.internal

  If `ca.homelab.internal` does not resolve (MagicDNS-only resolver, see
  [`dns-tailscale-spof.md`](./dns-tailscale-spof.md)), fix that first (B.2).
- [x] **A.1 Trust the step-ca root.** Copy the PEM from
  `modules/step-ca-trust.nix` (unindented) to the host:

      install -m 0644 homelab-root-ca.crt /usr/local/share/ca-certificates/homelab-root-ca.crt
      update-ca-certificates
      curl -sS https://ca.homelab.internal:8443/health   # {"status":"ok"}

- [x] **A.2 Add the vhost** to `/etc/caddy/Caddyfile`, next to the existing
  ts.net block (leave that one alone):

      pve-gigabyte.homelab.internal {
          tls {
              ca https://ca.homelab.internal:8443/acme/acme/directory
              ca_root /usr/local/share/ca-certificates/homelab-root-ca.crt
          }
          reverse_proxy https://127.0.0.1:8006 {
              transport http {
                  tls_insecure_skip_verify
              }
          }
      }

  Caddy answers the challenge on :80 (http-01) or :443 (tls-alpn-01); step-ca
  connects from `192.168.2.160`. If the Proxmox firewall is on at host level,
  allow 80/443 from the LAN.

      caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
      journalctl -u caddy -n 50 | grep -i -E 'obtain|certificate|error'

- [x] **A.3 Verify** from wotan (trusts the root):

      curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' https://pve-gigabyte.homelab.internal/
      # expect 200 0; the noVNC console must work too (websockets through Caddy)

- [ ] **A.4 Renewal.** ~20 days after A.2, confirm Caddy renewed
  (`journalctl -u caddy | grep -i renew`, or the cert's notBefore).
- [x] **A.5 Repo follow-up (after A.3 is green):** add
  `pve-gigabyte = ["pve-gigabyte.homelab.internal"];` to `certSubjects` in
  `hosts/otel/blackbox.nix` (instance `pve-gigabyte`, so it dedups against
  `pve-node`). Held back until now: the file's rule is curl-verify first, and
  a probe on a missing cert fires `ProbeFailed` immediately.

## Phase B — remove Tailscale from the host

Everything that reaches pve-gigabyte, or that pve-gigabyte reaches, over
Tailscale must move to the LAN first.

- [ ] **B.1 Repo references** (`git grep -n -E 'pve-gigabyte|dropbear-butterfly'`):
  - dashboard link: done in Phase A.
  - [x] `TF_VAR_endpoint` set to `https://pve-gigabyte.homelab.internal:8006/`
    (2026-10-28, after Caddy's ts.net vhost started failing TLS with
    `tls: internal error`); `just iac-apply` worked through it. The
    `insecure = true` comment in `iac/main.tf` updated.
  - The PVE vault note: the `tailscale0` line and the apt repo list.
- [ ] **B.2 Resolver.** If `/etc/resolv.conf` is `100.100.100.100`, point the
  host at `dns` (`192.168.2.145`) via `/etc/network/interfaces`
  (`dns-nameservers`) or the PVE node DNS settings, with a public fallback.
- [ ] **B.3 What the host reaches over the tailnet.** Check and move to LAN
  names/IPs:

      grep -rn -E 'ts\.net|100\.[0-9]+\.[0-9]+\.[0-9]+' /etc/pve/storage.cfg /etc/pve/jobs.cfg /etc/postfix /etc/caddy 2>/dev/null

  Most important: the `pbs-r2` storage's `server` (PBS is VM 180). If it is a
  ts.net name, change it to PBS's LAN address and keep the `fingerprint`, or
  the 03:00 backups break.
- [ ] **B.4 What reaches the host over the tailnet.** Bookmarks, the iPhone /
  MacBook Proxmox apps, any `ssh pve-gigabyte` aliases using the MagicDNS name.
  Remote clients use the `dns` subnet route to `192.168.2.46` instead; confirm
  from off-LAN that `https://pve-gigabyte.homelab.internal/` works through it.
- [ ] **B.5 Tailscale ACLs** (`tailscale-acls` repo, outside yggdrasil): remove
  the pve-gigabyte host/tag entries and any rule granting it access.
- [ ] **B.6 Remove.** Trial first, then uninstall:

      tailscale serve reset          # if A.0 showed serve config
      tailscale down                 # trial: run a day, recheck B.3/B.4
      # Caddyfile: delete the pve-gigabyte.dropbear-butterfly.ts.net block, reload caddy
      apt purge tailscale && rm /etc/apt/sources.list.d/tailscale.list
      # Tailscale admin console: delete the pve-gigabyte machine

  Guests with their own tailscaled (e.g. the pocketid LXC, whose ts.net name
  is the OIDC issuer) are not affected; check their `/dev/net/tun` passthrough
  still works after the purge.

## Verification

- `https://pve-gigabyte.homelab.internal/` is green from wotan and from a
  tailnet client off-LAN (via the subnet route).
- `pve-node` and the new `blackbox-tls_cert` target for `pve-gigabyte` are up.
- The next nightly backup to `pbs-r2` succeeds after `tailscale down`.
- `just iac-plan` connects with the new endpoint.
