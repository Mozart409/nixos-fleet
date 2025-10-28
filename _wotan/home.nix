{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  imports = [
    # inputs.nixvim.homeManagerModules.nixvim
    # ./nixvim.nix
    ./kickstart.nixvim/nixvim.nix
    ./terminals.nix
    ./tmux.nix
  ];
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "amadeus";
  home.homeDirectory = "/home/amadeus";

  nixpkgs.config.allowUnfree = true;

  services.gpg-agent.extraConfig = "pinentry-program ${pkgs.pinentry-gtk2}/bin/pinentry";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.packages = with pkgs; [
    fabric-ai
    opencode
    krita
    charasay
    fortune
    dwt1-shell-color-scripts
    cowsay
    bluejay
    anytype
    nixos-anywhere
    vlc
    chromium
    teamspeak6-client
    nixos-generators
    signal-desktop-bin
    comet-gog
    eza
    cocogitto
    mergiraf
    discord
    busybox
    kdePackages.kwallet-pam
    nettools
    openrgb-with-all-plugins
    kubectl
    xclip
    nh
    nerd-fonts.jetbrains-mono
    gnome-boxes
    just
    rustscan
    rustup
    bacon
    nettools
    nodejs_22
    tpi
    talosctl
    kubie
    kubectl
    hcloud
    jq
    pnpm
    rainfrog
    lazydocker
    gparted
    steam-devices-udev-rules
    rclone
    vulnix
    mangojuice
    tor
    torsocks
    tor-browser
    dprint
    nvtopPackages.full
    kubernetes-helm
    helm-ls
    helmsman
    helmfile
    duckdb
    sqlite
    sqlitestudio
    sqlite-analyzer
    bat
    cargo-binstall
    dioxus-cli
    file
    wasm-bindgen-cli
    pwgen
    devenv
    nix-prefetch
    nix-prefetch-github
    glow
    pkg-configUpstream
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };
  home.sessionPath = [
    "/var/lib/flatpak/exports/share"
    "/home/amadeus/.local/share/flatpak/exports/share"
  ];
  programs.zsh = {
    enable = true;
    autocd = true;
    zprof.enable = false;
    historySubstringSearch.enable = true;
    syntaxHighlighting = {
      enable = true;
    };
    autosuggestion = {
      enable = true;
    };
    shellAliases = {
      l = "ls -lah";
      lg = "lazygit";
      k = "kubectl";
      flk = "cd /etc/nixos";
      dps = "docker compose ps";
      dup = "docker compose up -d --build --remove-orphans";
      dwn = "docker compose down";
      ld = "lazydocker";
      n = "nvim .";
    };
    oh-my-zsh = {
      enable = true;
      # theme = "wezm";
      theme = "fino";
      plugins = [
        "git"
        "z"
        "fzf"
      ];
    };
  };

  programs.fastfetch = {
    enable = true;
  };
  programs.ripgrep = {
    enable = true;
  };
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };
  programs.k9s = {
    enable = true;
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.git = {
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
  programs.lazygit = {
    enable = true;
    settings.gui.theme = {
      activeBorderColor = [
        "#89b4fa"
        "bold"
      ];
      inactiveBorderColor = ["#a6adc8"];
      optionsTextColor = ["#89b4fa"];
      selectedLineBgColor = ["#313244"];
      selectedRangeBgColor = ["#313244"];
      unstagedChangesColor = ["#f38ba8"];
      defaultFgColor = ["#cdd6f4"];
      searchingActiveBorderColor = ["#f9e2af"];
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
