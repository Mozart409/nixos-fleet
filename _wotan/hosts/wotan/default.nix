{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix

    # Common modules
    ../../modules/nixos/common-packages.nix
    ../../modules/nixos/flatpak.nix
    ../../modules/nixos/desktop/default.nix
    ../../modules/nixos/desktop/kde.nix
    ../../modules/nixos/desktop/niri.nix
    ../../modules/nixos/desktop/user-experience.nix
    
    # Desktop configuration
    ./desktop-config.nix
  ];

  # Host-specific settings
  networking.hostName = "wotan";

  # Host-specific DNS settings
  networking.nameservers = ["192.168.2.1" "1.1.1.1"];

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
  ];

  # Host-specific services
  virtualisation.docker.enable = true;
  programs.steam.enable = true;
  services.tailscale.enable = true;

  # System state version
  system.stateVersion = "24.11";
}
