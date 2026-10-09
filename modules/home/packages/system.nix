{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    age
    bat
    file
    glow
    gparted
    just
    nettools
    nvtopPackages.full
    rclone
    steam-devices-udev-rules
    trash-cli
    vulnix
    xclip
    # keep-sorted end
  ];

  # Run packages without installing them: `c <cmd>` (comma), `nix-locate <file>`.
  # Uses the prebuilt database from the nix-index-database flake input
  # (refreshed by `nix flake update nix-index-database`), no local `nix-index`
  # build needed.
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;
  home.shellAliases.c = "comma";
}
