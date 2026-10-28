# Replace the NixOS UniFi controller with UniFi OS Server in a Fedora VM

Replace the deprecated NixOS-hosted UniFi Network Application on `unifi`
(`192.168.2.142`) with UniFi OS Server, installed by hand in a small Fedora 44
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
backed up before the VM was destroyed. Next: create the Fedora VM, install
UniFi OS Server, restore that backup. There is no old controller to fall back
to, so the rollback steps below are moot.

## Target and decisions

- **Decided 2026-10-28: a Fedora 44 VM with a hand install (first planned as
  Debian 13), not the Proxmox
  Community Scripts `unifi-os-server` LXC.** A review of that script (ProxmoxVE
  `502bd98c`, community-scripts/core `a14f2d45`) found:
  - It always creates a **privileged** CT.
  - It appends `lxc.cgroup2.devices.allow: a` and an empty `lxc.cap.drop:` to every privileged CT. Root in the CT can then reach the host's block devices and gets back the capabilities PVE drops, so it is close to root on pve-gigabyte.
  - It downloads and runs the ~786 MB closed-source installer with no checksum check.
  - It deletes the CT's root password and auto-logs the console in as root.
  - Its engine is unsigned `curl | source` from `main`.

  A VM gives a real trust boundary, and podman runs there without nesting or
  device workarounds.
- Size: 2 vCPU, 4096 MB pinned RAM, 32 GB disk on `zfs_pool` (UniFi's own
  profile is 2/4 GB/20 GB). Headroom checked 2026-10-28 from the node
  exporter: MemAvailable 12.7 GiB, 8.3 GiB at the 7-day low, ARC at its 8 GiB
  cap with ~6 GiB reclaimable, swap unused. See also
  [`pve-gigabyte-memory-oversubscription.md`](./pve-gigabyte-memory-oversubscription.md).
- Declared in `iac/main.tf` as `unifi_vm` (vm_id 4327, the old controller's):
  the existing `fedora_cloud_image` (Fedora 44 Cloud Base), cloud-init
  `user_account` amadeus with the wotan key, static `192.168.2.142/24` with
  `dns` + the router as resolvers, guest agent, `startup` order 5.
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

- [x] Check Proxmox memory headroom for a 4 GB guest (2026-10-28, see above).
- [x] Take a backup of the UniFi Network Application before the VM was
  destroyed (done before 2026-10-28).
- [x] ~~Decide how to retain the old controller as a rollback~~ moot: the VM
  is deleted; the backup is the only rollback.
- [ ] Choose monitoring for a non-NixOS guest: `node-exporter` from Fedora
  (`golang-github-prometheus-node-exporter`) plus a scrape job, and/or only a
  blackbox probe of the UI.

## Phase 1 — Provision and install

- [x] `unifi_vm` in `iac/main.tf` (2026-10-28).
- [x] `just iac-plan` / `just iac-apply`; `ssh amadeus@192.168.2.142` works
  (2026-10-28).
- [x] In the VM (2026-10-28): cloud-init's first-boot `dnf -y upgrade` (Proxmox
  enables it by default; `cloud-init status --wait`), `dnf install podman
  slirp4netns jq qemu-guest-agent dnf5-plugin-automatic`, `apply_updates = yes`
  in `/etc/dnf/automatic.conf`, `dnf5-automatic.timer` enabled (dnf5: the old
  `dnf-automatic-install.timer` does not exist). qemu-guest-agent is
  udev-started on Fedora. SELinux left enforcing.
- [x] Download the UniFi OS Server installer for `linux-x64` from Ubiquiti
  (`https://fw-update.ui.com/api/firmware-latest`, product
  `unifi-os-server`). **Verify its `sha256_checksum` from that API before
  running it.** v5.1.42 x64 is
  `f6111e9396a42c74016f5dde9b01fbef486a6fe69efe137935e6e38b7c22f94d`. Then run
  it as root and answer its prompt by hand. Done 2026-10-28: v5.1.42,
  `sha256sum -c` OK. Listening afterwards (podman/pasta): TCP 11443 (UI), 8080
  (inform), 8443-8444/8880-8882 (portal), 6789 (speed test), 5671, 9543,
  28082; UDP 3478 (STUN), 10001/10003 (discovery), 5514 (syslog).
- [ ] Confirm its services survive a VM reboot.
- [ ] Host firewall: firewalld is inactive on the Fedora Cloud image, so every
  port above is open to the LAN. Optional: firewalld or the PVE firewall on
  net0, allowing the UI,
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

- [x] `unifi` entry (`192.168.2.142`, default zones like the old controller,
  so `unifi.homelab.{internal,local}` resolve as before) in `lib/hosts.nix`
  (2026-10-28). Not in `fleet`, so no colmena target. Needs
  `just colmena-apply-host dns`.
- [x] TLS front for `unifi.homelab.internal` (2026-10-28, `200 0` from wotan): Caddy **on the VM itself**
  (`dnf install caddy`), step-ca ACME, reverse-proxying to `127.0.0.1:11443`
  with `tls_insecure_skip_verify` (UniFi OS's cert is self-signed). On the VM
  rather than on `containers` so the name keeps pointing at the controller
  (devices that inform by name reach :8080 there). Trust the step-ca root in
  `/etc/pki/ca-trust/source/anchors/` + `update-ca-trust`. If Caddy returns
  502, SELinux: `setsebool -P httpd_can_network_connect 1`.
- [x] Monitoring: `unifi.homelab.internal` in `certSubjects` in
  `hosts/otel/blackbox.nix` (2026-10-28).
- [ ] Optional: a node exporter on the VM and a `unifi-node` scrape job.
- [x] The UniFi link in `hosts/containers/homelab-dashboard/default.nix` and a
  row in `infra/README.md`'s host inventory (2026-10-28).
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
