{
  config,
  pkgs,
  ...
}: {
  # To make flathub work
  xdg.portal.enable = true;

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
}
