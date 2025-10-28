{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # Hardware configuration
    ./hardware-configuration.nix
    
    # Common modules
    ../../modules/nixos/common-packages.nix
    ../../modules/nixos/flatpak.nix
  ];

  # Host-specific settings
  networking.hostName = "wotan";
  
  # Host-specific DNS settings
  networking.nameservers = ["192.168.2.1" "1.1.1.1"];

  # Bootloader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # Desktop environment (KDE Plasma)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.autoLogin = {
    enable = true;
    user = "amadeus";
  };

  # X11 keyboard configuration
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Graphics and OpenGL configuration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting is required.
    modesetting.enable = true;

    # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
    powerManagement.enable = false;

    # Fine-grained power management. Turns off GPU when not in use.
    powerManagement.finegrained = false;

    # Use the NVidia open source kernel module
    open = false;

    # Enable the Nvidia settings menu
    nvidiaSettings = true;

    # Use stable drivers
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  # Sound configuration
  services.pulseaudio.enable = false;
  services.pulseaudio.support32Bit = true;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
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