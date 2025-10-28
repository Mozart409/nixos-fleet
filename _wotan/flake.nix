{
  description = "A very basic flake";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"

      # nix community's cache server
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      # nix community's cache server public key
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
  } @ inputs: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    nixosConfigurations = {
      wotan = lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};

        modules = [
          ./configuration.nix
          {
            nix.settings.trusted-users = [
              "amadeus"
            ];
          }
        ];
      };
    };

    homeConfigurations = {
      amadeus = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home.nix
          inputs.nixvim.homeModules.nixvim
          # inputs.plasma-manager.homeManagerModules.plasma-manager
        ];
      };
    };
  };
}
