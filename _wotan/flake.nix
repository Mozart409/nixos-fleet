{
  description = "NixOS multi-host configuration with home-manager and nixvim";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixvim.cachix.org"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
  } @ inputs: let
    # Helper function to generate host configurations
    mkHost = hostname: system: lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs;};
      modules = [
        ./hosts/${hostname}/default.nix
        {
          nix.settings.trusted-users = ["amadeus"];
        }
      ];
    };

    # Helper function to generate home-manager configurations
    mkHome = hostname: system: home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.${system};
      extraSpecialArgs = {inherit inputs;};
      modules = [
        ./hosts/${hostname}/home.nix
        inputs.nixvim.homeModules.nixvim
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
        nh
        alejandra
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
