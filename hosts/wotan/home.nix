{
  config,
  pkgs,
  inputs,
  lib,
  osConfig,
  username,
  ...
}: {
  imports = [
    # keep-sorted start
    ../../modules/home/common-packages.nix
    ../../modules/home/node-security.nix
    ../../modules/home/packages/browsers.nix
    ../../modules/home/packages/chess.nix
    ../../modules/home/packages/claude.nix
    ../../modules/home/packages/database.nix
    ../../modules/home/packages/desktop.nix
    ../../modules/home/packages/development.nix
    ../../modules/home/packages/easyeffects.nix
    ../../modules/home/packages/fun.nix
    ../../modules/home/packages/git-sync.nix
    ../../modules/home/packages/gtk.nix
    ../../modules/home/packages/halloy.nix
    ../../modules/home/packages/hofvarpnir-tui.nix
    ../../modules/home/packages/hyprland-configs.nix
    ../../modules/home/packages/kubernetes.nix
    ../../modules/home/packages/onlyoffice.nix
    ../../modules/home/packages/opencode.nix
    ../../modules/home/packages/podman.nix
    ../../modules/home/packages/quickshell.nix
    ../../modules/home/packages/rofi.nix
    ../../modules/home/packages/sops.nix
    ../../modules/home/packages/system.nix
    ../../modules/home/packages/terminals.nix
    ../../modules/home/packages/tmux.nix
    ../../modules/home/packages/yazi.nix
    ../../modules/home/packages/zinc-oxide.nix
    inputs.mozart409-nixvim.homeModules.default
    # keep-sorted end
  ];

  # Two 1440p/144Hz panels side by side: DP-3 left, DP-2 right. Workspaces 1-5
  # live on the left one, 6-10 on the right one. This is the only Hyprland
  # config that is genuinely wotan-specific; it is rendered into
  # ~/.config/hypr/host.lua by modules/home/packages/hyprland-configs.nix.
  desktop.hyprland-configs = {
    enable = true;

    monitors = [
      {
        output = "DP-3";
        mode = "2560x1440@144";
        position = "0x0";
        scale = 1;
      }
      {
        output = "DP-2";
        mode = "2560x1440@144";
        position = "2560x0";
        scale = 1;
      }
    ];

    workspaces =
      map (id: {
        inherit id;
        monitor = "DP-3";
        default = id == 1;
      }) [1 2 3 4 5]
      ++ map (id: {
        inherit id;
        monitor = "DP-2";
        default = id == 6;
        # The number-row binds stop at 9, so nothing can focus 10 -- keep the
        # rule (it still belongs to this output) but leave it out of the bar.
        showInBar = id != 10;
      }) [6 7 8 9 10];
  };
  desktop.rofi.enable = true;
  desktop.gtk.enable = true;
  # quickshell owns notifications; dunst is one word away if the in-shell
  # daemon ever misbehaves (a QML error takes the whole shell down, and with
  # it your notifications -- dunst is isolated from that).
  desktop.notifications.backend = "quickshell";

  desktop.quickshell = {
    enable = true;
    # ~/.config/quickshell points at the working tree instead of a store copy,
    # so editing (or adding) a widget under
    # modules/home/packages/quickshell/ shows up immediately -- no
    # rebuild. Trade-off: what is on screen is whatever is checked out, which
    # is only the same as the flake once the tree is committed and rebuilt.
    liveReload = true;

    homeAssistant = {
      enable = true;
      url = "https://homeassistant.dropbear-butterfly.ts.net";
      # age.secrets.ha-token in default.nix: raw long-lived token, no KEY=.
      tokenFile = "/run/agenix/ha-token";
      # Büro lights plus the kitchen. HA has no Büro area -- the Büro ones all
      # sit under Living Room.
      entities = [
        {
          id = "switch.tasmota_licht_5_tasmota_licht_5";
          label = "Licht 5";
        }
        {id = "switch.tasmota_licht_ecke_licht_ecke";} # Couch Tisch
        {id = "switch.tasmota_licht_ecke_licht_ecke_2";} # Arbeitsecke
        {id = "switch.tasmota_licht_kuche_tasmota_licht_kuche";} # Küche
      ];
    };
  };
  desktop.easyeffects.enable = true;

  # Disabled: every 4 hours, fast-forward-only pull/push every git repo under
  # ~/code (skips dirty trees, never commits, never force-pushes or creates
  # new remote branches). See modules/home/packages/git-sync.nix.
  # gitSync = {
  #   enable = true;
  #   interval = "0/4:00:00";
  # };

  # Enable opencode custom commands
  opencode.enable = true;

  # Encrypted per-project dotenv files (.sops.env) decrypted via gpg-agent.
  # Fingerprint = the primary key; gpg picks its encryption subkey.
  sopsEnv = {
    enable = true;
    pgpFingerprint = "CAE234D7B574DC1D72AB52391DDDB1E94B3B2C1E";
  };

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
  # llmfit's vLLM detection reads two different env vars (llmfit 1.1.16):
  # the TUI/model-listing VllmProvider probes VLLM_HOST (default
  # http://localhost:8000), while `bench` endpoint discovery builds the URL
  # from VLLM_PORT alone (bench.rs vllm_url()). Both point at the server
  # from modules/wotan/vllm.nix. osConfig reads the NixOS option from this
  # home-manager module.
  home.sessionVariables.VLLM_HOST = "http://127.0.0.1:${toString osConfig.services.vllm.port}";
  home.sessionVariables.VLLM_PORT = toString osConfig.services.vllm.port;

  # Load agenix secrets into shell environment variables
  home.sessionVariablesExtra = ''
    if [ -n "$CONTEXT7_API_KEY_FILE" ] && [ -f "$CONTEXT7_API_KEY_FILE" ]; then
      export CONTEXT7_API_KEY=$(cat "$CONTEXT7_API_KEY_FILE")
    fi
    if [ -n "$AXON_GATEWAY_TOKEN_FILE" ] && [ -f "$AXON_GATEWAY_TOKEN_FILE" ]; then
      export AXON_GATEWAY_TOKEN=$(cat "$AXON_GATEWAY_TOKEN_FILE" | sed 's/AXON_GATEWAY_TOKEN=//')
    fi  '';

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
      Match User ${username},root
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
