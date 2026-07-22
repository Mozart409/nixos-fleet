{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf config.desktop.enable {
    # User experience configuration
    programs = {
      # Auto-start applications
      kdeconnect.enable = true;
    };

    # System services for user experience
    services = {
      # Power management
      tlp.enable = lib.mkDefault false;
      thermald.enable = lib.mkDefault true;

      # User directories
      xserver.desktopManager.xterm.enable = false;
    };

    # User directories
    xdg = {
      autostart.enable = true;
      menus.enable = true;
      icons.enable = true;
      mime.enable = true;
      sounds.enable = true;
    };

    # Icon themes
    environment.systemPackages = with pkgs; [
      # Icon themes
      papirus-icon-theme
      adwaita-icon-theme

      # Cursor themes
      bibata-cursors

      # GTK themes
      adwaita-qt
    ];

    # Polkit authentication agent
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          subject.isInGroup("users") &&
          (
            action.id == "org.freedesktop.login1.reboot" ||
            action.id == "org.freedesktop.login1.power-off" ||
            action.id == "org.freedesktop.login1.hibernate" ||
            action.id == "org.freedesktop.login1.suspend"
          )
        )
        {
          return polkit.Result.YES;
        }
      });
    '';

    # Environment variables for better UX
    environment.sessionVariables = {
      # Better performance
      MOZ_ENABLE_WAYLAND = "1";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";

      # Electron apps
      ELECTRON_OZONE_PLATFORM_HINT = "auto";

      # Java applications
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Default applications
      BROWSER = "brave";
      EDITOR = "nvim";
      TERMINAL = lib.mkIf (config.desktop.environment == "niri") "kitty";
    };

    # Auto-start applications configuration
    environment.etc."xdg/autostart".source = pkgs.runCommand "autostart" {} ''
      mkdir -p $out

      # Network manager applet
      cat > $out/nm-applet.desktop << EOF
      [Desktop Entry]
      Type=Application
      Name=Network Manager
      Exec=nm-applet
      Icon=nm-device-wired
      Terminal=false
      Categories=System;Network;
      EOF

      # Bluetooth applet (for Niri)
      ${lib.optionalString (config.desktop.environment == "niri") ''
        cat > $out/blueman.desktop << EOF
        [Desktop Entry]
        Type=Application
        Name=Bluetooth Manager
        Exec=blueman-applet
        Icon=blueman
        Terminal=false
        Categories=System;
        EOF
      ''}
    '';

    # User services
    systemd.user = {
      services = {
        # Network manager applet
        nm-applet = {
          unitConfig = {
            Description = "Network Manager Applet";
            PartOf = ["graphical-session.target"];
          };
          serviceConfig = {
            ExecStart = "${pkgs.networkmanagerapplet}/bin/nm-applet";
            Restart = "on-failure";
          };
          wantedBy = ["graphical-session.target"];
        };

        # Bluetooth applet (Niri only)
        blueman-applet = lib.mkIf (config.desktop.environment == "niri") {
          unitConfig = {
            Description = "Bluetooth Manager";
            PartOf = ["graphical-session.target"];
          };
          serviceConfig = {
            ExecStart = "${pkgs.blueman}/bin/blueman-applet";
            Restart = "on-failure";
          };
          wantedBy = ["graphical-session.target"];
        };
      };
    };
  };
}
