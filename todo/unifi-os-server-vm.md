# Replace the NixOS UniFi controller with UniFi OS Server in a Debian VM

Replace the deprecated NixOS-hosted UniFi Network Application on `unifi`
(`192.168.2.142`) with UniFi OS Server, installed by hand in a small Debian 13
VM. UniFi OS Server is a multi-service appliance stack on podman; keep it in
its supported environment rather than trying to model it as NixOS services.

The old `docs/archive/unifi/host-configuration.nix` ran the legacy Network
Application (`pkgs.unifi`). This migration is for the newer UniFi OS Server,
not a repackaging of that NixOS service.

## Status

**2026-10-28: old controller gone, new one not installed yet.** The NixOS
controller VM was decommissioned in the repo on 2026-10-21 (config in
`docs/archive/unifi/`; registry entry, DNS records, monitoring, dashboard
link, README row and the `unifi_vm` tofu resource removed), and the VM itself
(Proxmox vm 4327) has since been deleted in Proxmox. The controller config was
backed up before the VM was destroyed. Next: create the Debian VM, install
UniFi OS Server, restore that backup. There is no old controller to fall back
to, so the rollback steps below are moot.

## Target and decisions

- **Decided 2026-10-28: a Debian 13 VM with a hand install, not the Proxmox
  Community Scripts `unifi-os-server` LXC.** A review of that script (ProxmoxVE
  `502bd98c`, community-scripts/core `a14f2d45`) found:
  - It always creates a **privileged** CT.
  - It appends `lxc.cgroup2.devices.allow: a` and an empty `lxc.cap.drop:` to every privileged CT. Root in the CT can then reach the host's block devices and gets back the capabilities PVE drops, so it is close to root on pve-gigabyte.
  - It downloads and runs the ~786 MB closed-source installer with no checksum check.
  - It deletes the CT's root password and auto-logs the console in as root.
  - Its engine is unsigned `curl | source` from `main`.

  A VM gives a real trust boundary, and podman runs there without nesting or
  device workarounds.
- Size: 2 vCPU, 4096 MB RAM, ~32 GB disk (UniFi's own profile is 2/4 GB/20 GB).
  Check headroom first:
  [`pve-gigabyte-memory-oversubscription.md`](./pve-gigabyte-memory-oversubscription.md).
  The old VM's 2560 MB is freed.
- Declare the VM in `iac/main.tf` like the other guests (cloud-init
  `user_account` with the wotan key, `vmbr0`, guest agent, `startup` order 5).
  `debian_cloud_image` is still bookworm. Add a trixie (Debian 13) generic
  cloud image download with its sha512 instead of bumping the shared one,
  because the NixOS guests were installed from it.
- `192.168.2.142` is free now that the VM is gone. Reusing it (and
  `unifi.homelab.internal`) keeps the devices' inform host stable, so devices
  reconnect without `set-inform`.
- The UI port is `11443` (the old NixOS proxy targeted `8443`). Devices use
  TCP `8080` (inform), UDP `3478` (STUN) and UDP `10001`/`10003` (discovery).
  Confirm the full set with `ss -tulpn` after install and only open what is
  used.
- None of the old NixOS host integrations carry over: Caddy, node exporter,
  step-ca trust and the host firewall all came from the archived
  `docs/archive/unifi/host-configuration.nix`. No Tailscale on the new VM: the
  fleet is moving off it (see `pve-gigabyte-off-tailscale.md`).

## Phase 0 — Prepare

- [ ] Check Proxmox memory/storage headroom for a 4 GB guest.
- [x] Take a backup of the UniFi Network Application before the VM was
  destroyed (done before 2026-10-28).
- [x] ~~Decide how to retain the old controller as a rollback~~ moot: the VM
  is deleted; the backup is the only rollback.
- [ ] Choose monitoring for a non-NixOS guest: `prometheus-node-exporter` from
  Debian apt plus a scrape job, and/or only a blackbox probe of the UI.

## Phase 1 — Provision and install

- [ ] Add the trixie cloud image and a `unifi_vm` resource to `iac/main.tf`.
  Use a static `ip_config` of `192.168.2.142/24` (or a DHCP reservation), then
  `just iac-plan` and `just iac-apply`.
- [ ] In the VM: `apt install podman slirp4netns uidmap`, plus
  `qemu-guest-agent`, `unattended-upgrades` and (optionally)
  `prometheus-node-exporter`. Give root a password; SSH key-only.
- [ ] Download the UniFi OS Server installer for `linux-x64` from Ubiquiti
  (`https://fw-update.ui.com/api/firmware-latest`, product
  `unifi-os-server`). **Verify its `sha256_checksum` from that API before
  running it.** v5.1.42 x64 is
  `f6111e9396a42c74016f5dde9b01fbef486a6fe69efe137935e6e38b7c22f94d`. Then run
  it as root and answer its prompt by hand.
- [ ] Confirm its services survive a VM reboot.
- [ ] Host firewall (nftables, or the PVE firewall on net0): allow the UI,
  inform, STUN and discovery ports from the LAN/device networks only.
- [ ] Confirm the UI is reachable at `https://192.168.2.142:11443` from the LAN.

## Phase 2 — Restore and cut over

- [ ] Restore the UniFi Network Application backup into UniFi OS Server;
  confirm sites, settings, and device inventory.
- [ ] Confirm the devices reconnect (they will if the inform host/IP is the
  same); otherwise re-point them at the new controller (`set-inform`) and check
  representative access points/switches stay manageable.
- [x] ~~Keep the old controller available during adoption; stop the old VM
  before reusing `192.168.2.142`~~ moot: the VM is deleted.
- [ ] Confirm adoption, STUN, and discovery traffic works from the device
  network.
- [ ] Verify backup/restore and the documented UniFi OS Server update procedure.

## After the VM is up — repo work

- [ ] Re-add a `unifi` entry (`ip = "192.168.2.142"`,
  `zones = ["homelab.internal"]`) to `infra/lib/hosts.nix`, which brings back
  the `unifi.homelab.internal` A/PTR records on `dns`. It has no NixOS config,
  so keep it out of `hostAddrs` and `colmenaHive`, like `pocketid`.
- [ ] A TLS front for `unifi.homelab.internal`: Caddy with a step-ca cert on an
  existing NixOS host, reverse-proxying to the VM's `:11443` (UniFi OS's own
  cert is self-signed, so `tls_insecure_skip_verify` on the upstream).
- [ ] Monitoring: a blackbox probe of the UI in `hosts/otel/blackbox.nix`, and a
  `unifi-node` scrape job if the node exporter is installed.
- [ ] The UniFi link in `hosts/containers/homelab-dashboard/default.nix` and a
  row in `infra/README.md`'s host inventory.
- [ ] Add the VM to the PBS backup job.
- [ ] Run `just fmt` and evaluate the touched hosts.

## Phase 3 — Remove obsolete NixOS host configuration

Done on 2026-10-21 (see `docs/archive/unifi/README.md`), verified 2026-10-28:

- [x] `unifi` removed from `flake.nix`; `hosts/unifi/` moved to
  `docs/archive/unifi/`.
- [x] `unifi_vm` and its output removed from `iac/main.tf`.
- [x] The `unifi` registry entry in `lib/hosts.nix` (and so its A/PTR records)
  removed.
- [x] The `unifi-node` scrape job and the `homelab-unifi` blackbox probe on
  `otel` removed. (uptime-forge was retired on 2026-09-12, nothing to update
  there.)
- [x] Removed the old `hostUnifi` SSH recipient from
  `secrets/agenix-rules.nix`.
- [x] The `infra/README.md` row and the dashboard link removed. The host list
  in the archived hermes souls (`docs/archive/hermes/souls/user.md`) stays as
  history.
- [x] The old VM deleted in Proxmox (before 2026-10-28).

## Verification

- UniFi OS Server UI works at the final URL with the expected TLS behavior.
- Existing sites and representative devices are present and online; devices
  remain manageable after a controller/VM reboot.
- Required ports work from the appropriate LAN segments, and unused ports are
  not exposed.
- Chosen monitoring and PBS backup paths cover the new VM, and a restore path
  is documented.
- DNS, dashboard, and monitoring target the new endpoint.
