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
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
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
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Theme
    mac-style-plymouth = {
      url = "github:SergioRibera/s4rchiso-plymouth-theme";
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
    nixos-generators,
    agenix,
    hyprland,
    hyprland-plugins,
    hypr-dynamic-cursors,
    hyprsunset,
    ironbar,
    quickshell,
    caelestia-shell,
    mac-style-plymouth,
    disko,
    awww,
  } @ inputs: let
    # Helper function to generate host configurations
    mkHost = hostname: system: let
      pkgsStable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
      lib.nixosSystem {
        specialArgs = {inherit inputs;};
        modules = [
          ./hosts/${hostname}/default.nix
          {
            nixpkgs.hostPlatform = system;
            nix.settings.trusted-users = ["amadeus"];
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = [
              (final: prev: {
                anytype = pkgsStable.anytype;
              })
            ];
          }
        ];
      };

    # Helper function to generate home-manager configurations
    mkHome = hostname: system: let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      pkgsStable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          ./hosts/${hostname}/home.nix
          inputs.nixvim.homeModules.nixvim
          {
            nixpkgs.overlays = [
              (final: prev: {
                anytype = pkgsStable.anytype;
              })
            ];
          }
        ];
      };

    lib = nixpkgs.lib;
    system = "x86_64-linux";
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
