{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    podman
    podman-compose
    podman-desktop
    podman-tui
    lazydocker
  ];
}
