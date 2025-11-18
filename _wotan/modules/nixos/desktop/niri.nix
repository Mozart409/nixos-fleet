{
  config,
  pkgs,
  lib,
  ...
}: {
  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "niri") {
    # Niri specific configuration
    programs.niri.enable = true;
    
    # Default niri configuration for users
    environment.etc."niri-config.kdl".text = ''
      # Configure superkey as Mod (Windows key)
      input {
        keyboard {
          repeat-delay 600
          repeat-rate 25
          track-layout window
        }
        touchpad {
          tap-button-map left-right-middle
          dwt true
          disable-while-typing true
          click-method clickfinger
          scroll-method two-finger
          natural-scroll false
          accel-speed 0.5
          accel-profile adaptive
        }
        mouse {
          accel-speed 0.5
          accel-profile flat
        }
        warp-mouse-to-focus true
        focus-follows-mouse false
      }

      outputs {
        "eDP-1" {
          mode {
            width 1920
            height 1080
            refresh 60.0
          }
          position { x 0 y 0 }
          scale 1.0
        }
      }

      layout {
        focus-ring {
          enable true
          width 4
          active-color "#7fc8ff"
          inactive-color "#505050"
        }
        border {
          enable true
          width 2
          active-color "#7fc8ff"
          inactive-color "#505050"
        }
        preset-column-widths [
          { proportion 1.0 }
          { proportion 0.5 }
          { proportion 0.33 }
          { proportion 0.25 }
        ]
        default-column-width { proportion 0.5 }
        gaps 8
        center-focused-column never
      }

      # Keybindings with Super (Windows) as Mod
      binds {
        # Super + Enter to open terminal
        Super+Return { spawn "alacritty" }
        
        # Super + D to open app launcher
        Super+D { spawn "fuzzel" }
        
        # Super + Q to close window
        Super+Q { close-window }
        
        # Super + Shift + Q to quit niri
        Super+Shift+Q { quit }
        
        # Window navigation
        Super+Left { focus-column-left }
        Super+Right { focus-column-right }
        Super+Up { focus-window-up }
        Super+Down { focus-window-down }
        
        # Move windows
        Super+Shift+Left { move-column-left }
        Super+Shift+Right { move-column-right }
        Super+Shift+Up { move-window-up }
        Super+Shift+Down { move-window-down }
        
        # Workspace navigation
        Super+1 { focus-workspace 1 }
        Super+2 { focus-workspace 2 }
        Super+3 { focus-workspace 3 }
        Super+4 { focus-workspace 4 }
        Super+5 { focus-workspace 5 }
        Super+6 { focus-workspace 6 }
        Super+7 { focus-workspace 7 }
        Super+8 { focus-workspace 8 }
        Super+9 { focus-workspace 9 }
        Super+0 { focus-workspace 10 }
        
        # Move windows to workspaces
        Super+Shift+1 { move-column-to-workspace 1 }
        Super+Shift+2 { move-column-to-workspace 2 }
        Super+Shift+3 { move-column-to-workspace 3 }
        Super+Shift+4 { move-column-to-workspace 4 }
        Super+Shift+5 { move-column-to-workspace 5 }
        Super+Shift+6 { move-column-to-workspace 6 }
        Super+Shift+7 { move-column-to-workspace 7 }
        Super+Shift+8 { move-column-to-workspace 8 }
        Super+Shift+9 { move-column-to-workspace 9 }
        Super+Shift+0 { move-column-to-workspace 10 }
        
        # Window resizing
        Super+Control+Left { set-column-width "-10%" }
        Super+Control+Right { set-column-width "+10%" }
        Super+Control+Up { set-window-height "-10%" }
        Super+Control+Down { set-window-height "+10%" }
        
        # Fullscreen
        Super+F { toggle-fullscreen-column }
        
        # Floating
        Super+Space { toggle-window-floating }
        
        # Screenshot
        Print { spawn "grim" "-o" "$(slurp)" "-" }
        Super+Print { spawn "grim" "-" }
        
        # Volume control
        XF86AudioRaiseVolume { spawn "pamixer" "-i" "5" }
        XF86AudioLowerVolume { spawn "pamixer" "-d" "5" }
        XF86AudioMute { spawn "pamixer" "-t" }
        
        # Brightness control
        XF86MonBrightnessUp { spawn "brightnessctl" "set" "+5%" }
        XF86MonBrightnessDown { spawn "brightnessctl" "set" "5%-" }
      }

      spawn-at-startup [
        { command "waybar" }
        { command "swaybg" }
        { command "dunst" }
      ]
    '';

    # Niri-specific packages (not in common)
    environment.systemPackages = with pkgs; [
      # Terminal and launcher
      alacritty
      fuzzel

      # Status bar and utilities
      waybar
      swaybg
      swaylock
      swayidle

      # Screenshots and screen recording
      grim
      slurp
      wf-recorder
      wl-clipboard
      wl-mirror

      # File management plugins
      xfce.thunar-archive-plugin

      # Network management applet
      networkmanagerapplet

      # Audio control
      pavucontrol
      pamixer

      # Bluetooth
      blueman

      # Notification daemon
      dunst
      libnotify

      # Polkit agent
      polkit_gnome

      # Color picker
      grimblast

      # PDF viewer
      evince

      # Image viewer
      loupe

      # Text editor
      gnome-text-editor

      # System monitor
      btop
    ];

    # Enable required services
    services = {
      # Auto-mount USB drives
      gvfs.enable = true;
      udisks2.enable = true;

      # Power management
      power-profiles-daemon.enable = true;
      auto-cpufreq.enable = lib.mkDefault false;
    };

    # Enable X11 for compatibility
    services.xserver.enable = true;

    # Enable polkit
    security.polkit.enable = true;

    # Enable portal for GTK/Qt applications
    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}

