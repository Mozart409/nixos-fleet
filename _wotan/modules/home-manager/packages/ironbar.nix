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

    xdg.configFile."ironbar/config.toml".text = ''
      [[bar]]
      position = "top"
      height = 30

      start = [
        { type = "workspaces" },
        { type = "focused" }
      ]

      center = [
        { type = "clock", format = "%a %d %b %H:%M" }
      ]

      end = [
        { type = "script", cmd = "${config.home.homeDirectory}/toolbox/zinc_oxide -p ${config.home.homeDirectory}/code -c", interval = 300000 },
        { type = "music" },
        { type = "volume" },
        { type = "backlight" },
        { type = "notifications" },
        { type = "tray" }
      ]
    '';

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
