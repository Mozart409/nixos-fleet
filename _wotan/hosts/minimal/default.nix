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

  # Enable passwordless sudo for wheel group
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Bootloader configuration for LXC
  boot.loader.grub.enable = true;

  # Home manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.amadeus = import ./home.nix;
  };

  # System state version
  system.stateVersion = "25.11";
}
