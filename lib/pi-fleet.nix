# The Raspberry Pi 4 fleet: the one place that lists which Pis exist.
#
# Adding a Pi = adding its name to `nodes`. flake.nix derives the
# nixosConfiguration, the `sdImage-<name>` package and the colmena node from
# this list, so nothing else needs touching. Hosts take a DHCP lease and are
# reached as <name>.<domain>; the DNS record (or DHCP reservation) for the name
# is not managed here.
{
  # Placeholders until the real inventory is known.
  nodes = ["rpi4-1" "rpi4-2" "rpi4-3"];

  domain = "homelab.internal";

  # The first entry is the k3s server (embedded etcd), every other entry an
  # agent. Override one host here to switch its role: "server" | "agent".
  # A second server needs HA setup (clusterInit/serverAddr) that
  # modules/k3s/server.nix does not do yet.
  roleOverrides = {
    # rpi4-2 = "agent";
  };
}
