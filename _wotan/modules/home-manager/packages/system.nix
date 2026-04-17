{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    bat
    busybox
    file
    glow
    gparted
    just
    nettools
    nvtopPackages.full
    rclone
    steam-devices-udev-rules
    vulnix
    xclip
    # keep-sorted end
  ];
}
