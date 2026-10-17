# Raspberry Pi 4 fleet with k3s

The Pi 4s are listed in one place, `infra/lib/pi-fleet.nix` (`nodes`). Each
name becomes a nixosConfiguration, an `sdImage-<name>` package and a colmena
node (`<name>.homelab.internal`, DHCP). The first name is the k3s server, all
others are agents; override a single host in `roleOverrides`.

## Add a Pi

1. Add its name to `nodes`.
2. Add a DNS record or DHCP reservation for `<name>.homelab.internal`.
3. Build and flash the image (below), boot it, then do the secret steps.

Once `k3s-token.age` is committed, k3s fails (and restarts in a loop) on a new Pi
until its host key is in `piHosts`, the secret is re-encrypted (`just reencrypt`)
and the host is applied. The Pi still boots and SSH works meanwhile.

## Build and flash

From wotan (it has aarch64 binfmt):

    just rpi-image rpi4-1
    just rpi-flash /dev/sdX      # asks for confirmation, then dd

## k3s token (after first boot)

k3s stays off until `infra/secrets/k3s-token.age` exists, so the image boots
as a plain Pi first. The Pis only have SSH host keys after first boot, and
agenix encrypts to those.

1. Boot every Pi, then collect its host key: `just get-host-key rpi4-1.homelab.internal`.
2. Put the keys in `piHosts` in `infra/secrets/agenix-rules.nix`.
3. Create the secret:

       cd infra/secrets
       pwgen -s 64 1 | agenix -e k3s-token.age

   (agenix opens `$EDITOR`; paste the pwgen output if the pipe is not accepted.)
4. `git add infra/secrets/k3s-token.age` (flakes only see tracked files), commit.
5. `colmena apply --on @raspberry-pi`. Apply order is not guaranteed; if an
   agent fails to join before the server is up, re-run the apply.

Adding a Pi later means re-encrypting: `just reencrypt` (or the ssh-identity
variant noted in `agenix-rules.nix`) after extending `piHosts`.

## Notes

- Ports: every node opens 10250/tcp and 8472/udp; the server also 6443/tcp.
- One server only, on k3s' default SQLite datastore (no etcd writes on the SD
  card). To go HA later (second server, or a USB SSD), restart the server with
  `--cluster-init` (set `services.k3s.clusterInit = true`); k3s migrates SQLite
  to embedded etcd, then add servers with `serverAddr`. Not wired up yet.
- The previous Pi and k3s-cntrl-1 config is archived in `docs/archive/rpi-k3s/`.
