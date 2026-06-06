{
  lib,
  inputs,
  nixpkgs,
  home-manager,
}: let
  # Shared nixpkgs config — kept in sync between mkHost and mkHome so both
  # nixos and home-manager evaluations see the same allow/insecure lists.
  sharedNixpkgsConfig = {
    allowUnfree = true;
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
  # Helper function to generate host configurations
  mkHost = hostname: system:
    lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/${hostname}/default.nix
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config = sharedNixpkgsConfig;
        }
      ];
    };

  # Helper function to generate home-manager configurations
  mkHome = hostname: system: let
    pkgs = import nixpkgs {
      inherit system;
      config = sharedNixpkgsConfig;
    };
  in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {inherit inputs;};
      modules = [
        ../hosts/${hostname}/home.nix
        inputs.nixvim.homeModules.nixvim
        inputs.agenix.homeManagerModules.default
        {
          # Repeated here because setting any nixpkgs.* option in a home-manager
          # module makes it re-import nixpkgs and drop the config from `pkgs`.
          nixpkgs.config = sharedNixpkgsConfig;
          # Pin nixvim's nixpkgs source to ours — suppresses the warning about
          # `inputs.nixvim.inputs.nixpkgs.follows` skewing the default.
          programs.nixvim.nixpkgs.source = pkgs.path;
        }
      ];
    };
}
