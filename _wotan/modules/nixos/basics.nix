{
  config,
  pkgs,
  username,
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
    trusted-users = ["root" username];
    substituters = [
      # Self-hosted attic (homelab `cache` host), on the wired LAN. Listed
      # first so local hits win over the public caches. The URL must include
      # the cache name — attic namespaces every binary-cache path under it, and
      # https://cache.homelab.local on its own is not a valid substituter.
      "https://cache.homelab.local/homelab"
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
      # cache.nixos.org builds. Those closures were pushed to the homelab
      # attic instead; `just attic-push` keeps them there after a rebuild.
    ];
    trusted-public-keys = [
      "homelab:aswnRAo2zbP13gGnUTCINX78X/lURQgPAfrgNpHpQpY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];

    # The homelab cache is a single VM on the HDD-backed zfs_pool, so it does go
    # away — reboots, a colmena apply against the `cache` host, or pool
    # contention. Without a short timeout nix waits out the default budget on
    # every path it wants to substitute, turning a cache outage into minutes of
    # stalling on an otherwise healthy build. `fallback` lets it build locally
    # instead of aborting when substitution fails outright.
    connect-timeout = 5;
    fallback = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    persistent = true;
    options = "--delete-older-than 7d";
  };

  programs.nh = {
    enable = true;
    flake = "/etc/nixos";
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
