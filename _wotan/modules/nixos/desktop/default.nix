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
      default = null;
      description = "Desktop environment to use (required when desktop.enable is true)";
    };
  };

  config = lib.mkIf config.desktop.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.desktop.environment != null;
          message = "desktop.environment must be set when desktop.enable is true";
        }
      ];
    }
    {
      # Common desktop packages and settings
      environment.systemPackages = with pkgs; [
        # Core utilities
        git
        curl
        wget
        unzip
        p7zip
        tree

        # System monitoring
        htop
        fastfetch

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
          # keep-sorted start

          # Additional fonts
          dejavu_fonts
          # Programming fonts (jetbrains-mono provided by nerd-fonts in home-manager)
          fira-code
          liberation_ttf
          # Core fonts
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          source-code-pro
          ubuntu-classic
          # keep-sorted end
        ];

        fontconfig = {
          defaultFonts = {
            serif = ["Noto Serif"];
            sansSerif = ["Noto Sans"];
            monospace = ["JetBrains Mono" "Symbols Nerd Font"];
            emoji = ["Noto Color Emoji"];
          };
        };
      };

      # Graphics and OpenGL configuration is handled in hardware section

      # Sound configuration (common to both DEs)
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        wireplumber = {
          enable = true;
          extraConfig = {
            "10-disable-suspend" = {
              "monitor.alsa.rules" = [
                {
                  matches = [{"node.name" = "~alsa_output.*";}];
                  actions = {
                    update-props = {
                      "session.suspend-timeout-seconds" = 300;
                    };
                  };
                }
              ];
            };
            # Bluetooth: expose A2DP only, disable the HFP/HSP headset roles.
            # When an app opens a BT speaker's mic (e.g. it advertises one), the
            # device is forced into the HFP/headset profile, which downgrades
            # audio to low-quality mono over a SCO/eSCO voice link that time-
            # shares the radio with A2DP -> severely choppy music. Disabling the
            # headset backend keeps speakers (like the Grundig CLUB) in
            # high-quality A2DP stereo. (Trade-off: no BT headset mic for calls.)
            "11-bluetooth-a2dp-only" = {
              "monitor.bluez.properties" = {
                "bluez5.roles" = ["a2dp_sink" "a2dp_source"];
                "bluez5.hfphsp-backend" = "none";
              };
            };
          };
        };
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

      # Prevent Razer Barracuda X 2.4 dongle from USB autosuspend (fixes audio dropout)
      services.udev.extraRules = ''
        ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="0550", ATTR{power/autosuspend}="-1"
      '';

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
        printing.drivers = with pkgs; [
          hplipWithPlugin
          epson-escpr
          epson-escpr2
        ];

        # Camera support is handled by pipewire and v4l-utils

        # Auto-mount USB drives
        gvfs.enable = true;
        udisks2.enable = true;

        # Tablet support
        libinput.enable = true;
      };

      # Network printer/scanner discovery
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
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

      # Disable btusb USB autosuspend. The Intel AX210 controller (USB
      # 8087:0032) defaults to a 2s USB autosuspend that powers the radio down
      # mid-stream, producing kernel "hci0: link tx timeout" -> "killing stalled
      # connection" and breaking A2DP audio playback (WirePlumber then fails to
      # acquire the Bluetooth audio transport). Keeping the controller awake
      # fixes the recurring audio dropouts / stalled connections.
      boot.extraModprobeConfig = ''
        options btusb enable_autosuspend=0
      '';

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
        sane = {
          enable = true;
          extraBackends = [pkgs.epsonscan2];
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
    }
  ]); # Close lib.mkMerge and lib.mkIf
}
