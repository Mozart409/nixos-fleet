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
    nh
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
