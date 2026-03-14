{
  config,
  pkgs,
  inputs,
  lib,
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

    # Common modules
    ../../modules/nixos/common-packages.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/razer.nix
    ../../modules/nixos/llama-cpp.nix
    ../../modules/nixos/open-webui.nix
    ../../modules/nixos/desktop/default.nix
    # ../../modules/nixos/desktop/kde.nix
    ../../modules/nixos/desktop/hyprland.nix
    ../../modules/nixos/desktop/user-experience.nix

    # Desktop configuration
    ./desktop-config.nix
  ];

  # Host-specific settings
  networking.hostName = "wotan";

  # Host-specific DNS settings
  networking.nameservers = ["192.168.2.1" "1.1.1.1"];

  nix.settings.download-buffer-size = 512 * 1024 * 1024;

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # Desktop environment configuration
  desktop.enable = true;

  # Display manager auto-login (KDE specific)
  services.displayManager.autoLogin = lib.mkIf (config.desktop.environment == "kde") {
    enable = true;
    user = "amadeus";
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  # Razer device support
  hardware.razer.enable = true;

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

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    steam
    bcachefs-tools
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.containers.registries.search = ["docker.io"];
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
  services.tailscale.enable = true;

  # llama.cpp server with models directory
  # Models are stored in /var/lib/llama-cpp/models (the service's state directory)
  # Per-model presets are in modules/nixos/llama-cpp.nix
  services.llama-cpp = {
    enable = true;
    modelsDir = "/var/lib/llama-cpp/models";
    extraFlags = [
      "--n-gpu-layers"
      "99" # Offload all layers to GPU
      "--cpu-moe" # Keep MoE expert weights in CPU RAM (required for large MoE models like Qwen3-30B-A3B)
      "--parallel"
      "2" # Allow 2 concurrent requests
      "--ctx-size"
      "32768" # Default context size (can be overridden per-model in presets)
      "--models-preset"
      "/etc/llama-cpp-presets.ini"
    ];
  };

  # System state version
  system.stateVersion = "24.11";

  # Ensure storage mount is owned by amadeus and create models directory
  systemd.tmpfiles.rules = [
    "Z /mnt/storage 0755 amadeus users -"
    "d /home/amadeus/models 0755 amadeus users -"
  ];

  # Agenix secrets configuration
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
  ];

  age.secrets.context7-api-key = {
    file = ../../secrets/context7-api-key.age;
    mode = "440";
    owner = "amadeus";
    group = "users";
  };

  # Environment variables
  environment.sessionVariables = {
    # Agenix secret
    CONTEXT7_API_KEY_FILE = config.age.secrets.context7-api-key.path;

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
