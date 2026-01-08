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
    security.sudo.extraConfig = ''
      Defaults!${pkgs.gparted}/bin/gparted env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
      Defaults!${pkgs.polkit.bin}/bin/pkexec env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
    '';

    # Essential Wayland packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      grimblast
      slurp
      grim
      wl-clipboard
      cliphist
      playerctl

      # Bar and launcher
      rofi
      inputs.ironbar.packages.${pkgs.stdenv.hostPlatform.system}.ironbar
      wofi
      wlogout

      # Lockscreen and background
      hyprlock
      hypridle
      hyprlauncher
      hyprtoolkit
      hyprsysteminfo
      # Blue light filter
      hyprsunset
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

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

    # Greetd configuration
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland}/bin/start-hyprland";
          user = "amadeus";
        };
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time --theme 'border=darkgray;text=yellow;prompt=lightyellow;time=yellow;action=yellow;button=darkgray;container=black' --cmd ${inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland}/bin/start-hyprland";
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
        inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
        inputs.hypr-dynamic-cursors.packages.${pkgs.system}.hypr-dynamic-cursors
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
          "1, monitor:DP-3"
          "2, monitor:DP-3"
          "3, monitor:DP-3"
          "4, monitor:DP-3"
          "5, monitor:DP-3"
        ];

        # Window rules
        windowrulev2 = [
          "float, class:^(pavucontrol)$"
          "float, class:^(blueman-manager)$"
          "float, class:^(nm-connection-editor)$"
          "size 800 600, class:^(pavucontrol)$"
          "size 800 600, class:^(blueman-manager)$"
          "float, class:^(steam)$"
          "center, class:^(steam)$"
          "size 1280 720, class:^(steam)$"
        ];

        # Mod key
        "$mod" = "SUPER";

        # Keybinds
        bind =
          [
            # Application launcher
            "$mod, D, exec, wofi --show drun"
            "$mod, SPACE, exec, rofi -show drun"

            # Terminal
            "$mod, Return, exec, alacritty"
            "$mod, T, exec, alacritty"

            # Browser
            "$mod, F, exec, firefox"

            # Text editor
            "$mod, N, exec, pluma"

            # File manager
            "$mod, E, exec, thunar"

            # Wallpaper
            "$mod, W, exec, awww img \"\$(find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.gif' \\) | shuf -n1)\" --transition-type fade"

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

            # Media keys (pass through to applications like Firefox)
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioStop, exec, playerctl stop"
            ", XF86AudioPrev, exec, playerctl previous"
            ", XF86AudioNext, exec, playerctl next"

            # Blue light filter
            "$mod, H, exec, hyprctl hyprsunset temperature +500"
            "$mod, B, exec, hyprctl hyprsunset temperature -500"
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

        # Startup applications
        exec-once = [
          "awww-daemon"
          "sleep 1 && awww img \"$(find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' \\) | shuf -n1)\" --transition-type grow --transition-fps 60"
          "hyprsunset"
          "hypridle"
          "ironbar"
        ];

        # Plugin configurations
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

    # Hyprsunset configuration
    systemd.user.services.hyprsunset = {
      description = "Hyprland blue light filter";
      partOf = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        ExecStart = "${pkgs.hyprsunset}/bin/hyprsunset";
        Restart = "on-failure";
      };
    };

    # Lockscreen configuration
    security.pam.services.hyprlock = {};

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
