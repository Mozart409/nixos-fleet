# Shared by modules/k3s/server.nix and agent.nix: the cluster join token and
# the ports every node needs.
#
# secrets/k3s-token.age is created by hand after the Pis' first boot (their
# SSH host keys do not exist before that; steps in infra/docs/rpi-k3s.md). Until the
# file is committed, k3s stays off and the host builds and boots as a plain Pi.
{
  config,
  lib,
  ...
}: let
  tokenFile = ../../secrets/k3s-token.age;
  haveToken = builtins.pathExists tokenFile;
in {
  options.homelab.k3s.serverUrl = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "https://rpi4-1.homelab.internal:6443";
    description = "API URL agents join. Unused on servers.";
  };

  config = lib.mkMerge [
    {
      warnings = lib.optional (!haveToken) "infra/secrets/k3s-token.age does not exist: k3s is disabled on ${config.networking.hostName} (see infra/docs/rpi-k3s.md).";
    }
    (lib.mkIf haveToken {
      age.secrets.k3s-token = {
        file = tokenFile;
        owner = "root";
        mode = "0400";
      };
      services.k3s = {
        enable = true;
        tokenFile = config.age.secrets.k3s-token.path;
      };
      networking.firewall = {
        allowedTCPPorts = [10250]; # kubelet
        allowedUDPPorts = [8472]; # flannel VXLAN
      };
    })
  ];
}
