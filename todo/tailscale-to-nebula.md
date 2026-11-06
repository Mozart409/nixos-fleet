# Homelab off Tailscale, onto the Nebula network mozart409

Move every homelab host and the user's own clients from Tailscale to the
Nebula network `mozart409` (172.16.20.0/24, UDP 4343, its own CA), then
delete the tailnet. Nothing here is deployed; this is the plan. The
`amartum` network (172.16.10.0/24, UDP 4242, separate CA) is business and
never carries homelab traffic; wotan stays on both and its `amartum` uses
do not change.

**Status 2026-11-06: planned, not started.** Point-in-time observation from
a Tailscale snapshot and Prometheus, same day. Nothing below has run.

## What exists

- Tailscale SaaS. Members: wotan, iPhone, MacBook (offline 36 days, key
  expired), homeassistant, 9 fleet hosts (agents, ca, containers, database,
  dns, forgejo, jellyfin, mcp, otel), pve-gigabyte, immich, pbs, pocketid,
  homelab-unifi (offline 15 days). No exit nodes, no shared nodes, no
  Serve/Funnel on wotan.
- Subnet route `192.168.2.0/24`: the repo says `dns` advertises it
  (`hosts/dns/configuration.nix`, `extraUpFlags`; root `flake.nix`, comment
  above `hostRegistry`), but the snapshot shows **Home Assistant** as the
  active router. Whether `dns` is an approved standby is unknown (A.4).
- `mozart409` has lighthouses `.1`-`.3` (`lighthouse-{a,b,c}.oyabu.cc`) and
  wotan `.100`. All lighthouses answer ping from wotan's `amadeus` user. No
  homelab traffic has ever used it, so it is unproven.
- wotan runs Nebula 1.12.0 and Tailscale 1.104.4. Lighthouse versions are
  unverified. The mozart409 CA expires 2031-09-20, wotan's cert 2028-09-21.
- wotan's client config: `hosts/wotan/nebula.nix` (history in
  [`nebula-clients.md`](./nebula-clients.md)). IP registry:
  `services/nebula/tenants.nix` in the lighthouse repo.
- Fleet hosts import `modules/tailscale.nix` (agents, ca, containers,
  database, dns, forgejo, jellyfin, mcp_vm, otel). wotan does not: it sets
  `services.tailscale.enable = true` in `hosts/wotan/default.nix`.
- Tailnet traffic is very low. otel received about 155 MB over `tailscale0`
  in 7 days from a source not yet identified (A.3).
- wotan's `agent` user cannot reach private ranges: verify as `amadeus`.

## Decisions (made)

- **Target is `mozart409`**, the user's personal network, for their own
  clients only.
- **All hosts join** with a per-host cert. There is **no `unsafe_routes`
  LAN gateway.** Consequence: anything not joined becomes unreachable
  off-site once Tailscale's `192.168.2.0/24` route goes.
- Nebula is UDP-only, on those ports. There is no HTTPS relay fallback like
  Tailscale's DERP, so networks that block UDP 4343 cannot connect.
- No exit node is needed (none is declared today), so there is no WireGuard
  hub in this plan. A WireGuard hub is only an optional later break-glass
  idea; the repo has no WireGuard config today.
- **Deploys stay plain LAN SSH.** Root `flake.nix` (`targetHost`) picks the
  FQDN and `dns` uses its raw IP. Deploys must not run through the mesh: a
  Nebula config change restarts the unit
  (`docs/nebula-nixos-deployment.md`, "restartTriggers").

## Phase A: now, independent of the migration

1. The iPhone's Tailscale key expires **2026-11-15**. Renew it or disable
   expiry in the admin console, so the phone stays usable until Phase H.
2. Export the policy from the external `tailscale-acls` repo: the only
   record of who may reach what, including the mosh UDP grant.
3. Identify the otel traffic source (~155 MB over `tailscale0` in 7 days)
   before removal (conntrack on otel, match peers against the member list).
4. Confirm the subnet router state: which node is approved for
   `192.168.2.0/24`, and whether `dns` is a standby.

## Phase B: resolvers first

PBS and pve-gigabyte reportedly resolve only through `100.100.100.100`,
which sits under the 03:00 backups.

1. Do B.2 of the existing todos: point both at `dns` (`192.168.2.145`) with
   a public fallback. Steps in
   [`pve-gigabyte-off-tailscale.md`](./pve-gigabyte-off-tailscale.md) and
   [`dns-tailscale-spof.md`](./dns-tailscale-spof.md); not repeated here.
2. Move the MCP PBS URL off `.ts.net`: `hosts/mcp_vm/configuration.nix`,
   `host = "https://pbs.dropbear-butterfly.ts.net/"`, to the PBS
   `.homelab.internal` name (it needs a step-ca cert there; check first).

## Phase C: shared Nebula module

Write `modules/nebula.nix`, generalised from `hosts/wotan/nebula.nix`, and
keep wotan's own file for its second network. Each joining host needs:

1. An entry in `services/nebula/tenants.nix` (lighthouse repo) in the
   `.4`-`.99` server range.
2. A cert signed offline with group `servers`
   (`nebula-cert sign -name <host> -networks 172.16.20.N/24 -groups servers`).
   Groups are fixed at signing.
3. `secrets/nebula-mozart409-<host>.age` plus a rule in
   `secrets/agenix-rules.nix`.
4. The CA and the host cert committed (public), as for wotan.

Must-haves:

- **Coexistence.** While a host runs both overlays, keep wotan's outbound
  rule of no general UDP (`hosts/wotan/nebula.nix`, comment above
  `firewall.outbound`: Tailscale routes through Nebula and stalls past the
  1300 MTU) except DNS. Mosh over Nebula waits until Tailscale is gone on
  that path.
- **Firewall.** Do not add Nebula tun devices to `trustedInterfaces`. Use
  Nebula rules plus `networking.firewall.interfaces.<dev>.allowedTCPPorts`.
  Both layers must allow a port.
- **Do not copy `requires = ["agenix.service"]`** from
  `docs/nebula-nixos-deployment.md`. `modules/tailscale.nix` (comment in
  `tailscaled-autoconnect`) documents why that makes a unit unstartable:
  agenix is an activation script here, not a unit.
- **Nebula 1.12.** Quote group values; a pre-existing `tun.dev` stops
  startup; `listen.host` defaults to `0.0.0.0` in the module, so use `::`
  for IPv6 paths; set `punchy` explicitly; `nebula ctl` may need
  `local_api.control.socket` under the NixOS unit (untested). Interface
  names are limited to 15 characters (`nebula-mz409`).
- **Reverse path.** Set `networking.firewall.checkReversePath` explicitly:
  removing the Tailscale module removes its `"loose"` setting.

## Phase D: pilot on `dns`

`dns` joins first, since every client needs its resolver.

1. Join `dns` per Phase C. Prove wotan to `dns` over `mozart409` with real
   traffic (SSH, a DNS query), and check direct versus relayed in the
   Nebula log.
2. wotan routes overlay DNS only on `nebula-amartum` today
   (`ExecStartPost` in `hosts/wotan/nebula.nix`). Add nothing that changes
   LAN resolution at home.
3. Add `172.16.20.0/24` to unbound's `access-control`
   (`hosts/dns/configuration.nix`).
4. DNS design: add a per-host overlay IP to `lib/hosts.nix`, and serve
   overlay answers for `*.homelab.internal` to overlay clients through an
   unbound view keyed on source `172.16.20.0/24`. LAN clients keep
   `192.168.2.x`. Fleet-to-fleet and wotan-at-home traffic stays on the LAN.
5. step-ca issuance and validation stay on the LAN. Check that ACME still
   works after the view is live (a renewal on one host).

## Phase E: roll out to the fleet

One host at a time: ca, database, forgejo, jellyfin, agents, mcp, otel,
containers. Per host: Phase C, deploy over LAN SSH, confirm the handshake
and a port test from wotan.

Ports for off-site clients (TCP; add ICMP, and mosh UDP 60000-61000 later;
verify against each host's firewall before writing rules):

- ca 22, 443, 8443; database 22, 443, 5432; dns 22, 53 (also UDP), 443
- forgejo 22, 443, 2222; jellyfin 22, 443, 8096; agents 22
- mcp, otel, containers 22, 443

Postgres `pg_hba` (`hosts/database/configuration.nix`) has no `172.16/12`
entry: it lists `10.0.0.0/8`, `192.168.0.0/16` and `100.64.0.0/10`. Add one
only if off-site Postgres is wanted. Membership groups are fixed at signing,
so choose them before signing.

## Phase F: non-fleet nodes (open decision for the user)

Decide each individually: join with its own cert, or accept LAN-only.

- pve-gigabyte, pbs, the pocketid LXC, immich, homelab-unifi
  ([`unifi-os-server-vm.md`](./unifi-os-server-vm.md)), Home Assistant.
- Running Nebula on HAOS is unverified.
- Other LAN devices become LAN-only.
- Pocket-ID must be reachable by every OIDC client, so it must join or be
  otherwise reachable. That constrains Phase G.

No recommendation beyond: join what must be reachable off-site.

## Phase G: Pocket-ID issuer (hardest item)

The issuer `https://pocketid.dropbear-butterfly.ts.net` must become
`https://pocketid.homelab.internal`. `lib/hosts.nix` (comment above the
pocketid entry) says the issuer URL is part of token identity, so this is a
migration, not a rename. It needs:

1. A new Pocket-ID cert valid for the `.homelab.internal` name (step-ca).
2. The 5 consumers changed:
   - `hosts/containers/countdown/default.nix` (`oidcIssuer`)
   - `hosts/containers/hindsight/default.nix` (`oidcIssuerUrl`, `loginURL`,
     `redeemURL`, `profileURL`, `oidc-jwks-url`)
   - `hosts/containers/romm/default.nix` (`OIDC_SERVER_APPLICATION_URL`)
   - `hosts/otel/configuration.nix` (`auth_url`, `token_url`, `api_url`)
   - `hosts/jellyfin/hofvarpnir.nix` (`OIDC_ISSUER`)
3. Mutable clients redone by hand: the Forgejo auth source, and Jellyfin SSO
   (its settings live in mutable state, `AGENTS.md`, "OpenID Endpoint").
4. A login-linking test per service: an existing account must link, not
   duplicate.

Must complete before the phone cuts over: `.ts.net` will not resolve
without Tailscale.

## Phase H: iPhone

The MacBook is the user's call (offline, key expired). iOS runs one VPN at
a time, so the phone cannot use Tailscale and Nebula together. Keep both
apps and toggle during the test, with On Demand off.

1. Install Mobile Nebula 0.12.1 (iOS 15+, free, no account).
2. Import YAML with `pki.ca` only, so the phone generates its own key.
   Lighthouses at `lighthouse-{a,b,c}.oyabu.cc:4343`. `relay.relays` and
   `punchy.respond` have no UI and need YAML.
3. Set `mobile_nebula.dns_resolvers` to `dns`'s overlay IP and
   `match_domains: ["homelab.internal"]`. DNS lookup mode: Both.
4. Share the public key out and stay on that screen until the cert is
   loaded: the keypair is regenerated when the config page reopens.
5. Sign it (`.101` to be checked against `tenants.nix`; `-ip` is
   deprecated; guide:
   https://nebula.defined.net/docs/guides/sign-certificates-with-public-keys/):

       nebula-cert sign -in-pub device.pub -name iphone \
         -networks 172.16.20.101/24 -groups mobile,admin -duration 8760h

6. The phone's inbound is ICMP only. Servers must allow group `mobile`.
   The phone needs the step-ca root installed and trusted.
7. Test on cellular early. mobile_nebula issue #355 reports that
   "Connected" reflects only the OS process, not a working tunnel
   (https://github.com/DefinedNet/mobile_nebula/issues/355).

Known limits, from reading the source; **not tested on a device**:
disconnecting in the app turns Always-on off and reconnecting does not
restore it; no SSID exception; no iOS full tunnel (nebula-docs #401); no
expiry notification, so track the phone cert yourself.

## Phase I: remove Tailscale, one host at a time

Per host: deploy over LAN, reboot once, then the next host.

1. **ts.net Caddy vhosts**, together with their socket `BindPaths` and
   `permitCertUid`. `BindPaths` has no `-` prefix on 6 hosts (dns, ca,
   database, forgejo, jellyfin, mcp_vm), so a missing socket should stop
   Caddy and its `*.homelab.internal` vhosts (inferred from systemd
   behaviour). Remove vhost and bind together. Includes the
   `homelab-mcp` vhost in `hosts/mcp_vm/axon-gateway/default.nix`.
2. The `ts.net.` forward in `modules/dns-client-cache.nix` (`name =
   "ts.net."`, `forward-addr`), plus `ts.net.` in `domain-insecure`.
3. `100.64.0.0/10` source ACLs: `hosts/dns/configuration.nix`
   (`access-control`), `hosts/database/configuration.nix` (`pg_hba`),
   `modules/wotan/agent-user.nix` (tailnet CGNAT entry).
4. `trustedInterfaces = ["tailscale0"]` on 8 hosts (dns, ca, containers,
   database, forgejo, jellyfin, mcp_vm, otel; not agents or wotan).
5. step-ca's `.ts.net` dnsName (`hosts/ca/configuration.nix`).
6. Caddy ordering on `tailscaled.service`: `hosts/mcp_vm/configuration.nix`
   (`after`/`wants`), `hosts/containers/countdown/default.nix` (`after`).
7. agents' UDP port (`hosts/agents/configuration.nix`,
   `config.services.tailscale.port`).
8. The rewrite in `hosts/agents/zones.nix` (the two
   `homelab-forgejo.dropbear-butterfly.ts.net` entries).
9. The `deployNet == "tailscale"` branch in root `flake.nix`
   (`targetHost`, `hostAddrs`).
10. **The module, last, with a trap.** `lib/hosts.nix` defines `fleet` as
    the hosts with a `tailscale` attribute. Re-key that marker first (for
    example to a `colmena = true` flag), or every Colmena target fails
    evaluation.
11. wotan: drop the assertion (`hosts/wotan/default.nix`, "must not enable
    Tailscale SSH") and `services.tailscale.enable`. Widen wotan's Nebula
    outbound as its comment says. Open mosh UDP 60000-61000
    (`modules/server.nix`, `programs.mosh`) on the overlay interface and
    rewrite its comment.
12. Nodes outside this repo, by hand: pve-gigabyte (Phase B of its todo),
    pbs, the pocketid LXC, immich, homelab-unifi, Home Assistant (the active
    subnet router, so off-site LAN access ends here), the iPhone and the
    MacBook.
13. Retire `tailscale-auth-key.age` and its rule in
    `secrets/agenix-rules.nix`. Delete the tailnet last.
14. After a reboot on each host, check `ip rule`, routing table 52 and the
    `ts-*` iptables chains are clean.

## Risks and gaps

- **Shared lighthouses.** Shared with the business network and managed in
  another repo. A separate CA means no trust crossover, but maintenance
  there affects new connections here.
- **Cert expiry.** Nothing tracks it; add alerts (see
  [`nebula-clients.md`](./nebula-clients.md)). Revocation means
  `pki.blocklist` on every host.
- **No central ACL.** Access is per-host firewall rules; groups are fixed
  in certs.
- **UDP-blocked networks** cannot connect, with no fallback.
- **Routing interactions.** Tailscale's table 52 is consulted before main,
  so an accepted subnet route beats a Nebula route. This is from source
  reading and untested: test on one host first (Phase D).
- **Not audited.** Encrypted values may hold `.ts.net` names
  (`iac/secrets.sops.env`, agenix env files, the `.sops.env` files of
  exported Rust projects). So may runtime state: dashboard links, service
  settings stored outside Nix. Check these before Phase I.

## Stale docs to fix at the end (not touched here)

- `docs/nebula-nixos-deployment.md`: proposes its own CA, `10.42.0.0/16` and
  its own lighthouse, and says not implemented.
- `AGENTS.md`, "Tailscale MagicDNS Does Not Resolve Between Homelab VMs" and
  the `trustedInterfaces`/ACL section (about lines 368-375 and 384-416).
  Also "Adding New Hosts Checklist" (the `tailscale` registry attribute) and
  the agenix pitfall that says every host runs Tailscale.
- `todo/nebula-clients.md` (about line 151): the sample firewall block is
  `outbound any`, but the live config limits outbound.
- Out of scope, already dead: Harbor image references in
  `rust/services/iac`, and the retired `hosts/cache` and `hosts/zeroclaw`.
