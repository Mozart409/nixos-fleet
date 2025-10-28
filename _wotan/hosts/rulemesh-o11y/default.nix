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

  # Add host-specific configuration here
  networking = {
    hostName = "rulemesh-o11y";
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [22 80 443];
      /*
         allowedUDPPortRanges = [
        {
          from = 4000;
          to = 4007;
        }
        {
          from = 8000;
          to = 8010;
        }
      ];
      */
    };
  };

  services.caddy = {
    enable = true;
  };

  # Bootloader configuration for LXC
  boot.loader.grub.enable = false;
  
  # System state version
  system.stateVersion = "25.11";
}
