# Homelab off Tailscale, onto the Nebula network mozart409

Move the homelab hosts and the user's own clients from Tailscale to the
Nebula network `mozart409` (172.16.20.0/24, UDP 4343, its own CA), then
delete the tailnet. The repo side is done and deployed and every node is off
Tailscale; only deleting the tailnet remains (see the status line). The
`amartum` network (172.16.10.0/24, UDP 4242, separate CA) is business and
never carries homelab traffic; wotan stays on both and its `amartum` uses
do not change.

**Status 2026-11-11: complete. Every node is off Tailscale and the tailnet is
deleted.** The "What exists" section below is a point-in-time observation
from a Tailscale snapshot and Prometheus on 2026-11-06 and describes the state
before this work.

DONE and deployed:

- The repo side (commits `fdc48272`, `85e014f4`): Phase C (`modules/nebula.nix`),
  Phase D (`dns` is `.4`, live since 2026-11-07), Phase E, Phase G (2026-11-06) and
  Phase I (no Tailscale left in the config). Registry marker is `colmena = true;`
  in `lib/hosts.nix`; deploys use `<host>.homelab.internal` (`dns` by raw IP) over
  the LAN; `DEPLOY_NET` is gone.
- Certs and keys for all 8 fleet hosts (commits `73bfdbdb`, `827ee079`;
  `services/nebula/tenants.nix` in `~/code/nixos-ventara-ai` is committed too).
  The fleet was deployed over LAN SSH, without reboots.
- Prometheus shows `nebula@mozart409` active on all 9 hosts (`dns` plus the 8) and
  `tailscale0` gone from every fleet host. The node_exporter textfile metrics
  `tailscale_leftover_*` (`modules/tailscale-leftover-metrics.nix`, alert
  `TailscaleLeftover` in `hosts/otel/alerting.nix`, commit `8d849c1b`) read 0 on all
  9 hosts, so no reboot is needed to find leftover `ip rule` entries, table 52,
  `ts-*` chains or `tailscale0` (this closes the old items (b) and (e)).
- PBS URL: the `pbs` registry entry (192.168.2.112, `homelab.internal` only; commit
  `bb777f6b`) and the MCP URL `https://pbs.homelab.internal:8007/`. Port 8007 is
  kept on purpose: PBS serves its API there and nothing listens on 443.
- PBS: off Tailscale (`tailscale logout`, `tailscaled` disabled), `resolv.conf`
  points at the `dns` host 192.168.2.145 with 1.1.1.1 as fallback, its Caddy (it
  had only a `.ts.net` vhost) is disabled so port 80 is free. The step-ca ACME
  account is registered (directory
  `https://ca.homelab.internal:8443/acme/acme/directory`, provisioner `acme`, no
  EAB) and the cert for `pbs.homelab.internal` was issued with
  `proxmox-backup-manager acme cert order --force` (the first order needs
  `--force` because the old self-signed cert expires in centuries). It is valid to
  2027-02-08 and renewed by PBS's daily timer. The `pbs_node_status` MCP call works
  over verified TLS.
- pve-gigabyte: off Tailscale, `resolv.conf` fixed the same way. Its Caddy now
  serves only `pve-gigabyte.homelab.internal` on 443 with a step-ca cert it renews
  itself (the `.ts.net` vhost was removed); no `pvenode` ACME account is used there.
- Gotchas: unbound on `dns` needed `systemctl restart unbound` after the deploy
  before the new `pbs` record answered. `curl -I` against PVE returns 501 because
  pveproxy rejects HEAD; use a GET.

**STILL OPEN:**

1. Nothing. The tailnet was deleted on 2026-11-11. Optional later cleanup: remove
   `modules/tailscale-leftover-metrics.nix` and the `TailscaleLeftover` alert once
   every host has rebooted at least once, since a reboot clears what they count.

Decided, no work left:

- **homelab-unifi** stays LAN only, no overlay.
- **Home Assistant** no longer needs to be a tailnet node: off-site access goes
  through the `containers` host.
- **immich** (CT 104, hand-managed LXC) is LAN only by choice: no Nebula client.
  It is in the registry (`192.168.2.104`, `homelab.internal` only, commit
  `63a74119`) and is served at `https://immich.homelab.internal` by its own Caddy
  with a step-ca cert. Gotcha: a second Caddy unit, `caddy-api.service`
  (`caddy run --resume`), was also holding port 80 and made the HTTP-01 challenge
  hang; it is disabled.
- The `.ts.net` leftovers in `hosts/otel` and the dead vhosts in `hosts/cache`
  and `hosts/zeroclaw` are removed (commit `9011f310`).

Postgres stays LAN only (decided 2026-11-09): `database` allows 22 and 443 on the
overlay, never 5432.

## What exists

- Tailscale SaaS. Members: wotan, iPhone, MacBook (offline 36 days, key
  expired), homeassistant, 9 fleet hosts (agents, ca, containers, database,
  dns, forgejo, jellyfin, mcp, otel), pve-gigabyte, immich, pbs,
  homelab-unifi (offline 15 days). No exit nodes, no shared nodes, no
  Serve/Funnel on wotan. The snapshot also lists a `pocketid` node: its LXC
  (CT 102) was destroyed on 2026-11-06 and deleting the node is still open.
- Subnet route `192.168.2.0/24`: the repo says `dns` advertises it
  (`hosts/dns/configuration.nix`, `extraUpFlags`; root `flake.nix`, comment
  above `hostRegistry`), but the snapshot shows **Home Assistant** as the
  active router. Whether `dns` is an approved standby is unknown (A.2).
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
- Tailnet traffic is very low.
- Pocket ID runs on `containers` (`hosts/containers/pocket-id/default.nix`)
  with its database on `database`, and its issuer is
  `https://pocketid.homelab.internal` ([runbook](./pocket-id-lxc-to-nixos.md)).
- wotan's `agent` user cannot reach private ranges: verify as `amadeus`.

## Decisions (made)

- **Target is `mozart409`**, the user's personal network, for their own
  clients only.
- **Fleet hosts, pve-gigabyte and immich join** with a per-host cert.
  Pocket ID has no cert of its own: it arrives with `containers`.
  **Home Assistant is reached through Caddy on `containers`** (Phase F), with
  no gateway. Consequence: anything else not joined becomes unreachable
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

1. The iPhone's Tailscale key expires **2026-11-15**. Log back in with GitHub
   to refresh it, so the phone stays usable until Phase H.
2. Confirm the subnet router state: which node is approved for
   `192.168.2.0/24`, and whether `dns` is a standby.

## Phase B: resolvers first

PBS and pve-gigabyte reportedly resolve only through `100.100.100.100`,
which sits under the 03:00 backups.

1. On both, run `tailscale set --accept-dns=false` first, or Tailscale keeps
   rewriting `/etc/resolv.conf`. `*.ts.net` names stop resolving there.
2. In each web UI, set DNS to `dns` (`192.168.2.145`) with a public fallback.
   Details in
   [`pve-gigabyte-off-tailscale.md`](./pve-gigabyte-off-tailscale.md) and
   [`dns-tailscale-spof.md`](./dns-tailscale-spof.md); not repeated here.
3. Done: the MCP PBS URL is `https://pbs.homelab.internal:8007/`, and PBS has a
   step-ca cert for that name (ACME, 2026-11-10).

## Phase C: shared Nebula module

Done: `modules/nebula.nix` (`homelab.nebula`) is generalised from
`hosts/wotan/nebula.nix`; wotan keeps its own file for its second network.
Host certs go in `modules/nebula/`. Each joining host needs:

1. An entry in `services/nebula/tenants.nix` (lighthouse repo) in the
   `.4`-`.99` server range.
2. A cert with group `servers`, signed from the lighthouse repo:
   `just nebula-sign mozart409 <host> servers <pubkey>`, passing the host's
   public key so its private key stays in this repo's agenix. Members that
   flake does not build use `just nebula-onboard mozart409 <host> servers`.
   Groups are fixed at signing.
3. `secrets/nebula-mozart409-<host>.age` plus a rule in
   `secrets/agenix-rules.nix`.
4. The CA and the host cert committed (public), as for wotan. Copy the cert
   with `install -m 664`: a `cp` can leave it unreadable to other users, and
   the agent user's flake evals then fail for every host.

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

Done on 2026-11-07 except item 5: `dns` is `172.16.20.4`, and wotan reaches it
directly over the LAN (0.4 ms, handshake from `192.168.2.145:4343`). That needed
a fixed, open UDP port on the host: with the ephemeral default the handshake was
dropped and the tunnel was relayed through a lighthouse (15 ms). The home NAT
showed a different public port per lighthouse, and the iPhone on cellular does
reach `dns` only through a lighthouse relay (direct from `192.168.2.31` on Wi-Fi).

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
   The view must cover aliases too (`pocketid`, `ha` and the others in
   `lib/hosts.nix`), since those are the names off-site clients use. Fleet hosts must keep
   querying `dns` over the LAN: Pocket ID connects to
   `database.homelab.internal`, `pg_hba` has no `172.16/12` entry, and an
   overlay answer there would break every login.
5. step-ca issuance and validation stay on the LAN. Check that ACME still
   works after the view is live (a renewal on one host).

## Phase E: roll out to the fleet

**Repo side done 2026-11-09, certs pending.** `homelab.nebula` is enabled on ca
(.5), database (.6), forgejo (.7), jellyfin (.8), agents (.9), mcp (.10), otel
(.11) and containers (.12); the overlay IPs are in `lib/hosts.nix`. Inbound TCP
as built: ca 22 8443; database 22 443 (never 5432); forgejo 22 443 2222;
jellyfin 22 443 8096; agents 22; mcp, otel, containers 22 443. New option
`allowMosh` (default true) opens UDP 60000-61000 on the overlay interface.
Nebula outbound is fully open on the module and on wotan. The port list below is
the original plan, kept as written.

### Per host to finish

For each of ca, database, forgejo, jellyfin, agents, mcp, otel, containers:

1. In `~/code/nixos-ventara-ai`, add the host's overlay IP (`.5`-`.12`) to the
   hosts section of `services/nebula/tenants.nix`, next to
   `dns = "172.16.20.4"`.
2. Add a rule `nebula-mozart409-<host>.age` to `secrets/agenix-rules.nix` here
   (needed before the key can be minted and stored).
3. Sign: `just nebula-sign mozart409 <host> servers <pubkey>`, or without the
   pubkey to mint and store the key.
4. Copy the cert to `modules/nebula/mozart409-<host>.crt` (`install -m 664`) and
   the key to `secrets/nebula-mozart409-<host>.age`; `git add` both.
5. Eval the host (`nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`),
   then the user deploys over LAN SSH, one host at a time, and checks the
   handshake and a port test from wotan.

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

## Phase F: non-fleet nodes

Decided 2026-11-06:

- **Join with their own cert:** pve-gigabyte and immich.
- **Home Assistant, through `containers`:** Caddy there already proxies
  `ha.homelab.internal` to port 8123 (`hosts/containers/configuration.nix`),
  so the overlay answer for `ha` (D.4) is enough. No gateway and no
  `unsafe_routes`. HAOS does not join: it could only run Nebula through an
  unofficial add-on (`mr-ransel/addon-nebula`: manual install, no releases,
  Nebula version unconfirmed, and `mozart409` certs are v2).
- **LAN-only:** pbs, homelab-unifi
  ([`unifi-os-server-vm.md`](./unifi-os-server-vm.md)) and other LAN devices.

Off-site, Home Assistant is reachable only as `ha.homelab.internal` on port
8123, and only while `containers` is up. This path is untested off-site
(Phase H tests it).

## Phase G: Pocket-ID issuer (done 2026-11-06)

The issuer moved to `https://pocketid.homelab.internal` with the service, and
every consumer was switched, so this no longer blocks anything here. Details
and the remaining open items are in
[`pocket-id-lxc-to-nixos.md`](./pocket-id-lxc-to-nixos.md). Passkeys are bound
to that name, so moving to Nebula does not invalidate them as long as the name
stays.

## Phase H: iPhone

Joined on 2026-11-07 as `.101`: wotan pings it, and it reaches `dns` by name
over HTTPS. Step 7 is still open beyond `dns`, since the other hosts must join
first.

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
5. Register `.101` in `tenants.nix` (free on 2026-11-06), then sign it
   (`-ip` is deprecated; guide:
   https://nebula.defined.net/docs/guides/sign-certificates-with-public-keys/):

       nebula-cert sign -in-pub device.pub -name iphone \
         -networks 172.16.20.101/24 -groups mobile,admin -duration 8760h

6. The phone's inbound is ICMP only. Servers must allow group `mobile`.
   The phone needs the step-ca root installed and trusted.
7. Test on cellular early, including a Pocket ID login and Home Assistant
   (web UI and iOS app, whose server URL must be `https://ha.homelab.internal`).
   Both need `containers` on the overlay and the D.4 view. mobile_nebula
   issue #355 reports that "Connected" reflects only the OS process, not a
   working tunnel (https://github.com/DefinedNet/mobile_nebula/issues/355).

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
   Done 2026-11-09: vhosts, `BindPaths` and `permitCertUid` removed; `ca` no longer runs Caddy (only step-ca on 8443).
2. The `ts.net.` forward in `modules/dns-client-cache.nix` (`name =
   "ts.net."`, `forward-addr`), plus `ts.net.` in `domain-insecure`.
   Done 2026-11-09.
3. `100.64.0.0/10` source ACLs: `hosts/dns/configuration.nix`
   (`access-control`), `hosts/database/configuration.nix` (`pg_hba`),
   `modules/wotan/agent-user.nix` (tailnet CGNAT entry).
   Done 2026-11-09 (unbound, `pg_hba`, wotan agent-user).
4. `trustedInterfaces = ["tailscale0"]` on 8 hosts (dns, ca, containers,
   database, forgejo, jellyfin, mcp_vm, otel; not agents or wotan). Also
   drop the `tailscale0` remark above `ACTORS_HOST` in `hosts/containers/pocket-id/default.nix`.
   Done 2026-11-09: no host trusts `tailscale0` any more.
5. step-ca's `.ts.net` dnsName (`hosts/ca/configuration.nix`).
    Done 2026-11-09.
6. Caddy ordering on `tailscaled.service`: `hosts/mcp_vm/configuration.nix`
   (`after`/`wants`), `hosts/containers/countdown/default.nix` (`after`).
   Done 2026-11-09.
7. agents' UDP port (`hosts/agents/configuration.nix`,
   `config.services.tailscale.port`).
   Done 2026-11-09.
8. The rewrite in `hosts/agents/zones.nix` (the two
   `homelab-forgejo.dropbear-butterfly.ts.net` entries).
   Done 2026-11-09.
9. The `deployNet == "tailscale"` branch in root `flake.nix`
   (`targetHost`, `hostAddrs`).
   Done 2026-11-09: `DEPLOY_NET`/`deployNet` is gone from `flake.nix`.
10. **The module, last, with a trap.** `lib/hosts.nix` defines `fleet` as
    the hosts with a `tailscale` attribute. Re-key that marker first (for
    example to a `colmena = true` flag), or every Colmena target fails
    evaluation.
    Done 2026-11-09: the marker is `colmena = true;`; `modules/tailscale.nix` is deleted.
11. wotan: drop the assertion (`hosts/wotan/default.nix`, "must not enable
    Tailscale SSH") and `services.tailscale.enable`. Widen wotan's Nebula
    outbound as its comment says. Open mosh UDP 60000-61000
    (`modules/server.nix`, `programs.mosh`) on the overlay interface and
    rewrite its comment.
    Done 2026-11-09: wotan no longer runs Tailscale; its Nebula outbound is fully open; mosh UDP is `allowMosh` on the overlay interface.
12. Nodes outside this repo, by hand: pve-gigabyte (Phase B of its todo),
    pbs, immich, homelab-unifi, Home Assistant (the active
    subnet router, so off-site LAN access ends here), the iPhone and the
    MacBook.
    Done 2026-11-10 except immich (still on the tailnet) and the tailnet deletion, see the status line.
13. Retire `tailscale-auth-key.age` and its rule in
    `secrets/agenix-rules.nix`. Delete the tailnet last.
    Config part done 2026-11-09 (`secrets/tailscale-auth-key.age` and its rule are deleted). OPEN: delete the tailnet last.
14. After a reboot on each host, check `ip rule`, routing table 52 and the
    `ts-*` iptables chains are clean.
    OPEN: after the first deploy and reboot of each host.

## Risks and gaps

- **Shared lighthouses.** Shared with the business network and managed in
  another repo. A separate CA means no trust crossover, but maintenance
  there affects new connections here.
- **`containers` carries off-site logins and Home Assistant.** Pocket ID and
  the `ha` proxy both run there, and Pocket ID needs `database` over the LAN.
  A Nebula restart on `containers` interrupts both for off-site clients.
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
- `infra/AGENTS.md`: done 2026-11-09 (the MagicDNS and ACL sections became
  "Nebula overlay: reaching a host"; checklist and agenix pitfall fixed).
- `todo/nebula-clients.md` (about line 151): the sample firewall block is
  `outbound any`, but the live config limits outbound.
- Out of scope, already dead: Harbor image references in
  `rust/services/iac`, and the retired `hosts/cache` and `hosts/zeroclaw`.
