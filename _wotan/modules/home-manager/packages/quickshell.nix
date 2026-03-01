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

    # Systemd service for Quickshell
    systemd.user.services.quickshell = {
      Unit = {
        Description = "Quickshell custom widgets";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };

      Service = {
        Environment = [
          "PATH=/run/wrappers/bin:${lib.makeBinPath dependencies}"
          "QML2_IMPORT_PATH=${qmlImportPath}"
        ];
        ExecStart = lib.getExe quickshell;
        Restart = "on-failure";
        RestartSec = 3;
      };

      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
