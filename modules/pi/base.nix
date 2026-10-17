# Raspberry Pi 4 SD-image host: everything a Pi needs to boot, be reachable
# over SSH and take colmena deploys. Deliberately not modules/common.nix: the
# fleet's Loki shipper and exporters need secrets a freshly flashed Pi cannot
# decrypt yet. The host name comes from infra/lib/pi-fleet.nix via flake.nix.
{
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
    ../base.nix
  ];

  # Only the image build needs the compressed/ZFS knobs below; the running
  # host ignores them.
  sdImage.compressImage = false;
  boot.supportedFilesystems.zfs = lib.mkForce false;

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking = {
    useDHCP = true;
    useNetworkd = true;
    wireless.enable = false;
    domain = "homelab.internal";
    firewall = {
      enable = true;
      allowedTCPPorts = [22];
    };
  };

  programs.zsh.enable = true; # amadeus's login shell (homelab-users.nix)

  # Auto-reboot a frozen Pi.
  systemd.settings.Manager = {
    RuntimeWatchdogSec = "30s";
    RebootWatchdogSec = "10m";
  };

  # k3s on a 2GB model gets tight without swap.
  zramSwap.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # The fleet's keys (lib/ssh-keys.nix), incl. the colmena deploy key.
  homelab.users.amadeus.sshKeys = import ../../lib/ssh-keys.nix;
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    jq
    vim
  ];

  system.stateVersion = "25.05";
}
