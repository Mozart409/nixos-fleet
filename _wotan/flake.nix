{
  description = "NixOS multi-host configuration with home-manager and nixvim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors";
      inputs.hyprland.follows = "hyprland"; # to make sure that the plugin is built for the correct version of hyprland
    };

    hyprsunset.url = "github:hyprwm/hyprsunset";

    ironbar = {
      url = "github:JakeStanger/ironbar";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Disko - Declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    awww.url = "git+https://codeberg.org/LGFae/awww";
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    nixvim,
    agenix,
    hyprland,
    hyprland-plugins,
    hypr-dynamic-cursors,
    hyprsunset,
    ironbar,
    quickshell,
    disko,
    awww,
  } @ inputs: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

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

    # Helper function to generate host configurations
    mkHost = hostname: system: let
      pkgsStable = mkPkgsStable system;
    in
      lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/${hostname}/default.nix
          {
            nixpkgs.hostPlatform = system;
            nix.settings.trusted-users = ["amadeus"];
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
          ./hosts/${hostname}/home.nix
          inputs.nixvim.homeModules.nixvim
          {
            nixpkgs.overlays = anytypeOverlay pkgsStable;
          }
        ];
      };
  in {
    # NixOS configurations for each host
    nixosConfigurations = {
      wotan = mkHost "wotan" system;
      # Add more hosts here:
      # laptop = mkHost "laptop" system;
      # server = mkHost "server" system;
    };

    # Home-manager configurations for each user/host
    homeConfigurations = {
      "amadeus@wotan" = mkHome "wotan" system;
      # Add more user/host combinations here:
      # "amadeus@laptop" = mkHome "laptop" system;
      # "user@server" = mkHome "server" system;
    };

    # Development shell for working with this configuration
    devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
      buildInputs = with nixpkgs.legacyPackages.${system}; [
        git
        alejandra
        lefthook
        opencode
        cocogitto
      ];
      shellHook = ''
        echo "Welcome to the NixOS configuration development shell!"
        echo "Available commands:"
        echo "  nix flake check .#nixosConfigurations.wotan"
        echo "  nix flake check .#homeConfigurations.amadeus@wotan"
        echo "  sudo nixos-rebuild switch --flake .#wotan"
        echo "  home-manager switch --flake .#amadeus@wotan"
        lefthook install
        cog install-hook
      '';
    };
  };
}
