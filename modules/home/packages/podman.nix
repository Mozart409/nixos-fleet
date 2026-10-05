{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    podman
    podman-compose
    podman-desktop
    podman-tui
    # keep-sorted end
  ];
}
