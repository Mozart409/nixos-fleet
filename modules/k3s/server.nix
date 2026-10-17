# k3s server (control plane) on the default SQLite datastore: no etcd writes on
# the SD card. One server per cluster for now (see roleOverrides in
# lib/pi-fleet.nix); going HA needs `--cluster-init`, see infra/docs/rpi-k3s.md.
{
  config,
  lib,
  ...
}: {
  imports = [./common.nix];

  config = lib.mkIf config.services.k3s.enable {
    services.k3s = {
      role = "server";
      extraFlags = ["--tls-san=${config.networking.hostName}.${config.networking.domain}"];
    };
    networking.firewall.allowedTCPPorts = [6443]; # Kubernetes API
  };
}
