# k3s server (control plane) with embedded etcd. One server per cluster for
# now; see roleOverrides in lib/pi-fleet.nix.
{
  config,
  lib,
  ...
}: {
  imports = [./common.nix];

  config = lib.mkIf config.services.k3s.enable {
    services.k3s = {
      role = "server";
      clusterInit = true;
      extraFlags = ["--tls-san=${config.networking.hostName}.${config.networking.domain}"];
    };
    networking.firewall.allowedTCPPorts = [6443]; # Kubernetes API
  };
}
