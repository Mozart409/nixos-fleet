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
        { type = "music" },
        { type = "volume" },
        { type = "notifications" },
        { type = "tray" }
      ]
    '';

    xdg.configFile."ironbar/style.css".text = ''
      * {
        font-family: "FiraCode Nerd Font", monospace;
        font-size: 14px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      .background {
        background-color: #1a1a1f;
      }

      .container {
        padding: 0 8px;
      }

      .workspaces .item {
        padding: 0 8px;
        margin: 0 2px;
        border-radius: 6px;
        transition: background-color 200ms;
      }

      .workspaces .item.focused {
        background-color: #33ccff;
        color: #1a1a1f;
      }

      .workspaces .item.visible {
        background-color: #00ff99;
        color: #1a1a1f;
      }

      .workspaces .item:hover {
        background-color: #2a2a2f;
      }

      .focused {
        color: #e6e9ef;
        padding: 0 12px;
      }

      .clock {
        color: #cfd6f4;
        padding: 0 12px;
      }

      .music, .volume, .backlight, .notifications {
        color: #cfd6f4;
        padding: 0 8px;
      }

      .tray {
        padding: 0 8px;
      }

      .tray .item {
        padding: 0 4px;
      }
    '';

    systemd.user.targets.hyprland-session = {
      Unit = {
        Description = "Hyprland compositor session";
        Documentation = "man:systemd.special(7)";
        BindsTo = ["graphical-session.target"];
        Wants = ["graphical-session-pre.target"];
        After = ["graphical-session-pre.target"];
      };
    };

    systemd.user.services.ironbar = {
      Unit = {
        Description = "Ironbar status bar";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        ExecStart = "${inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.ironbar}/bin/ironbar";
        Restart = "on-failure";
        RestartSec = 3;
        Environment = [
          "PATH=${pkgs.bash}/bin:${pkgs.coreutils}/bin"
        ];
      };

      Install = {
        WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
