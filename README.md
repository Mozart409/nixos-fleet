# infra

NixOS flakes, Colmena, and OpenTofu definitions for a Proxmox homelab, plus my
desktop `wotan`. Part of the `yggdrasil` monorepo (formerly the
`pve-nixos-homelab` and `nixos-wotan` repos). The flake, `justfile` and dev
shell are at the repo root; run commands from there. Paths below are relative
to `infra/`.

VMs are provisioned on Proxmox with OpenTofu (`iac/`), installed with
nixos-anywhere + disko, and thereafter updated with Colmena. Secrets are
agenix-encrypted; internal TLS comes from a self-hosted step-ca.

## Hosts

### Active (Colmena-managed)

These are the nodes in `colmenaHive` — `just colmena-apply` targets exactly this
set. IPs are the static addresses configured in each host's NixOS config.

| Host | IP | Colmena tags | Role |
|------|------|------|------|
| `database` | 192.168.2.134 | `database` | PostgreSQL 18 + pgbouncer, multi-tenant (tofu state, forgejo, romm, hofvarpnir); `postgresqlBackup` |
| `otel` | 192.168.2.135 | `monitoring` | Observability stack: Prometheus, Grafana, Loki, Tempo |
| `dns` | 192.168.2.145 | `dns` | Unbound recursive DNS + authoritative `homelab.internal` zone (A + PTR) |
| `containers` | 192.168.2.149 | `containers` | Podman host: axon-gateway, SearXNG, RomM, homelab-dashboard, Multica (backend + web) |
| `mcp` | 192.168.2.152 | `mcp` | MCP servers from the `homelab-mcp-servers` monorepo (pbs, pg, prom, loki, ha) as hardened systemd units |
| `ca` | 192.168.2.160 | `security`, `ca` | step-ca internal Certificate Authority (ACME for `*.homelab.internal`) |
| `forgejo` | 192.168.2.178 | `forgejo`, `git` | Forgejo git forge (Postgres on `database`, SSH on :2222) |
| `jellyfin` | 192.168.2.180 | `media`, `jellyfin` | Jellyfin + SSO-Auth plugin, ZFS `mediapool`, hofvarpnir container |
| `agents` | 192.168.2.190 | `ai`, `agents` | Agent platform: Multica daemons per trust zone (microVMs); successor to `development`/`hermes` |

#### Retired agent hosts (gone 2026-10-06)

`development`, `hermes` and `zeroclaw` were all decommissioned on 2026-10-06,
so no live host imports `modules/coding-harness.nix` any more. Their successor
is `agents` (2026-10-07), which `infra/scripts/eval-touched-hosts.sh` now
evaluates for module changes. Until its zones import the harness,
`coding-harness.nix`, `claude-permissions*.nix` and `herdr.nix` are still only
syntax-checked.

The `development` and `hermes` configs are archived (2026-10-21) in
`docs/archive/development/` and `docs/archive/hermes/`, which also describe
what each host was. `zeroclaw` stays under `hosts/`, wired to nothing.

### Desktop (not in the Colmena hive)

| Host | Role |
|------|------|
| `wotan` | My workstation: Hyprland, NVIDIA/CUDA, local llama.cpp. Deploys only itself (`just switch-wotan`), no inbound SSH. See `hosts/wotan/README.md` |

### Provisioned by IaC, not in the Colmena hive

| Host | IP | Status |
|------|------|------|
| `cache` | 192.168.2.175 | Garage S3 + Attic Nix binary cache. VM and `nixosConfigurations.cache` exist; the `colmenaHive` entry is commented out, so it is not deployed by `colmena apply`. |
| `scratchpad` | 192.168.2.185 | Fedora 44 cloud VM for ad-hoc testing. Not NixOS — no flake entry, no Colmena node. |
| `unifi` | 192.168.2.142 | Fedora 44 VM running UniFi OS Server (installed by hand, podman); its own Caddy serves `unifi.homelab.internal` with a step-ca cert. Not NixOS. See `todo/unifi-os-server-vm.md`. |

### Dormant configs (present in the repo, not deployed)

- `buildbot-master` / `buildbot-worker-1` — Buildbot CI was removed
  (`refactor(buildbot): remove buildbot`). The VM resources and Colmena nodes
  are gone; only `hosts/` dirs and `nixosConfigurations` entries linger.
- `k3s-server-1` / `k3s-agent-1` — commented out in `flake.nix` and
  `iac/main.tf`.
- `rpi`, `rpi4-1`, `k3s-cntrl-1` — archived in `docs/archive/rpi-k3s/`.
- `minimal` — bootstrap config used by `just deploy-minimal`, not a host.

All active hosts run Tailscale and a Caddy front end, serving both Tailscale TLS
(`*.dropbear-butterfly.ts.net`) and step-ca certs for `*.homelab.internal`.
Note that MagicDNS names do **not** resolve between homelab VMs — use
`<host>.homelab.internal` for service-to-service URLs (see AGENTS.md §6).

## Quick start

### Dev shell

```
nix develop
```

Provides:
- **IaC**: `opentofu`, `tofu-ls`, `colmena`, `nixos-anywhere`, `agenix`
- **Containers**: `podman`, `podman-compose`, `podman-tui`, `dive`, `lazydocker`
- **Kubernetes**: `timoni`
- **Rust**: `cargo`, `cargo-workspaces`, `rustc`, `rust-analyzer`, `bacon`, `rainfrog`
- **Utilities**: `just`, `dprint`, `kics`, `keep-sorted`, `lefthook`, `cocogitto`, `shellcheck`, `pwgen`

`lefthook install` runs from the shell hook, wiring the pre-commit
`alejandra`/`keep-sorted`/`just --fmt`/`shellcheck` hooks and the `cog verify`
commit-msg hook.

### Nix workflows

- Format: `just fmt`
- Check flake & hosts: `just nixos-check`
- Dry build a host: `just nixos-test <host>`
- Build a host via Colmena: `just colmena-build-host <host>`
- Build the whole hive: `just colmena-build`

`just nixos-check` does **not** gate the Colmena deploy — it only evaluates
`nixosConfigurations`, which omit the home-manager/nixvim layer, and skips
`colmenaHive` entirely. Before deploying a flake-input or home-manager change,
run `just colmena-build-host <host>`. See AGENTS.md §3.

### Deploy

**Config change to a running host** (the normal path):

```
just colmena-apply-host <hostname>     # or: just colmena-apply-tag <tag>
just colmena-apply                     # every node in the hive
```

**Initial install onto a bare VM** — `nixos-anywhere`, which is destructive
(disko reformats all disks, generates a new host key, breaking agenix until you
re-key):

```
just deploy-minimal <ip>        # bare VM -> minimal NixOS, then colmena
just deploy <hostname> <ip>     # bare VM -> full host config (guarded prompt)
```

Use `just deploy <host> <ip>` directly for hosts with extra disks or a static IP
(e.g. `jellyfin`) — disko only runs under nixos-anywhere, never under
`colmena apply`. See AGENTS.md §6.

Set `DEPLOY_NET=tailscale` to deploy over Tailscale hostnames instead of local IPs.

### Secrets (agenix)

Secrets live in `secrets/*.age`, with recipients declared in `secrets/agenix-rules.nix`.

- Edit a secret: `agenix -e <name>.age` from anywhere in the dev shell (it
  exports `AGENIX_RULES`); always the bare filename. Without the dev shell,
  `cd infra/secrets` first.
- Reencrypt after changing recipients: `just reencrypt`
- Fetch a new host key after a reinstall: `just get-host-key <ip>`

A user-level age identity at `~/.config/age/keys.txt` is registered as a
recipient so reencryption is passphrase-free.

### IaC (OpenTofu)

Inside `iac/` (via dev shell):

```
just iac-plan
just iac-apply
```

VM definitions live in `iac/main.tf`; state is in PostgreSQL on the `database`
host. The cloud-init `ip_config` blocks there only apply to the Debian bootstrap
image — the authoritative address for an installed host is the static IP in its
NixOS config, which can differ from the bootstrap address.

## Layout

- `../flake.nix` (repo root) – inputs, `hostAddrs`, `nixosConfigurations`, `colmenaHive`
- `hosts/` – per-host configurations (fleet + `wotan`)
- `modules/` – shared fleet modules (`common`, `disko-config`, `disko-jellyfin`,
  `tailscale`, `step-ca-trust`, `podman`, `nix-gc`, `coding-harness`,
  `herdr`, `moshi-hook`); `modules/{wotan,desktop,home}/` are the desktop's
- `lib/mkConfigs.nix` – `mkDesktop` for wotan
- `pkgs/` – third-party packaging
- `secrets/` – agenix-encrypted secrets + `agenix-rules.nix` recipient map (fleet and wotan)
- `iac/` – Proxmox VM definitions (OpenTofu)
- `k8s/timoni/` – Timoni modules
- `tests/` – nixosTest VM tests
- `docs/`, `todo/` – design plans and open work items
- `../justfile` (repo root) – task runner commands
- `AGENTS.md` – conventions, deploy checklists, and a long list of debugged
  pitfalls; read it before changing host configs

## Notes

- Keep plaintext secrets out of the repo: `iac/secrets.sops.env` (sops, `just iac-secrets`) for IaC
  credentials, agenix for everything else.
- Commits are single-line conventional commits, verified by `cog verify`; run
  `just fmt` before committing Nix changes (lefthook also enforces it).
- Adding a host means an entry in `lib/hosts.nix` (the host registry: IP,
  DNS names, tailnet name; A/PTR records, `hostAddrs` and the static address
  derive from it), `flake.nix` (`nixosConfigurations`, `colmenaHive`),
  `iac/main.tf` (VM + output) and `hosts/otel/configuration.nix` (Prometheus
  scrape). Checklist in AGENTS.md §5.
- Some services are not restarted by `colmena apply` — `hermes-agent` after
  SOUL/skill/config changes, `podman-axon-gateway` after config.toml edits,
  Caddy after adding several vhosts at once. Post-deploy checklist in AGENTS.md §3.
