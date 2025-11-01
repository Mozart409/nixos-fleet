{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  # Home Manager needs basic information
  home.username = "amadeus";
  home.homeDirectory = "/home/amadeus";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Common development tools
  home.packages = with pkgs; [
    # Development Tools
    fabric-ai
    opencode
    nixos-anywhere
    nixos-generators
    eza
    cocogitto
    mergiraf
    rustscan
    rustup
    bacon
    nodejs_22
    tpi
    talosctl
    kubie
    hcloud
    jq
    pnpm
    rainfrog
    lazydocker
    cargo-binstall
    dioxus-cli
    wasm-bindgen-cli
    pwgen
    devenv
    nix-prefetch
    nix-prefetch-github
    dprint
    pkg-configUpstream

    # Kubernetes & Cloud Tools
    kubectl
    kubernetes-helm
    helm-ls
    helmsman
    helmfile

    # Database Tools
    duckdb
    sqlite
    sqlitestudio
    sqlite-analyzer

    # System Utilities
    busybox
    nettools
    file
    nh
    just
    xclip
    bat
    glow
    gparted
    rclone
    vulnix
    nvtopPackages.full
    steam-devices-udev-rules

    # Desktop Applications
    krita
    anytype
    haruna
    chromium
    teamspeak6-client
    signal-desktop-bin
    comet-gog
    discord
    gnome-boxes
    mangojuice
    ladybird

    # Privacy & Security
    tor
    torsocks
    tor-browser

    # Customization & Fun
    charasay
    fortune
    dwt1-shell-color-scripts
    cowsay
    bluejay
    nerd-fonts.jetbrains-mono
    kdePackages.kwallet-pam
    openrgb-with-all-plugins
  ];

  # Common session variables
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [
    "/var/lib/flatpak/exports/share"
    "/home/amadeus/.local/share/flatpak/exports/share"
  ];

  # Common shell configuration
  programs.zsh = {
    enable = true;
    autocd = true;
    zprof.enable = false;
    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    shellAliases = {
      l = "ls -lah";
      lg = "lazygit";
      ld = "lazydocker";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      flk = "cd /etc/nixos";
      dps = "docker compose ps";
      dup = "docker compose up -d --build --remove-orphans";
      dwn = "docker compose down";
      n = "nvim .";
    };
    oh-my-zsh = {
      enable = true;
      theme = "fino";
      plugins = [
        "git"
        "z"
        "fzf"
      ];
    };
  };

  # Common program configurations
  programs = {
    fastfetch.enable = true;
    ripgrep.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
    k9s.enable = true;
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    git = {
      enable = true;
      settings = {
        user.name = "Amadeus Mader";
        user.email = "amadeus@mozart409.com";
        aliases = {
          ci = "commit";
          s = "status";
          f = "fetch";
        };
        signing = {
          signByDefault = true;
          format = "ssh";
        };
        init.defaultBranch = "main";
        pull.rebase = "true";
        credential = {
          helper = "oauth";
          cache = "--timeout 21600";
        };
      };
      ignores = [
        "*~"
        "*.swp"
      ];
    };
    lazygit = {
      enable = true;
      settings.gui.theme = {
        activeBorderColor = ["#89b4fa" "bold"];
        inactiveBorderColor = ["#a6adc8"];
        optionsTextColor = ["#89b4fa"];
        selectedLineBgColor = ["#313244"];
        selectedRangeBgColor = ["#313244"];
        unstagedChangesColor = ["#f38ba8"];
        defaultFgColor = ["#cdd6f4"];
        searchingActiveBorderColor = ["#f9e2af"];
      };
    };
    home-manager.enable = true;
  };

  # GPG agent configuration
  services.gpg-agent.extraConfig = "pinentry-program ${pkgs.pinentry-gtk2}/bin/pinentry";

  # Home Manager state version
  home.stateVersion = "24.11";
}
