{
  config,
  pkgs,
  lib,
  username,
  ...
}: {
  # Home Manager needs basic information
  home.username = username;
  home.homeDirectory = "/home/${username}";

  # Common session variables
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [];

  # GPG agent. This is the agent that actually runs -- the NixOS-level
  # programs.gnupg.agent in modules/wotan/common-packages.nix configures a
  # different one, and its pinentryPackage does not reach this service.
  #
  # gpg-agent also backs SSH here (SSH_AUTH_SOCK points at S.gpg-agent.ssh), so
  # this prompt is what appears for git commit signing as well as gpg.
  services.gpg-agent = {
    enable = true;

    # Passphrase cache. sops decrypts project .sops.env files through this
    # agent (modules/home/packages/sops.nix), so these TTLs are the
    # trade-off between prompts and how long a warm cache lets any process --
    # including an AI agent running `just dev` -- decrypt silently. The idle
    # TTL resets on every use; the max TTL is a hard ceiling from first unlock.
    defaultCacheTtl = 3600; # 1h idle
    maxCacheTtl = 28800; # 8h hard cap

    # pinentry-rofi renders the passphrase prompt through rofi, so it inherits
    # the theme in ../packages/rofi/theme.rasi and matches the bar, launcher
    # and notifications instead of being a lone GTK dialog. `program` is needed
    # because the package ships bin/pinentry-rofi, not bin/pinentry.
    #
    # BACKUP -- to go back, set package = pkgs.pinentry-gnome3 and program =
    # "pinentry-gnome3". Worth knowing: if this prompt ever fails to appear you
    # cannot sign commits or decrypt agenix secrets, and the failure looks like
    # "agent refused operation" rather than anything about pinentry.
    pinentry = {
      package = pkgs.pinentry-rofi;
      program = "pinentry-rofi";
    };
  };

  # Home Manager state version
  home.stateVersion = "24.11";
}
