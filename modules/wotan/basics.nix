{username, ...}: {
  # Common Nix settings
  nix.settings = {
    auto-optimise-store = true;
    max-jobs = "auto";
    cores = 0;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = ["root" username];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixvim.cachix.org"
      "https://hyprland.cachix.org"
      "https://cache.nixos-cuda.org"
      # cache.garnix.io was here. garnix shut down on 2026-07-15 and deletes
      # user data; the host now serves 502 on every request, including
      # /nix-cache-info, which hard-fails eval (see the comment in switch.sh).
      # Do not re-add it. It was the only source for the unfree set — the
      # nvidia-x11 stack, discord, obsidian, claude-code — none of which
      # cache.nixos.org builds. The homelab attic that took over that job was
      # decommissioned on 2026-09-23, so the unfree set is now always built
      # locally.
    ];
    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];

    # Caches do go away. Without a short timeout nix waits out the default
    # budget on every path it wants to substitute, turning a cache outage into
    # minutes of stalling on an otherwise healthy build. `fallback` lets it
    # build locally instead of aborting when substitution fails outright.
    connect-timeout = 5;
    fallback = true;
    min-free = 20 * 1024 * 1024 * 1024;
    max-free = 40 * 1024 * 1024 * 1024;
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    persistent = true;
    options = "--delete-generations +3";
  };

  programs.nh = {
    enable = true;
    flake = "/home/amadeus/code/yggdrasil";
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

  # Periodic TRIM for SSD longevity
  services.fstrim.enable = true;

  # AppImage support
  programs.appimage = {
    enable = true;
    binfmt = true;
  };
}
