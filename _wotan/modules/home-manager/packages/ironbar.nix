{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.desktop.ironbar;
in {
  options.desktop.ironbar = {
    enable = lib.mkEnableOption "ironbar";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.ironbar
    ];

    systemd.user.services.ironbar = {
      Unit = {
        Description = "Ironbar status bar";
        PartOf = ["graphical-session.target"];
      };

      Service = {
        ExecStart = "${inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.ironbar}/bin/ironbar";
        Restart = "on-failure";
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
