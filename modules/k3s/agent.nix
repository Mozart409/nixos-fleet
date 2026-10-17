# k3s agent (worker) joining homelab.k3s.serverUrl.
{
  config,
  lib,
  ...
}: {
  imports = [./common.nix];

  config = lib.mkIf config.services.k3s.enable {
    assertions = [
      {
        assertion = config.homelab.k3s.serverUrl != "";
        message = "homelab.k3s.serverUrl must be set on a k3s agent.";
      }
    ];
    services.k3s = {
      role = "agent";
      serverAddr = config.homelab.k3s.serverUrl;
    };
  };
}
