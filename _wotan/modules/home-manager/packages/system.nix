{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    busybox
    nettools
    file
    just
    xclip
    bat
    glow
    gparted
    rclone
    vulnix
    nvtopPackages.full
    steam-devices-udev-rules
  ];
}
