{
  lib,
  inputs,
  nixpkgs,
}: let
  # Shared nixpkgs config — single source of truth for all nixos and
  # home-manager evaluations.  cudaSupport is included here because it
  # affects the package set that the cache.nixos-cuda.org substituter
  # carries (vLLM, torch, etc.).
  sharedNixpkgsConfig = {
    allowUnfree = true;
    cudaSupport = true;
    permittedInsecurePackages = [
      # anytype currently links against EOL Electron; upstream controls bumps.
      "electron-39.8.10"
      # vLLM 0.16.0 — three CVEs documented in modules/nixos/vllm.nix.
      # Mitigations: loopback-only bind, trusted-repo-only models. Drop when
      # nixpkgs ships vllm >= 0.20.0.
      "python3.13-vllm-0.16.0"
    ];
  };
in {
  inherit sharedNixpkgsConfig;

  # Helper function to generate host configurations.
  # Home-manager is integrated via the NixOS module so a single
  # `nixos-rebuild switch` activates both system and user config.
  # `username` is threaded through specialArgs (system) and extraSpecialArgs
  # (home) so shared modules stay reusable across hosts/users.
  mkHost = hostname: system: username:
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
            ];
            users.${username} = import ../hosts/${hostname}/home.nix;
          };
        })
      ];
    };
}
