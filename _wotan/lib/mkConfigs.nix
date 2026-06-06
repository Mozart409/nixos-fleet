{
  lib,
  inputs,
  nixpkgs,
  nixpkgs-stable,
  home-manager,
}: let
  # Helper to create pkgsStable - shared between mkHost and mkHome
  mkPkgsStable = system:
    import nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;
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
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = anytypeOverlay pkgsStable;
        }
      ];
    };

  # Helper function to generate home-manager configurations
  mkHome = hostname: system: let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
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
          nixpkgs.overlays = anytypeOverlay pkgsStable;
        }
      ];
    };
}
