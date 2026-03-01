{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  cfg = config.desktop.quickshell;
  quickshell = inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Runtime dependencies for shell scripts and widgets
  dependencies = with pkgs; [
    bash
    coreutils
    gawk
    gnugrep
    procps
    curl # for weather widget
  ];

  # QML import paths for Qt6
  qmlImportPath = lib.concatStringsSep ":" [
    "${quickshell}/lib/qt-6/qml"
    "${pkgs.kdePackages.qtdeclarative}/lib/qt-6/qml"
  ];
in {
  options.desktop.quickshell = {
    enable = lib.mkEnableOption "quickshell custom widgets";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [quickshell];

    # Set QML import path for proper module resolution
    home.sessionVariables.QML2_IMPORT_PATH = qmlImportPath;

    # Link QML config files from the module directory
    xdg.configFile."quickshell".source = ./quickshell;

    # Hyprland session target (for systemd integration)
    systemd.user.targets.hyprland-session = {
      Unit = {
        Description = "Hyprland compositor session";
        Documentation = "man:systemd.special(7)";
        BindsTo = ["graphical-session.target"];
        Wants = ["graphical-session-pre.target"];
        After = ["graphical-session-pre.target"];
      };
    };

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
