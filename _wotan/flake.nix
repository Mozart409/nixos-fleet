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
    colmena = {
      url = "github:zhaofengli/colmena";
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
    colmena,
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
      minimal = mkHost "minimal" system;
      wotan = mkHost "wotan" system;
      rulemesh-o11y = mkHost "rulemesh-o11y" system;
      servarr = mkHost "servarr" system;
      # Add more hosts here:
      # laptop = mkHost "laptop" system;
      # server = mkHost "server" system;
    };

    # Home-manager configurations for each user/host
    homeConfigurations = {
      "amadeus@minimal" = mkHome "minimal" system;
      "amadeus@wotan" = mkHome "wotan" system;
      "amadeus@rulemesh-o11y" = mkHome "rulemesh-o11y" system;
      "amadeus@servarr" = mkHome "servarr" system;
      # Add more user/host combinations here:
      # "amadeus@laptop" = mkHome "laptop" system;
      # "user@server" = mkHome "server" system;
    };

    # Nixos Generator
    packages."x86_64-linux".minimal-pve = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [
        ({pkgs, ...}: {
          # set disk size to to 20G
          virtualisation.diskSize = 20 * 1024;
          system.stateVersion = "25.11";
          /*
             users.defaultUserShell = pkgs.zsh;
          environment.shells = with pkgs; [zsh];
          */
        })
        ./hosts/minimal/default.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.amadeus = import ./hosts/minimal/home.nix;
          home-manager.sharedModules = [inputs.nixvim.homeModules.nixvim];
        }
      ];
      format = "proxmox-lxc";
    };

    # Colmena configuration for multi-host deployment
    colmenaHive = colmena.lib.makeHive {
      meta = {
        nixpkgs = import nixpkgs {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
        specialArgs = {inherit inputs;};
      };

      rulemesh-o11y = {
        deployment = {
          targetHost = "192.168.2.120";
          targetUser = "amadeus";
          targetPort = 22;
          buildOnTarget = false;
        };
        imports = [
          ./hosts/rulemesh-o11y/default.nix
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nix.settings.trusted-users = ["amadeus"];
          }
        ];
      };
      servarr = {
        deployment = {
          targetHost = "192.168.2.188";
          targetUser = "amadeus";
          targetPort = 22;
          buildOnTarget = false;
          sshOptions = ["-i" "~/.ssh/id_ed25519"];
        };
        imports = [
          ./hosts/servarr/default.nix
          {
            nixpkgs.hostPlatform = "x86_64-linux";
            nix.settings.trusted-users = ["amadeus"];
            nix.settings.substituters = [];
            nix.settings.extra-substituters = [];
          }
        ];
      };
    };

    # Development shell for working with this configuration
    devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
      buildInputs = with nixpkgs.legacyPackages.${system}; [
        git
        alejandra
        lefthook
        colmena.packages.${system}.colmena
      ];
      shellHook = ''
        echo "Welcome to the NixOS configuration development shell!"
        echo "Available commands:"
        echo "  nix flake check .#nixosConfigurations.wotan"
        echo "  nix flake check .#homeConfigurations.amadeus@wotan"
        echo "  sudo nixos-rebuild switch --flake .#wotan"
        echo "  home-manager switch --flake .#amadeus@wotan"
      '';
    };
  };
}
