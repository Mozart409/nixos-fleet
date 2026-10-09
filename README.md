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
| `database` | 192.168.2.134 | `database` | PostgreSQL 18 + pgbouncer, multi-tenant (tofu state, forgejo, harbor, romm, hofvarpnir); `postgresqlBackup` |
| `otel` | 192.168.2.135 | `monitoring` | Observability stack: Prometheus, Grafana, Loki, Tempo |
| `unifi` | 192.168.2.142 | `unifi` | UniFi Network Controller |
| `dns` | 192.168.2.145 | `dns` | Unbound recursive DNS + authoritative `homelab.local` zone (A + PTR) |
| `containers` | 192.168.2.149 | `containers` | Podman host: Open WebUI, axon-gateway, SearXNG, RomM, homelab-dashboard, Multica (backend + web) |
| `mcp` | 192.168.2.152 | `mcp` | MCP servers from the `homelab-mcp-servers` monorepo (pbs, pg, prom, loki, ha) as hardened systemd units |
| `ca` | 192.168.2.160 | `security`, `ca` | step-ca internal Certificate Authority (ACME for `*.homelab.local`) |
| `fleet` | 192.168.2.164 | `security`, `fleet` | Fleet osquery management server (MySQL + Redis) |
| `harbor` | 192.168.2.174 | `registry`, `harbor` | Harbor container registry (OIDC, Postgres on `database`) |
| `forgejo` | 192.168.2.178 | `forgejo`, `git` | Forgejo git forge (Postgres on `database`, SSH on :2222) |
| `jellyfin` | 192.168.2.180 | `media`, `jellyfin` | Jellyfin + SSO-Auth plugin, ZFS `mediapool`, hofvarpnir container |
| `agents` | 192.168.2.190 | `ai`, `agents` | Agent platform: Multica daemons per trust zone (microVMs); successor to `development`/`hermes` |

#### `development` — the retired agent workstation (gone 2026-10-06)

`development`, `hermes` and `zeroclaw` were all decommissioned on 2026-10-06,
so no live host imports `modules/coding-harness.nix` any more. Their successor
is `agents` (2026-10-07), which `infra/scripts/eval-touched-hosts.sh` now
evaluates for module changes. Until its zones import the harness,
`coding-harness.nix`, `claude-permissions*.nix` and `herdr.nix` are still only
syntax-checked.

Retained for reference, describing what the host was:

`development` served nothing: no Caddy vhost, no
`homelab.local` service, only the node exporter on :9100 and SSH. It is a
headless box for driving LLM coding agents by hand over SSH/tmux, and it is the
only host that imports `modules/coding-harness.nix` + `modules/herdr.nix`
together:

- **Agents**: `claude-code` and `opencode` (plus `bun`/`nodejs`, which opencode
  needs to bootstrap its global plugins), with the usual CLI kit — neovim,
  lazygit, ripgrep, fd, fzf, delta, bat, eza, httpie, jq/yq, tmux.
- **MCP wiring**: `coding-harness-config` (a oneshot as `amadeus`) deep-merges
  the axon-gateway MCP server into `~/.claude.json` and
  `~/.config/opencode/opencode.jsonc` with `jq`, so Nix owns those keys without
  clobbering each tool's live session state. The bearer token is never baked
  into the configs — they reference `$AXON_GATEWAY_TOKEN`, which
  `environment.interactiveShellInit` sources from the agenix secret into every
  interactive login shell.
- **Provider key**: `development-opencode-zen-key.age`, merged into opencode's
  `auth.json`. Deliberately a per-host key — `hermes` has its own
  `hermes-opencode-zen-key.age` so a leak is contained and revocation is
  per-host.
- **herdr** (`v0.7.5`, pinned as a flake input) is installed with its
  opencode + claude integrations as a user service; `moshi-hook` pairs the iOS
  companion app from `moshi-device-id.age` and runs its hook daemon. The moshi
  units run in **both** the `agent` and `amadeus` user managers — one daemon,
  pairing and socket per login, so a notification reaches the phone whichever
  account raised it. Both need `linger = true`, which the modules set.
- **Podman** is available for experiments, with `podman+` in
  `trustedInterfaces` so containers on any per-experiment bridge can reach
  aardvark-dns.
- **Disko** pins the OS disk by `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`
  — the VM also has a 4 MB cloud-init drive on the ATA bus, so `/dev/sdX` is not
  stable and the default `/dev/sda` could target the wrong disk during install.

Sizing (4 GB RAM / 256 GB disk) is deliberate and documented in `iac/main.tf`:
opencode alone peaked at ~570 MB RSS on the hand-built reference box and `/nix`
took 21 GB there, before Claude Code and the bun-hosted plugins.

### Desktop (not in the Colmena hive)

| Host | Role |
|------|------|
| `wotan` | My workstation: Hyprland, NVIDIA/CUDA, local vLLM. Deploys only itself (`just switch-wotan`), no inbound SSH. See `hosts/wotan/README.md` |

### Provisioned by IaC, not in the Colmena hive

| Host | IP | Status |
|------|------|------|
| `cache` | 192.168.2.175 | Garage S3 + Attic Nix binary cache. VM and `nixosConfigurations.cache` exist; the `colmenaHive` entry is commented out, so it is not deployed by `colmena apply`. |
| `scratchpad` | 192.168.2.185 | Fedora 44 cloud VM for ad-hoc testing. Not NixOS — no flake entry, no Colmena node. |

### Dormant configs (present in the repo, not deployed)

- `buildbot-master` / `buildbot-worker-1` — Buildbot CI was removed
  (`refactor(buildbot): remove buildbot`). The VM resources and Colmena nodes
  are gone; only `hosts/` dirs and `nixosConfigurations` entries linger.
- `k3s-server-1` / `k3s-agent-1` — commented out in `flake.nix` and
  `iac/main.tf`.
- `rpi4-1` — commented out in the hive. `rpi4` / `rpi5` remain as SD-image
  builds (`just rpi-build rpi4`).
- `minimal` — bootstrap config used by `just deploy-minimal`, not a host.

All active hosts run Tailscale and a Caddy front end, serving both Tailscale TLS
(`*.dropbear-butterfly.ts.net`) and step-ca certs for `*.homelab.local`.
Note that MagicDNS names do **not** resolve between homelab VMs — use
`<host>.homelab.local` for service-to-service URLs (see AGENTS.md §6).

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
NixOS config (`harbor`, for instance, boots Debian on .166 but runs on .174).

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
- Adding a host means touching `flake.nix` (`hostAddrs`,
  `nixosConfigurations`, `colmenaHive`), `iac/main.tf` (VM + output),
  `hosts/dns/configuration.nix` (A + PTR), and `hosts/otel/configuration.nix`
  (Prometheus scrape). Checklist in AGENTS.md §5.
- Some services are not restarted by `colmena apply` — `hermes-agent` after
  SOUL/skill/config changes, `podman-axon-gateway` after config.toml edits,
  Caddy after adding several vhosts at once. Post-deploy checklist in AGENTS.md §3.
