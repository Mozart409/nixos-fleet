{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    desktop.enable = lib.mkEnableOption "desktop environment";
    desktop.environment = lib.mkOption {
      type = lib.types.enum ["kde" "hyprland"];
      description = "Desktop environment to use";
    };
  };

  config = lib.mkIf config.desktop.enable {
    # Common desktop packages and settings
    environment.systemPackages = with pkgs; [
      # Core utilities
      firefox
      git
      curl
      wget
      unzip
      p7zip
      tree

      # System monitoring
      htop
      neofetch

      # Text editors
      vim
      nano

      # Network tools
      networkmanager

      # Hardware integration tools
      usbutils
      pciutils
      lshw
      hwinfo

      # Printer/scanner tools
      simple-scan
      xsane

      # Camera tools
      cheese
      v4l-utils

      # Tablet tools
      opentabletdriver

      # Bluetooth tools
      bluez
      bluez-tools
      bluetuith

      # Passwords
      keepassxc
    ];

    # Font configuration
    fonts = {
      packages = with pkgs; [
        # Core fonts
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf

        # Programming fonts
        jetbrains-mono
        fira-code
        source-code-pro

        # Additional fonts
        dejavu_fonts
        ubuntu-classic
      ];

      fontconfig = {
        defaultFonts = {
          serif = ["Noto Serif"];
          sansSerif = ["Noto Sans"];
          monospace = ["JetBrains Mono"];
          emoji = ["Noto Color Emoji"];
        };
      };
    };

    # Graphics and OpenGL configuration is handled in hardware section

    # Sound configuration (common to both DEs)
    services.pulseaudio.enable = false;
    services.pulseaudio.support32Bit = true;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    # X11 keyboard configuration (common to both DEs)
    services.xserver.xkb = {
      layout = "de";
      variant = "";
    };

    # Common theming
    environment.sessionVariables = {
      # GTK theme
      GTK_THEME = "Adwaita:dark";

      # Qt theme
      QT_QPA_PLATFORMTHEME = "gtk3";

      # Cursor theme
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
    };

    # Enable common services
    services = {
      # Network management is handled elsewhere

      # Power management
      upower.enable = true;

      # Location services
      geoclue2.enable = true;

      # Time synchronization
      timesyncd.enable = true;

      # Hardware integration
      printing.enable = true;
      printing.drivers = [pkgs.hplipWithPlugin];

      # Scanner support is handled by packages

      # Camera support is handled by pipewire and v4l-utils

      # Auto-mount USB drives
      gvfs.enable = true;
      udisks2.enable = true;

      # Tablet support
      libinput.enable = true;
    };

    # Systemd service to unblock Bluetooth automatically
    systemd.services.unblock-bluetooth = {
      description = "Unblock Bluetooth device";
      after = ["bluetooth.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
        RemainAfterExit = true;
      };
    };

    # Hardware support packages
    hardware = {
      bluetooth = {
        enable = true;
        powerOnBoot = true;
        settings = {
          General = {
            Enable = "Source,Sink,Media,Socket";
            Experimental = true;
            # Improve compatibility with Bluetooth audio devices
            FastConnectable = true;
            # Disable auto-suspend to prevent connection issues
            ReconnectAttempts = 7;
            ReconnectIntervals = "1,2,4,8,16,32,64";
          };
          Policy = {
            AutoEnable = true;
          };
        };
      };
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      opentabletdriver = {
        enable = true;
      };
      printers = {
        ensurePrinters = [];
        ensureDefaultPrinter = null;
      };
    };

    # Enable common programs
    programs = {
      # Dconf for GTK settings
      dconf.enable = true;
    };

    # Common desktop settings
    security = {
      # Polkit
      polkit.enable = true;

      # AppArmor
      apparmor.enable = lib.mkDefault true;
    };

    # Enable portals for desktop integration
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}
