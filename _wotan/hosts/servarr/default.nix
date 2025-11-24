{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos/basics.nix
  ];

  # Basic host configuration
  networking = {
    hostName = "servarr";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22 80 443];
    };
  };

  # User configuration with default password
  users.users.amadeus = {
    isNormalUser = true;
    description = "amadeus";
    extraGroups = ["networkmanager" "wheel" "docker"];
    shell = pkgs.zsh;
    initialPassword = lib.mkForce "amadeus";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"
    ];
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
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 10;

  # System state version
  system.stateVersion = "25.11";
}
