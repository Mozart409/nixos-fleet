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
    # Pinned to 0.54.x (fcbbd6d) — 0.55.0 broke SUPER/mod-key bindings (a modifier-state
    # regression; binds register but never fire). See hyprwm/Hyprland#14099.
    # Unpin (drop the /<rev> suffix) once 0.55.x ships a fix, then `nix flake update hyprland`.
    hyprland.url = "github:hyprwm/Hyprland/fcbbd6d4d80033c40e3b702518e1a2ba3f479452";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };

    hypr-dynamic-cursors = {
      url = "github:VirtCode/hypr-dynamic-cursors";
      inputs.hyprland.follows = "hyprland"; # to make sure that the plugin is built for the correct version of hyprland
    };

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
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
    agenix,
    hyprland,
    hyprland-plugins,
    hypr-dynamic-cursors,
    hyprsunset,
    quickshell,
    disko,
    awww,
    rose-pine-hyprcursor,
    zinc-oxide,
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
      wotan = mkHost "wotan" system;
      # Add more hosts here:
      # laptop = mkHost "laptop" system;
      # server = mkHost "server" system;
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
