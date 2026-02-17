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
      position = "top"
      height = 30

      [[start]]
      type = "workspaces"

      [[start]]
      type = "music"
      player_type = "mpris"
      truncate.mode = "end"
      truncate.max_length = 30

      [[center]]
      type = "clock"
      format = "%a %d %b %H:%M"

      [[end]]
      type = "script"
      cmd = "timeout 3 ${config.home.homeDirectory}/toolbox/zinc_oxide --compact || echo '?'"
      mode = "poll"
      interval = 600000

      [[end]]
      type = "script"
      cmd = "${config.xdg.configHome}/ironbar/scripts/disk-free.sh"
      mode = "poll"
      interval = 60000

      [[end]]
      type = "volume"
    '';

    xdg.configFile."ironbar/style.css".text = ''
      :root {
          --color-dark-primary: #1c1c1caa;
          --color-dark-secondary: #2d2d2daa;

          --color-border-dark: #776DE844;
          --color-border-light: #776DE822;

          --color-white: #fff;
          --color-active: #776DE8CC;
          --color-urgent: #8f0a0a;

          --gradient: linear-gradient(90deg, #6699CC19 35%, #CC99CC19 100%);

          --margin-lg: 1em;
          --margin-sm: 0.5em;
          --margin-xs: 0.25em;

          --size-xxl: 2.6em;
          --size-xl: 2.2em;
          --size-lg: 1.5em;
          --size-md: 16px;
      }

      * {
          font-family: sans-serif;
          font-size: var(--size-md);
          border-radius: 0;
          border: none;
          box-shadow: none;
      }

      popover, popover contents {
          border-radius: 12px;
          padding: 0;
      }

      window, popover {
          background-color: var(--color-dark-secondary);
      }

      box, button, label, calendar {
          background-color: #0000;
      }

      #bar, popover contents {
          background: var(--gradient);
      }

      scale.horizontal highlight {
          background: linear-gradient(90deg, #6699CCCC 35%, #CC99CCB2 100%);
      }

      scale.vertical highlight {
          background: linear-gradient(0, #6699CCCC 35%, #CC99CCB2 100%);
      }

      slider {
          border-radius: 100%;
      }

      button {
          padding-left: var(--margin-sm);
          padding-right: var(--margin-sm);
      }

      button:hover, button:active {
          background-color: var(--color-dark-secondary);
      }

      dropdown popover row:hover, dropdown popover row:focus, dropdown popover row:selected {
          background-color: var(--color-dark-secondary);
      }

      radio {
          /* make purple */
          -gtk-icon-filter: hue-rotate(45deg) contrast(0.6);
          margin-right: var(--margin-sm);
      }

      #end > * + * {
          margin-left: var(--margin-sm);
      }

      .popup {
          padding: var(--margin-lg);
      }

      /* --- clock --- */

      .clock {
          font-weight: bold;
      }

      .popup-clock .calendar-clock {
          font-size: var(--size-xl);
          margin-bottom: var(--margin-xs);
      }

      .popup-clock .calendar .today {
          background-color: #776DE899;
          border-radius: 0.25em;
      }

      .popup-clipboard .item {
          padding: var(--margin-xs);
      }

      .popup-clipboard .item + .item {
          border-top: 1px solid var(--color-border-light);
      }

      /* --- launcher --- */

      .launcher .item + .item {
          margin-left: 4px;
      }

      .launcher .item.open {
          box-shadow: inset 0 -1px var(--color-white);
      }

      .launcher .item.focused {
          box-shadow: inset 0 -1px var(--color-active);
      }

      .launcher .item.urgent {
          box-shadow: inset 0 -1px var(--color-urgent);
      }

      .popup-launcher {
          padding: var(--margin-sm);
      }

      .popup-launcher .popup-item {
          padding: var(--margin-lg);
          border-radius: 10px;
      }

      .popup-launcher .popup-item label {
          margin-top: var(--margin-sm);
      }

      /* --- menu --- */

      .menu label {
          padding: 0 var(--margin-sm);
      }

      .popup-menu .sub-menu {
          border-left: 1px solid var(--color-border-light);
          padding-left: var(--margin-sm);
      }

      .popup-menu .category, .popup-menu .application {
          padding: var(--margin-xs);
      }

      .popup-menu .category.open {
          background-color: var(--color-dark-secondary);
      }

      /* --- music --- */

      .popup-music .album-art {
          margin-right: var(--margin-lg);
          border-radius: 5px;
      }

      .popup-music .icon-box {
          margin-right: var(--margin-sm);
      }

      .popup-music .title .icon, .popup-music .title .label {
          font-size: var(--size-lg);
      }

      .popup-music .artist .label, .popup-music .album .label {
          margin-left: 6px;
      }

      .popup-music .volume .icon {
          /* fix icon offset */
          margin-right: 3px;
      }

      /* --- notifications --- */

      .notifications .count {
          font-size: 0.8em;
          padding: 0.18em;
      }

      /* --- sysinfo --- */

      .sysinfo > .item + .item {
          margin-left: var(--margin-sm);
      }

      /* --- tray --- */

      .tray popover contents {
          padding: var(--margin-lg);
      }

      /* --- volume --- */

      .popup-volume .device-box {
          border-right: 1px solid var(--color-border-light);
      }

      /* --- workspaces --- */

      .workspaces .item.visible {
          box-shadow: inset 0 -1px var(--color-white);
      }

      .workspaces .item.focused {
          box-shadow: inset 0 -1px var(--color-active);
          background-color: var(--color-dark-secondary);
      }

      .workspaces .item.urgent {
          background-color: var(--color-urgent);
      }

      /* --- custom: power menu ---  */

      .popup-power-menu #header {
          font-size: var(--size-lg);
          margin-bottom: 0.6em;
      }

      .popup-power-menu .power-btn {
          border: 1px solid var(--color-border-dark);
          border-radius: 10px;
          padding: 0 1.2em;
      }

      .popup-power-menu .power-btn label {
          font-size: var(--size-xxl);
      }

      /* need to use funky selector
      due to widgets being wrapped in GtkRevealers */
      .popup-power-menu #buttons > * + * {
          margin-left: 1.3em;
      }
    '';
    xdg.configFile."ironbar/style-backup.css".text = ''
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

    xdg.configFile."ironbar/scripts/disk-free.sh" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        set -euo pipefail

        used=$(timeout 3 ${pkgs.coreutils}/bin/df -P --output=pcent / | ${pkgs.gawk}/bin/awk 'NR==2 {gsub("%", "", $1); print $1}')
        printf "%d%% free\n" $((100 - used))
      '';
    };

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
          "PATH=${lib.makeBinPath (with pkgs; [
            bash
            coreutils
            git
            gnugrep
            gnused
            findutils
            curl
          ])}:/run/current-system/sw/bin:/run/wrappers/bin:${config.home.profileDirectory}/bin"
        ];
      };

      Install = {
        WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
