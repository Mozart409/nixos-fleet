{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/common-packages.nix
  ];

  # Basic host configuration
  networking = {
    hostName = "minimal";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  # User configuration with default password
  users.users.amadeus = {
    # All other userconfig is done in modules/nixos/common-packages.nix
    initialPassword = lib.mkForce "amadeus";
  };

  # Enable SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Bootloader configuration for LXC
  boot.loader.grub.enable = false;

  # System state version
  system.stateVersion = "25.11";
}

