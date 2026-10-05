# Shared by every machine: the fleet (via modules/common.nix) AND the desktop
# wotan. Only settings both sides want identically go here -- nothing that
# opens a port, starts a daemon or loosens sudo. Server-only config lives in
# modules/server.nix, which wotan must never import (its no-sshd assertion in
# hosts/wotan/default.nix fails evaluation if it does).
{...}: {
  imports = [
    ./homelab-users.nix
    ./just-completions.nix
    ./nh.nix
  ];

  # Timezone configuration
  time.timeZone = "Europe/Berlin";

  # Locale and keyboard settings
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

  # Console keymap (the console font is server-only, see server.nix)
  console.keyMap = "de";

  # Enable nix flakes
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # Trust the amadeus user for remote builds
  nix.settings.trusted-users = ["root" "amadeus"];

  # Common user configuration. Adding another person is one attribute here (or
  # in a host config) -- see modules/homelab-users.nix. SSH keys are added by
  # server.nix: only hosts that run sshd authorize anyone.
  homelab.users.amadeus = {
    isAdmin = true;
    extraGroups = ["networkmanager"];
  };
}
