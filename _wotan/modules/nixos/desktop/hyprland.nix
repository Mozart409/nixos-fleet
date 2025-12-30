{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.hyprland.nixosModules.default
  ];

  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "hyprland") {
    # Essential Wayland packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      grimblast
      slurp
      grim
      wl-clipboard
      cliphist

      # Bar and launcher
      waybar
      wofi
      wlogout

      # Lockscreen and background
      hyprlock
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprpaper
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprlauncher
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprtoolkit
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprsysteminfo
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprshutdown

      # Notifications
      mako

      # File manager
      xfce.thunar

      # Hyprland plugins
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
      inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails

      # Theming
      qt6.qtwayland
      libsForQt5.qtwayland
    ];

    # Display manager
    services.displayManager = {
      defaultSession = "hyprland";
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

    # Portal configuration
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      ];
      configPackages = with pkgs; [
        inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland
      ];
    };

    # Hyprland configuration
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      plugins = [
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprspace
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
      ];
      settings = {
        # Monitor configuration
        monitor = [
          "DP-3,2560x1440@144,0x0,1" # Center display
          "DP-2,2560x1440@144,2560x0,1" # Right display
        ];

        # Input device settings
        input = {
          kb_layout = "de";
          follow_mouse = 1;
          touchpad = {
            natural_scroll = false;
          };
          sensitivity = 0;
        };

        # General settings
        general = {
          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;
          "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
          "col.inactive_border" = "rgba(595959aa)";
          layout = "dwindle";
          resize_on_border = false;
        };

        # Decoration and theming
        decoration = {
          rounding = 10;
          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
          dim_inactive = false;
        };

        # Workspace configuration
        workspace = [
          "1, monitor:DP-1"
          "2, monitor:DP-1"
          "3, monitor:DP-1"
          "4, monitor:DP-1"
          "5, monitor:DP-1"
        ];

        # Window rules
        windowrulev2 = [
          "float, class:^(pavucontrol)$"
          "float, class:^(blueman-manager)$"
          "float, class:^(nm-connection-editor)$"
          "size 800 600, class:^(pavucontrol)$"
          "size 800 600, class:^(blueman-manager)$"
        ];

        # Mod key
        "$mod" = "SUPER";

        # Keybinds
        bind =
          [
            # Application launcher
            "$mod, D, exec, wofi --show drun"
            "$mod, SPACE, exec, hyprlauncher"

            # Terminal
            "$mod, Return, exec, alacritty"
            "$mod, T, exec, alacritty"

            # Browser
            "$mod, F, exec, firefox"

            # File manager
            "$mod, E, exec, thunar"

            # Screenshot
            ", Print, exec, grimblast copy area"
            "$mod, Print, exec, grimblast copy window"
            "$mod SHIFT, Print, exec, grimblast copy screen"

            # Lockscreen
            "$mod, L, exec, hyprlock"

            # Exit menu
            "$mod, Q, exec, wlogout"

            # Window controls
            "$mod, C, killactive"
            "$mod, M, fullscreen"
            "$mod, V, togglefloating"
            "$mod, R, togglesplit"

            # Focus
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"

            # Swap windows
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"
          ]
          ++ (
            # Workspace bindings
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  "$mod, code:1${toString i}, workspace, ${toString ws}"
                  "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                ]
              )
              9)
          );

        # Plugin configurations
        "plugin:hyprspace" = {
          workspace_gaps = 15;
          workspace_border = 2;
          "workspace_border_accent" = "rgba(33ccffee)";
        };

        "plugin:hyprtrails" = {
          "bezier_points" = "0.1,0.1,0.9,0.9";
          "bezier_step" = 0.01;
          "bezier_curve" = "catmull-rom";
          "trail_color" = "rgba(33ccffee)";
          "trail_size" = 3;
          "trail_steps" = 5;
        };

        # Mouse bindings
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };

    # Lockscreen configuration
    security.pam.services.hyprlock = {};

    # Hyprlock configuration
    environment.etc."hypr/hyprlock.conf".text = ''
      $font = Monospace

      general {
          hide_cursor = false
      }

      animations {
          enabled = true
          bezier = linear, 1, 1, 0, 0
          animation = fadeIn, 1, 5, linear
          animation = fadeOut, 1, 5, linear
          animation = inputFieldDots, 1, 2, linear
      }

      background {
          monitor =
          path = screenshot
          blur_passes = 3
      }

      input-field {
          monitor =
          size = 20%, 5%
          outline_thickness = 3
          inner_color = rgba(0, 0, 0, 0.0)

          outer_color = rgba(33ccffee) rgba(00ff99ee) 45deg
          check_color = rgba(00ff99ee) rgba(ff6633ee) 120deg
          fail_color = rgba(ff6633ee) rgba(ff0066ee) 40deg

          font_color = rgb(143, 143, 143)
          fade_on_empty = false
          rounding = 15

          font_family = $font
          placeholder_text = Input password...
          fail_text = $PAMFAIL

          dots_spacing = 0.3

          position = 0, -20
          halign = center
          valign = center
      }

      label {
          monitor =
          text = $TIME
          font_size = 90
          font_family = $font

          position = -30, 0
          halign = right
          valign = top
      }

      label {
          monitor =
          text = cmd[update:60000] date +"%A, %d %B %Y"
          font_size = 25
          font_family = $font

          position = -30, -150
          halign = right
          valign = top
      }

      label {
          monitor =
          text = $LAYOUT[de,en]
          font_size = 24
          onclick = hyprctl switchxkblayout all next

          position = 250, -20
          halign = center
          valign = center
      }
    '';

    # Theming integration
    environment.sessionVariables = {
      # Qt theme - use Kvantum directly
      QT_QPA_PLATFORMTHEME = lib.mkForce "kvantum";
      QT_STYLE_OVERRIDE = "kvantum";

      # GTK theme
      GTK_THEME = "Adwaita:dark";

      # Cursor theme
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";

      # Wayland compatibility
      MOZ_ENABLE_WAYLAND = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };
  };
}
