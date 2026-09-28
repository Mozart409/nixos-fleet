{
  description = "NixOS multi-host configuration with home-manager and nixvim";

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
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland.url = "github:hyprwm/Hyprland";
    hyprsunset.url = "github:hyprwm/hyprsunset";

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

    # Cursor themes
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zinc-oxide = {
      url = "github:Mozart409/zinc_oxide";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Neovim (nixvim) configuration, moved out to its own public repo so it
    # can be reused at work with plain Nix + Home Manager. Its nixvim/nixpkgs
    # follow ours so we don't pull in a second copy.
    mozart409-nixvim = {
      url = "github:Mozart409/mozart409-nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixvim.follows = "nixvim";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
    agenix,
    hyprland,
    hyprsunset,
    quickshell,
    disko,
    awww,
    rose-pine-hyprcursor,
    zinc-oxide,
    mozart409-nixvim,
  } @ inputs: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

    helpers = import ./lib/mkConfigs.nix {
      inherit lib inputs nixpkgs;
    };
    inherit (helpers) mkHost sharedNixpkgsConfig;
  in {
    # NixOS configurations for each host
    nixosConfigurations = {
      wotan = mkHost "wotan" system "amadeus";
      # Add more hosts here (mkHost hostname system username):
      # laptop = mkHost "laptop" system "amadeus";
      # server = mkHost "server" system "amadeus";
    };

    # Development shell for working with this configuration
    devShells.${system}.default = let
      pkgs = import nixpkgs {
        inherit system;
        config = sharedNixpkgsConfig;
      };
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          alejandra
          shellcheck
          lefthook
          opencode
          cocogitto
          claude-code
          agenix.packages.${system}.default
        ];
        shellHook = ''
          echo "Welcome to the NixOS configuration development shell!"
          echo "Available commands:"
          echo "  nix flake check .#nixosConfigurations.wotan"
          echo "  sudo nixos-rebuild switch --flake .#wotan"
          lefthook install
          cog install-hook
        '';
      };
  };
}
