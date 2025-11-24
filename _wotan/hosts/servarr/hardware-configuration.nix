{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  # imports = [(modulesPath + "/profiles/qemu-guest.nix")];

  fileSystems."/" = {
    device = "/zfs_pool/subvol-188-disk-0";
    fsType = "none";
    options = ["bind"];
  };

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.ens18.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
