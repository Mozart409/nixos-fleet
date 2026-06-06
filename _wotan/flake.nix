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

    llama-cpp = {
      url = "github:ggml-org/llama.cpp";
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

    # Cursor themes
    rose-pine-hyprcursor = {
      url = "github:ndom91/rose-pine-hyprcursor";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zinc-oxide = {
      url = "git+file:///home/amadeus/code/rust/zinc_oxide";
      flake = false;
    };
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
    llama-cpp,
    quickshell,
    disko,
    awww,
    rose-pine-hyprcursor,
    zinc-oxide,
  } @ inputs: let
    lib = nixpkgs.lib;
    system = "x86_64-linux";

    helpers = import ./lib/mkConfigs.nix {
      inherit lib inputs nixpkgs nixpkgs-stable home-manager;
    };
    inherit (helpers) mkHost mkHome;
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
    devShells.${system}.default = let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
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
          echo "  nix flake check .#homeConfigurations.amadeus@wotan"
          echo "  sudo nixos-rebuild switch --flake .#wotan"
          echo "  home-manager switch --flake .#amadeus@wotan"
          lefthook install
          cog install-hook
        '';
      };
  };
}
