{
  config,
  pkgs,
  ...
}: {
  # Common Nix settings
  nix.settings = {
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Restrict to root only - wheel/users can still build, just not bypass sandbox
    trusted-users = ["root"];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixvim.cachix.org"
      "https://hyprland.cachix.org"
      "https://cache.garnix.io"
      "https://cache.nixos-cuda.org"
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-generations +5";
  };

  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
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

  # Suggest which nix package provides a missing command
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  # Periodic TRIM for SSD longevity
  services.fstrim.enable = true;

  # AppImage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
