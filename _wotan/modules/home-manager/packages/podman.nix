{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    podman
    podman-compose
    podman-tui
    lazydocker
  ];
}
