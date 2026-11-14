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
