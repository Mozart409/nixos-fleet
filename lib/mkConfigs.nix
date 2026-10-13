{
  lib,
  inputs,
  nixpkgs,
}: let
  # Shared nixpkgs config — single source of truth for all nixos and
  # home-manager evaluations.  cudaSupport stays off: globally it turned
  # every CUDA-capable package (handy's onnxruntime, opencv, ...) into a
  # multi-GiB CUDA build. Enable it per package with `.override` instead.
  sharedNixpkgsConfig = {
    allowUnfree = true;
  };
in {
  inherit sharedNixpkgsConfig;

  # Helper function to generate host configurations.
  # Home-manager is integrated via the NixOS module so a single
  # `nixos-rebuild switch` activates both system and user config.
  # `username` is threaded through specialArgs (system) and extraSpecialArgs
  # (home) so shared modules stay reusable across hosts/users.
  mkDesktop = hostname: system: username:
    lib.nixosSystem {
      specialArgs = {inherit inputs username;};
      modules = [
        ../hosts/${hostname}/default.nix
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config = sharedNixpkgsConfig;
          # hyprland 0.56.1's CMakeLists requires `find_package(glaze 7...<8)`,
          # but nixpkgs ships glaze 8.0.0, so CMake falls back to FetchContent
          # (git clone) which fails in the sandboxed build. Pin glaze 7.9.1 until
          # hyprland supports glaze 8. hyprshutdown (same 7.x requirement) also
          # benefits. Drop once nixpkgs' hyprland builds against glaze 8.
          nixpkgs.overlays = [
            (final: prev: {
              glaze = prev.glaze.overrideAttrs (old: {
                version = "7.9.1";
                src = prev.fetchFromGitHub {
                  owner = "stephenberry";
                  repo = "glaze";
                  tag = "v7.9.1";
                  hash = "sha256-NRRq5MGF2f5PW0teYnq58ELzson+U6KHVPaY6r30KLA=";
                };
              });
            })
          ];
        }
        inputs.home-manager.nixosModules.home-manager
        ({pkgs, ...}: {
          home-manager = {
            extraSpecialArgs = {inherit inputs username;};
            useGlobalPkgs = true;
            sharedModules = [
              # nixvim's Home Manager module (and the nixpkgs source pin) are
              # brought in by inputs.mozart409-nixvim.homeModules.default, which
              # wotan's home.nix imports.
              inputs.agenix.homeManagerModules.default
              # nix-index with the prebuilt database; provides the
              # `programs.nix-index-database.comma.enable` option in home configs.
              inputs.nix-index-database.homeModules.default
            ];
            users.${username} = import ../hosts/${hostname}/home.nix;
          };
        })
      ];
    };
}
