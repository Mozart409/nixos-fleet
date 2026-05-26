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

  # Install Bottles for running Windows apps (SimHub, etc.).
  #
  # Permissions:
  #   --device=all      Required for /dev/ttyACM* (MOZA base, Arduino dashes)
  #                     and /dev/hidraw* / /dev/input/* — Flatpak has no
  #                     finer-grained option that exposes character device
  #                     nodes. Scope is /dev only, not arbitrary host files.
  #   --nofilesystem=host
  #                     Explicitly revoke full-home access in case a prior
  #                     activation set it. Bottles' default sandbox already
  #                     covers xdg-download (drag-in installers) and its own
  #                     app data dir.
  systemd.services.flatpak-bottles = {
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "flatpak-repo.service"];
    wants = ["network-online.target"];
    requires = ["flatpak-repo.service"];
    path = [pkgs.flatpak];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      flatpak install -y --noninteractive flathub com.usebottles.bottles
      flatpak override com.usebottles.bottles \
        --nofilesystem=host \
        --device=all
    '';
  };
}
