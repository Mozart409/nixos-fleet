{
  config,
  pkgs,
  inputs,
  lib,
  username,
  ...
}: {
  imports = [
    # Disko configuration (must come before hardware-config)
    inputs.disko.nixosModules.disko
    ./disko-config.nix

    # Hardware configuration
    ./hardware-configuration.nix

    # Agenix for secrets management
    inputs.agenix.nixosModules.default

    # What wotan shares with the fleet: timezone, locale, keymap, flakes,
    # trusted-users, the amadeus account. Only base.nix -- never common.nix or
    # server.nix, which start sshd (see the assertions below).
    ../../modules/base.nix

    # Shared NixOS modules (aggregator — each gated by its own enable flag)
    ../../modules/wotan

    # Desktop configuration
    ./desktop-config.nix

    # Nebula overlay client (amartum + mozart409 tenants)
    ./nebula.nix
  ];

  # Host-specific settings
  networking.hostName = "wotan";

  # Host-specific DNS settings
  # 192.168.2.145 = local Unbound resolver (primary)
  # 192.168.2.1   = router fallback
  # 1.1.1.1       = Cloudflare public fallback
  networking.nameservers = ["192.168.2.145" "192.168.2.1" "1.1.1.1"];

  # Static IP configuration for enp38s0 (main Ethernet)
  networking.useDHCP = lib.mkForce false;
  networking.interfaces.enp38s0.ipv4.addresses = [
    {
      address = "192.168.2.71";
      prefixLength = 24;
    }
  ];
  networking.defaultGateway = {
    address = "192.168.2.1";
    interface = "enp38s0";
  };

  nix.settings = {
    download-buffer-size = 4 * 1024 * 1024 * 1024;
    substituters = lib.mkAfter ["https://cache.int.oyabu.cc/ventara"];
    trusted-public-keys = lib.mkAfter [
      "ventara:GbJNF0XM+B6Ow4Bq4Y7P0t8opAr28zNIyUjRBtbDwDw="
    ];
  };

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 5;

  # /tmp lives on the root partition, so nothing resets it between the daily
  # systemd-tmpfiles pass (q /tmp ... 10d). Wipe it on boot instead.
  boot.tmp.cleanOnBoot = true;

  # Enable aarch64 emulation for cross-compilation (e.g., building aarch64 ISOs)
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  # Desktop environment configuration
  desktop.enable = true;

  # Security hardening
  security.hardening = {
    enable = true;
    firewall.allowedTCPPorts = [];
    audit.enable = false; # Enable for security auditing (generates logs)
  };

  # wotan has no inbound SSH: it deploys only itself and is not a colmena node.
  # Bots may edit this config, and fleet modules (modules/common.nix) turn sshd
  # on, so fail evaluation -- the pre-push gate and switch.sh both evaluate
  # wotan -- rather than trust that nobody re-enables it. security.hardening.ssh
  # only hardens sshd's settings; it does not start it.
  assertions = let
    sshFlag = lib.any (lib.hasPrefix "--ssh");
  in [
    {
      assertion = !config.services.openssh.enable;
      message = "wotan must not run sshd (services.openssh.enable): it has no inbound SSH by design. Was modules/common.nix imported?";
    }
    {
      assertion = !(lib.elem 22 config.networking.firewall.allowedTCPPorts);
      message = "wotan must not open TCP 22 in networking.firewall.allowedTCPPorts.";
    }
    {
      assertion = !(sshFlag config.services.tailscale.extraUpFlags || sshFlag config.services.tailscale.extraSetFlags);
      message = "wotan must not enable Tailscale SSH (--ssh in services.tailscale.extra{Up,Set}Flags).";
    }
  ];

  # k3s pod/overlay networking must bypass the host firewall
  networking.firewall.trustedInterfaces = ["cni0" "flannel.1"];

  # Display manager auto-login (KDE specific)
  services.displayManager.autoLogin = lib.mkIf (config.desktop.environment == "kde") {
    enable = true;
    user = username;
  };

  # Razer device support
  hardware.razer.enable = true;

  # MOZA sim-racing wheelbase support
  hardware.moza.enable = true;

  # System-managed MCP servers for Claude Code
  programs.claudeCodeMcp.enable = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    # Enable this if you have graphical corruption issues or application crashes after waking
    # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
    # of just the bare essentials.
    powerManagement.enable = true;

    # Fine-grained power management. Turns off GPU when not in use.
    # Experimental and only works on modern Nvidia GPUs (Turing or newer).
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module (not to be confused with the
    # independent third-party "nouveau" open source driver).
    # Support is limited to the Turing and later architectures. Full list of
    # supported GPUs is at:
    # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
    # Only available from driver 515.43.04+
    # Currently alpha-quality/buggy, so false is currently the recommended setting.
    open = false;

    # Enable the Nvidia settings menu,
    # accessible via `nvidia-settings`.
    nvidiaSettings = true;

    # Optionally, you may need to select the appropriate driver version for your specific GPU.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Enable NVIDIA Container Toolkit so Podman can pass GPUs to containers
  # via CDI (--device nvidia.com/gpu=all).
  hardware.nvidia-container-toolkit.enable = true;

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    steam
    heroic
    mangohud
    bcachefs-tools
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  # v2 registries.conf schema. Replaces the deprecated
  # `virtualisation.containers.registries.search`, which emitted the v1
  # `[registries.search]` table; `unqualified-search-registries` is its v2
  # equivalent. Setting `settings` also drops nixpkgs' default
  # `registry = [docker.io quay.io]`, which configures those registries but
  # does NOT make them searchable for unqualified names.
  virtualisation.containers.registries.settings = {
    unqualified-search-registries = ["quay.io"];
  };

  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
    package = pkgs.steam.override {
      extraBwrapArgs = [
        "--bind"
        "/mnt/games"
        "/mnt/games"
      ];
    };
  };
  # gamescope micro-compositor — wraps games so Hyprland sees one
  # well-behaved window (fixes Xwayland fullscreen/cursor weirdness,
  # e.g. S.T.A.L.K.E.R. GAMMA via Heroic).
  #
  # capSysNice MUST stay false: it installs gamescope as a setcap wrapper
  # at /run/wrappers/bin, which fails ("failed to inherit capabilities")
  # inside Heroic's no-new-privs bubblewrap sandbox and bails instantly.
  # false installs the plain binary at /run/current-system/sw/bin, which
  # the sandbox can run (we only forgo realtime scheduling priority).
  programs.gamescope = {
    enable = true;
    capSysNice = false;
  };
  services.tailscale.enable = true;

  # Trust Homelab CA root certificate (step-ca)
  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
      MIIBqDCCAU6gAwIBAgIRALQDGl7A1VqHYulOxqghMAUwCgYIKoZIzj0EAwIwMjET
      MBEGA1UEChMKSG9tZWxhYiBDQTEbMBkGA1UEAxMSSG9tZWxhYiBDQSBSb290IENB
      MB4XDTI2MDQxNzIwMDQzMloXDTM2MDQxNDIwMDQzMlowMjETMBEGA1UEChMKSG9t
      ZWxhYiBDQTEbMBkGA1UEAxMSSG9tZWxhYiBDQSBSb290IENBMFkwEwYHKoZIzj0C
      AQYIKoZIzj0DAQcDQgAE43kC/jM9k+aC3yS1m1ckSohIHFRdU1gZvZVkW1TyiUJm
      i88gkJJl0B1NrU8ZjBwT/rthgpPyXu6P8ZiUFcb5yaNFMEMwDgYDVR0PAQH/BAQD
      AgEGMBIGA1UdEwEB/wQIMAYBAf8CAQEwHQYDVR0OBBYEFIVsuIWilVCzeUOnHLhq
      kHKB5uYhMAoGCCqGSM49BAMCA0gAMEUCIQDuctLl8ySFXqgAsJV4E7cEM3ezyvdo
      eC4NJYiSUAa8xwIgcjnD5fki6RlgJisn80mg/nARJNvNHqjazM3j1b4x4/4=
      -----END CERTIFICATE-----
    ''
  ];

  # opencode headless server — persistent background service so every new
  # opencode session attaches to the same server instead of spawning a new one.
  # A zsh function in configs/shell.nix (`opencode` → `opencode attach
  # $OPENCODE_SERVER_URL --dir "$PWD"`) makes this transparent. Commands run
  # in the server's environment, not the attaching shell's: devshell/direnv
  # tools are only available via `nix develop -c ...`.
  services.opencode-serve = {
    enable = true;
    hostname = "127.0.0.1";
    port = 4096;
    user = username;
    # password = "";  # Set for auth; empty = no basic-auth.
    # The server process (not the attaching shell) connects to MCP servers, so
    # secrets referenced via {env:VAR} in opencode.json must be in the
    # service's environment. The agenix secret is already in KEY=value format.
    # NOTE: restart the service after re-encrypting the secret (token rotation).
    environmentFiles = [
      config.age.secrets.axon-gateway-env.path
      config.age.secrets.ventara-gateway-env.path
      # Basic auth; clients get it via OPENCODE_SERVER_PASSWORD (home.nix).
      config.age.secrets.opencode-server-password.path
    ];
    # Raw-value secret (not KEY=value), for {env:CONTEXT7_API_KEY}.
    credentialEnvironment.CONTEXT7_API_KEY = config.age.secrets.context7-api-key.path;
    readWritePaths = ["/home/${username}"];
    # Signing-only key (not a login key anywhere) in its own agent, so opencode
    # can sign commits but can't authenticate/push. Private key stays hidden
    # (~/.ssh is in inaccessiblePaths).
    signing = {
      keyFile = "/home/${username}/.ssh/id_ed25519_signing";
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII0yU9qnU/StErCjgpV/M5h68Por1yRC21uqdO0eF6M9 bot-signing@wotan";
    };
    # systemd (PID 1) reads the secrets above before entering the sandbox, so
    # /run/agenix can be hidden from every tool. ~/.gnupg stays visible but
    # without private keys: signing goes through the (unsandboxed) gpg-agent.
    inaccessiblePaths = [
      "/run/agenix"
      "/run/agenix.d"
      "/home/${username}/.ssh"
      "/home/${username}/.gnupg/private-keys-v1.d"
      "/home/${username}/.config/sops/age"
      "/home/${username}/.config/age"
      "/home/${username}/.claude/.credentials.json"
    ];
  };

  # Swap on zram — helps avoid OOM during large builds and LLM inference
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  # System state version
  system.stateVersion = "24.11";

  # Ensure storage mount is owned by the primary user and create models directory
  systemd.tmpfiles.rules = [
    "Z /mnt/storage 0755 ${username} users -"
    "d /home/${username}/models 0755 ${username} users -"
  ];

  # Agenix secrets configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  age.secrets.context7-api-key = {
    file = ../../secrets/context7-api-key.age;
    mode = "440";
    owner = username;
    group = "users";
  };

  # Raw attic token for switch.sh's `attic push`; home.nix points
  # ~/.config/attic/config.toml at it via token-file. Gated until the .age file
  # exists (`agenix -e attic-push-token-wotan.age`), so eval never breaks.
  age.secrets.attic-push-token-wotan = lib.mkIf (builtins.pathExists ../../secrets/attic-push-token-wotan.age) {
    file = ../../secrets/attic-push-token-wotan.age;
    mode = "400";
    owner = username;
  };

  age.secrets.axon-gateway-env = {
    file = ../../secrets/axon-gateway-env.age;
    # Owner-only: read by the `claude` zsh function and (as root) by
    # opencode-serve's EnvironmentFile.
    mode = "400";
    owner = username;
    # Format inside the file: AXON_GATEWAY_TOKEN=ABC123
  };

  # Bearer token for ventara-gateway, the nixos-ventara-ai deployment's own
  # axon-gateway (a separate instance from the homelab one above).
  age.secrets.ventara-gateway-env = {
    file = ../../secrets/ventara-gateway-env.age;
    # Owner-only: read by the `claude` zsh function and (as root) by
    # opencode-serve's EnvironmentFile.
    mode = "400";
    owner = username;
    # Format inside the file: VENTARA_GATEWAY_TOKEN=ABC123
  };

  age.secrets.opencode-server-password = {
    file = ../../secrets/opencode-server-password.age;
    mode = "440";
    owner = username;
    group = "users";
    # Format inside the file: OPENCODE_SERVER_PASSWORD=xxxx
  };

  age.secrets.ha-token = {
    file = ../../secrets/ha-token.age;
    mode = "400";
    owner = username;
    # Raw Home Assistant long-lived access token, no KEY= prefix. Read by
    # quickshell-ha (desktop.quickshell.homeAssistant in home.nix).
  };

  age.secrets.hofvarpnir-tui = {
    file = ../../secrets/hofvarpnir-tui.age;
    mode = "400";
    owner = username;
    # Raw hofvarpnir API key (hof_sk_...), no KEY= prefix. Read by the TUI via
    # token_file in the generated ~/.config/hofvarpnir/tui.toml
    # (modules/home/packages/hofvarpnir-tui.nix).
  };

  # Environment variables
  environment.sessionVariables = {
    # Agenix secrets
    CONTEXT7_API_KEY_FILE = config.age.secrets.context7-api-key.path;
    AXON_GATEWAY_TOKEN_FILE = config.age.secrets.axon-gateway-env.path;
    VENTARA_GATEWAY_TOKEN_FILE = config.age.secrets.ventara-gateway-env.path;
    OPENCODE_SERVER_PASSWORD_FILE = config.age.secrets.opencode-server-password.path;

    # NVIDIA Wayland environment variables for better compatibility
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    # Disable hardware cursors (fixes flickering/lag on some setups)
    WLR_NO_HARDWARE_CURSORS = "1";
    # Enable VRR/GSync for NVIDIA
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    # Hardware video acceleration with NVIDIA
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    # Electron/Chromium apps - use Wayland
    ELECTRON_OZONE_PLATFORM_HINT = "auto";

    # Aquamarine (Hyprland renderer) NVIDIA fixes
    # Disable forcing linear modifiers - can help with scroll lag on NVIDIA
    AQ_FORCE_LINEAR_BLIT = "0";
  };
}
