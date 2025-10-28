{
  config,
  pkgs,
  ...
}: {
  # Common system packages that should be available on all hosts
  environment.systemPackages = with pkgs; [
    vim # Essential editor
    wget
    curl
    git
    nh
    alejandra
    pinentry-curses
    pinentry-gnome3
    dig
  ];

  # Common programs that should be enabled on all hosts
  programs = {
    zsh.enable = true;
    firefox.enable = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };

  # Common services that should be enabled on all hosts
  services = {
    pcscd.enable = true;
    dbus.packages = [pkgs.gcr];
    flatpak.enable = true;
  };

  # Common systemd services
  systemd.services.flatpak-repo = {
    wantedBy = ["multi-user.target"];
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  # Common Nix settings
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "user"
      "@wheel"
      "amadeus"
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-generations +3";
  };

  # Allow unfree packages on all hosts
  nixpkgs.config.allowUnfree = true;

  # Common user configuration
  users.users.amadeus = {
    isNormalUser = true;
    description = "amadeus";
    extraGroups = ["networkmanager" "wheel"];
    shell = pkgs.zsh;
  };

  users.defaultUserShell = pkgs.zsh;
  environment.shells = with pkgs; [zsh];

  # Common networking settings
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
  };

  # Common time and locale settings
  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Common console settings
  console.keyMap = "de";

  # Common printing support
  services.printing.enable = true;
}

