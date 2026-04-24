{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.desktop.quickshell;
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Audio switch script using rofi
  audio-switch = pkgs.writeShellScriptBin "audio-switch" ''
    set -euo pipefail

    # List all audio sinks
    sinks=$(${pkgs.wireplumber}/bin/wpctl status | sed -n '/Audio/,/Video/{/Sinks:/,/Sources:/p}' | grep -E '^\s*[│├└].*[0-9]+\.' | sed 's/[│├└]//g; s/^\s*//')

    if [ -z "$sinks" ]; then
      ${pkgs.libnotify}/bin/notify-send "Audio" "No audio sinks found"
      exit 1
    fi

    # Show rofi menu
    selected=$(echo "$sinks" | ${pkgs.rofi}/bin/rofi -dmenu -i -p "󰓃 Audio Output" -theme-str 'window {width: 450px;}')

    if [ -n "$selected" ]; then
      sink_id=$(echo "$selected" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
      if [ -n "$sink_id" ]; then
        ${pkgs.wireplumber}/bin/wpctl set-default "$sink_id"
        sink_name=$(echo "$selected" | sed 's/^[* ]*[0-9]*\. //' | cut -d'[' -f1 | xargs)
        ${pkgs.libnotify}/bin/notify-send "󰓃 Audio" "Switched to: $sink_name"
      fi
    fi
  '';

  # Runtime dependencies for shell scripts and widgets
  dependencies = with pkgs; [
    bash
    coreutils
    gawk
    gnugrep
    procps
    curl # for weather widget
    wireplumber # for wpctl audio control
    libnotify # for notify-send
    rofi # for audio device selection menu
  ];

  # QML import paths for Qt6
  qmlImportPath = lib.concatStringsSep ":" [
    "${quickshell}/lib/qt-6/qml"
    "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml"
  ];
in {
  imports = [
    ../services/hyprland-session.nix
  ];

  options.desktop.quickshell = {
    enable = lib.mkEnableOption "quickshell custom widgets";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      quickshell
      audio-switch # Rofi-based audio output switcher
      pkgs.pwvucontrol # Modern PipeWire volume control GUI
      pkgs.pulsemixer # TUI audio mixer
    ];

    # Set QML import path for proper module resolution
    home.sessionVariables.QML2_IMPORT_PATH = qmlImportPath;

    # Link QML config files from the module directory
    xdg.configFile."quickshell".source = ./quickshell;

    # Systemd service for Quickshell
    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell custom widgets";
        PartOf = ["hyprland-session.target"];
        After = ["hyprland-session.target"];
      };

      Service = {
        Environment = [
          "PATH=/run/wrappers/bin:${lib.makeBinPath dependencies}:/run/current-system/sw/bin:${config.home.profileDirectory}/bin"
          "QML2_IMPORT_PATH=${qmlImportPath}"
        ];
        ExecStart = lib.getExe quickshell;
        Restart = "on-failure";
        RestartSec = 3;
      };

      Install = {
        WantedBy = ["hyprland-session.target"];
      };
    };
  };
}
