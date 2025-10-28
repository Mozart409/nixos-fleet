{
  description = "NixOS configuration with home-manager and nixvim";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixvim.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixvim.cachix.org-1:tv1c7c4gHrNnf9p+5LxqC4WpF1cG5D9D+V7+F2M7Qw="
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
        pkgs = pkgs;
        extraSpecialArgs = {inherit inputs;};
        modules = [
          ./home.nix
          inputs.nixvim.homeModules.nixvim
          # inputs.plasma-manager.homeManagerModules.plasma-manager
        ];
      };
    };
  };
}
