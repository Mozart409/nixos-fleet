{
  lib,
  inputs,
  nixpkgs,
  nixpkgs-stable,
  home-manager,
}: let
  # Helper to create pkgsStable - shared between mkHost and mkHome
  # Shared nixpkgs config — kept in sync between mkHost and mkHome so both
  # nixos and home-manager evaluations see the same allow/insecure lists.
  sharedNixpkgsConfig = {
    allowUnfree = true;
    permittedInsecurePackages = [
      # Required by anytype (overlaid from nixpkgs-stable). EOL Electron release;
      # the upstream anytype team controls when this gets bumped.
      "electron-39.8.10"
      # vLLM 0.16.0 — three CVEs documented in modules/nixos/vllm.nix.
      # Mitigations: loopback-only bind, trusted-repo-only models. Drop when
      # nixpkgs ships vllm >= 0.20.0.
      "python3.13-vllm-0.16.0"
    ];
  };

  mkPkgsStable = system:
    import nixpkgs-stable {
      inherit system;
      config = sharedNixpkgsConfig;
    };

  # Shared overlay for anytype package
  anytypeOverlay = pkgsStable: [
    (final: prev: {
      anytype = pkgsStable.anytype;
    })
  ];
in {
  # Helper function to generate host configurations
  mkHost = hostname: system: let
    pkgsStable = mkPkgsStable system;
  in
    lib.nixosSystem {
      specialArgs = {inherit inputs;};
      modules = [
        ../hosts/${hostname}/default.nix
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config = sharedNixpkgsConfig;
          nixpkgs.overlays = anytypeOverlay pkgsStable;
        }
      ];
    };

  # Helper function to generate home-manager configurations
  mkHome = hostname: system: let
    pkgs = import nixpkgs {
      inherit system;
      config = sharedNixpkgsConfig;
    };
    pkgsStable = mkPkgsStable system;
  in
    home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {inherit inputs;};
      modules = [
        ../hosts/${hostname}/home.nix
        inputs.nixvim.homeModules.nixvim
        inputs.agenix.homeManagerModules.default
        {
          # Setting `nixpkgs.overlays` here makes home-manager re-import nixpkgs
          # internally — which drops the `config` from our outer `pkgs` import.
          # We therefore have to repeat the config so allow-lists survive.
          nixpkgs.config = sharedNixpkgsConfig;
          nixpkgs.overlays = anytypeOverlay pkgsStable;
          # Pin nixvim's nixpkgs source to ours — suppresses the warning about
          # `inputs.nixvim.inputs.nixpkgs.follows` skewing the default.
          programs.nixvim.nixpkgs.source = pkgs.path;
        }
      ];
    };
}
