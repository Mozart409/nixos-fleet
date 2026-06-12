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
  mkHost = hostname: system:
    lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/${hostname}/default.nix
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config = sharedNixpkgsConfig;
        }
        inputs.home-manager.nixosModules.home-manager
        ({pkgs, ...}: {
          home-manager = {
            extraSpecialArgs = {inherit inputs;};
            useGlobalPkgs = true;
            sharedModules = [
              inputs.nixvim.homeModules.nixvim
              inputs.agenix.homeManagerModules.default
              {
                # Pin nixvim's nixpkgs source to ours — suppresses the
                # warning about `inputs.nixvim.inputs.nixpkgs.follows`
                # skewing the default.
                programs.nixvim.nixpkgs.source = pkgs.path;
              }
            ];
            users.amadeus = import ../hosts/${hostname}/home.nix;
          };
        })
      ];
    };
}
