{pkgs, ...}: {
  environment.systemPackages = [pkgs.boxflat];

  # Boxflat ships 99-boxflat.rules (ttyACM management channel + uinput).
  services.udev.packages = [pkgs.boxflat];

  # Extra: hidraw access for MOZA / Gudsen wheelbases (VID 346e).
  # uaccess grants RW to the seated user via logind ACLs; 0660 is the
  # baseline fallback when no seat is active.
  services.udev.extraRules = ''
    SUBSYSTEM=="hidraw", ATTRS{idVendor}=="346e", MODE="0660", TAG+="uaccess"
  '';
}
