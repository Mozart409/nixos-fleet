{
  config,
  pkgs,
  username,
  ...
}: let
  # Runs as root (nix-daemon) after every successful local build. Logging in
  # every run is cheap and local-only (no network round trip), and keeps the
  # token in sync if the agenix secret is ever rotated.
  #
  # nix-daemon only waits for this script's own exit, not its descendants, so
  # the actual push is handed off to a detached background job with a hard
  # timeout and this script returns immediately. A synchronous `attic push`
  # walks the full closure of whatever just built, which can take a very long
  # time on a big rebuild -- on 2026-08-24 that hung `nh os switch` on the
  # trivial `system-units` derivation for 17+ minutes with no cache outage and
  # no build error, just a slow closure walk blocking the daemon. Never do
  # this synchronously again.
  postBuildHook = pkgs.writeShellScript "attic-push" ''
    set -eu
    set -f # disable globbing so $OUT_PATHS word-splits safely
    export IFS=' '
    export HOME=/root

    (
      set -o pipefail
      token="$(${pkgs.coreutils}/bin/cat ${config.age.secrets.attic-token.path})"
      ${pkgs.attic-client}/bin/attic login homelab https://cache.homelab.local/homelab "$token" >/dev/null 2>&1 || true
      ${pkgs.coreutils}/bin/timeout 300 ${pkgs.attic-client}/bin/attic push -j 5 homelab $OUT_PATHS 2>&1 \
        | ${pkgs.util-linux}/bin/logger -t attic-push \
        || ${pkgs.util-linux}/bin/logger -t attic-push "push failed or timed out"
    ) </dev/null >/dev/null 2>&1 &
    disown
  '';
in {
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

    # Auto-push every locally-built path (system generations included) to the
    # homelab attic cache -- this is what `just attic-push`/`attic-push-host`
    # used to require running by hand. post-build-hook runs as the nix-daemon
    # (root), outside the build sandbox, so it has network access and needs
    # its own attic login; it reuses the same admin push token from
    # `attic login homelab ...` that ~/.config/attic/config.toml already has,
    # stored as the agenix secret age.secrets.attic-token (hosts/wotan/default.nix).
    # A cache outage must never fail a build/switch, so both the login and the
    # push are best-effort (`|| true` / logged-and-swallowed failure).
    post-build-hook = "${postBuildHook}";
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
