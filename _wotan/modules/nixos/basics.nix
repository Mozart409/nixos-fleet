{
  config,
  pkgs,
  ...
}: {
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

  # AppImage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
