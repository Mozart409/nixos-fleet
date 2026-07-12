{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    # keep-sorted start
    ../../modules/home-manager/common-packages.nix
    ../../modules/home-manager/node-security.nix
    ../../modules/home-manager/packages/browsers.nix
    ../../modules/home-manager/packages/chess.nix
    ../../modules/home-manager/packages/database.nix
    ../../modules/home-manager/packages/desktop.nix
    ../../modules/home-manager/packages/development.nix
    ../../modules/home-manager/packages/easyeffects.nix
    ../../modules/home-manager/packages/fun.nix
    ../../modules/home-manager/packages/gtk.nix
    ../../modules/home-manager/packages/halloy.nix
    ../../modules/home-manager/packages/hyprland-configs.nix
    ../../modules/home-manager/packages/kubernetes.nix
    ../../modules/home-manager/packages/onlyoffice.nix
    ../../modules/home-manager/packages/opencode.nix
    ../../modules/home-manager/packages/podman.nix
    ../../modules/home-manager/packages/quickshell.nix
    ../../modules/home-manager/packages/rofi.nix
    ../../modules/home-manager/packages/system.nix
    ../../modules/home-manager/packages/terminals.nix
    ../../modules/home-manager/packages/tmux.nix
    ../../modules/home-manager/packages/yazi.nix
    ../../modules/home-manager/packages/zinc-oxide.nix
    inputs.mozart409-nixvim.homeModules.default
    # keep-sorted end
  ];

  desktop.hyprland-configs.enable = true;
  desktop.rofi.enable = true;
  desktop.gtk.enable = true;
  desktop.quickshell.enable = true;
  desktop.easyeffects.enable = true;

  # Enable opencode custom commands
  opencode.enable = true;

  # Skip building the nixvim option-reference manpage. As of 2026-07-11 nixpkgs
  # (nixos-render-docs) merged the GFM-alert/admonition support that the current
  # nixvim (2026-07-10 HEAD) still applies as a patch, so the patch fails with
  # "Reversed (or previously applied)" and breaks the build. We don't need the
  # generated manpage. Revisit once nixvim drops the redundant patch.
  programs.nixvim.enableMan = false;

  # Dedicated age identity for agenix (no passphrase, never expires)
  age.identityPaths = [
    "${config.home.homeDirectory}/.config/age/keys.txt"
  ];

  # Load agenix secrets into shell environment variables
  home.sessionVariablesExtra = ''
    if [ -n "$CONTEXT7_API_KEY_FILE" ] && [ -f "$CONTEXT7_API_KEY_FILE" ]; then
      export CONTEXT7_API_KEY=$(cat "$CONTEXT7_API_KEY_FILE")
    fi
    if [ -n "$AXON_GATEWAY_TOKEN_FILE" ] && [ -f "$AXON_GATEWAY_TOKEN_FILE" ]; then
      export AXON_GATEWAY_TOKEN=$(cat "$AXON_GATEWAY_TOKEN_FILE" | sed 's/AXON_GATEWAY_TOKEN=//')
    fi
  '';

  # Automatic Nix garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +5";
  };

  # SSH configuration - agent key for internal hosts, ed25519 for privileged access
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = "no";
        Compression = "no";
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = "no";
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        AddKeysToAgent = "confirm";
      };
      "192.168.* 10.* *.internal *.local" = {
        User = "agent";
        IdentityFile = "~/.ssh/id_agent";
        IdentitiesOnly = "yes";
      };
    };
    extraConfig = ''
      Match User amadeus,root
        IdentityFile ~/.ssh/id_ed25519
        IdentitiesOnly yes
    '';
  };

  # Host-specific home-manager packages can be added here
  # For example, if you want certain packages only on wotan:
  # home.packages = with pkgs; [
  #   host-specific-package
  # ];
}
