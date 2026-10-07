{
  config,
  pkgs,
  ...
}: {
  # The agent platform (knowledge-base/projects/agent-platform): one Multica
  # daemon per trust zone, each zone a microVM inside this guest. Replaces
  # `hermes` and `development` (decommissioned 2026-10-06). All state that
  # matters lives elsewhere -- Multica on `containers`/`database`, code on
  # Forgejo -- so rebuilding this host loses nothing but task worktrees.
  #
  # Zones: one microVM per trust zone, each with its own Multica daemon
  # (./zones.nix).
  imports = [
    ../../modules/common.nix
    # XFS root on ssd_pool (iac/main.tf, agents_vm), same as dns/ca/hermes.
    ../../modules/disko-xfs.nix
    ../../modules/tailscale.nix
    ../../modules/step-ca-trust.nix
    ../../modules/osquery.nix
    ./zones.nix
  ];

  networking.hostName = "homelab-agents";

  networking.interfaces.ens18 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        address = "192.168.2.190";
        prefixLength = 24;
      }
    ];
  };
  networking.defaultGateway = "192.168.2.1";

  # Compressed RAM swap absorbs the spike of an agent CLI plus a cold devShell
  # before the disk swap is touched (same reasoning as hermes/development).
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  # ── Firewall ──────────────────────────────────────────────────────────────
  # Like hermes: no `trustedInterfaces = ["tailscale0"]`. This host runs agents
  # with shells, so nothing is open merely because of the interface a packet
  # arrived on. Tailscale ACLs are a bonus, never the control.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # ssh (also the mosh handshake; mosh's UDP range comes from server.nix)
      9100 # node exporter, scraped by otel
    ];
    # tailscaled's own port, so sessions connect directly instead of via DERP.
    allowedUDPPorts = [config.services.tailscale.port];
  };

  environment.systemPackages = with pkgs; [
    # keep-sorted start
    btop
    git
    htop
    jq
    ripgrep
    tmux
    # keep-sorted end
  ];
}
