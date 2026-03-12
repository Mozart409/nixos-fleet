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

  options.desktop.hyprland = {
    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["DP-1,1920x1080@60,0x0,1"];
      description = "Hyprland monitor configuration";
    };
  };

  config = lib.mkIf (config.desktop.enable && config.desktop.environment == "hyprland") {
    security.sudo.extraConfig = ''
      Defaults!${pkgs.gparted}/bin/gparted env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
      Defaults!${pkgs.polkit.bin}/bin/pkexec env_keep+="DISPLAY WAYLAND_DISPLAY XDG_RUNTIME_DIR"
    '';

    # Essential Wayland packages
    environment.systemPackages = with pkgs; [
      # Core utilities
      hyprshot
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
      inputs.hyprsunset.packages.${pkgs.stdenv.hostPlatform.system}.hyprsunset
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww

      # Notifications
      dunst

      # File manager
      nemo
      nemo-fileroller # Archive support

      # Hyprland plugins (disabled due to build errors - waiting for upstream to update)
      # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars  # Disabled: incompatible with hyprland 0.54.0
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
          command = "${pkgs.tuigreet}/bin/tuigreet --greeting 'Welcome to NixOS!' --asterisks --remember --time --theme 'border=darkgray;text=yellow;prompt=lightyellow;time=yellow;action=yellow;button=darkgray;container=black' --cmd ${inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland}/bin/start-hyprland";
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
        # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprtrails
        # inputs.hypr-dynamic-cursors.packages.${pkgs.system}.hypr-dynamic-cursors
      ];
      settings = {
        # Monitor configuration (host-specific)
        monitor = config.desktop.hyprland.monitors;

        # Input device settings
        input = {
          kb_layout = "de";
          follow_mouse = 1;
          numlock_by_default = true;
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
          # Disable blur to reduce GPU load and scroll lag on NVIDIA
          blur = {
            enabled = false;
          };
        };

        # Cursor settings for NVIDIA - use software cursors (more reliable)
        cursor = {
          no_hardware_cursors = 1;
        };

        # Workspace configuration
        # Note: Workspace-to-monitor binding is now host-specific
        # See hosts/wotan/desktop-config.nix for example

        # Mod key
        "$mod" = "SUPER";

        # Keybinds
        bind =
          [
            # Application launcher
            "$mod, D, exec, wofi --show drun"
            "$mod, SPACE, exec, rofi -show drun -run-command 'bash -c \"{cmd}\"'"

            # Terminal
            "$mod, Return, exec, kitty"
            "$mod, T, exec, kitty"

            # Browser
            "$mod, F, exec, brave"

            # Text editor
            "$mod, N, exec, pluma"

            # File manager
            "$mod, E, exec, nemo"

            # Wallpaper
            "$mod, W, exec, awww img \"\$(find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.gif' \\) | shuf -n1)\" --transition-type random"

            # Screenshot (saves to ~/Pictures/hyprshot and copies to clipboard)
            ", Print, exec, hyprshot -m region -o ~/Pictures/hyprshot"
            "$mod, Print, exec, hyprshot -m window -o ~/Pictures/hyprshot"
            "$mod SHIFT, Print, exec, hyprshot -m output -o ~/Pictures/hyprshot"

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

            # Move windows to adjacent monitor (left/right) or swap within workspace (up/down)
            "$mod SHIFT, left, movewindow, mon:-1"
            "$mod SHIFT, right, movewindow, mon:+1"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"

            # Media keys (pass through to applications like Firefox)
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioStop, exec, playerctl stop"
            ", XF86AudioPrev, exec, playerctl previous"
            ", XF86AudioNext, exec, playerctl next"

            # Hyprsunset temperature adjustment (+/- 500K)
            "$mod, H, exec, hyprctl hyprsunset temperature +500"
            "$mod, B, exec, hyprctl hyprsunset temperature -500"
            "$mod SHIFT, H, exec, pkill hyprsunset; hyprsunset -i"
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
          "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland"
          "systemctl --user start hyprland-session.target"
          "awww-daemon"
          "sleep 1 && awww img \"$(find ~/Pictures/Wallpapers -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' \\) | shuf -n1)\" --transition-type grow --transition-fps 60"
          "hyprsunset -t 5000"
          "hypridle"
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

        # Window rules for ueberzugpp (yazi image preview)
        windowrule = [
          "no_focus on, match:class ueberzugpp"
          "no_shadow on, match:class ueberzugpp"
          "no_blur on, match:class ueberzugpp"
          "border_size 0, match:class ueberzugpp"
          "float on, match:class ueberzugpp"
          "no_anim on, match:class ueberzugpp"
          "pin on, match:class ueberzugpp"
          "no_initial_focus on, match:class ueberzugpp"
        ];

        # Mouse bindings
        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };

    # Lockscreen configuration
    security.pam.services.hyprlock = {};

    # Theming integration
    environment.sessionVariables = {
      # Qt theme - use Kvantum directly
      QT_QPA_PLATFORMTHEME = lib.mkForce "kvantum";
      QT_STYLE_OVERRIDE = "kvantum";

      # Wayland compatibility
      MOZ_ENABLE_WAYLAND = "1";
      _JAVA_AWT_WM_NONREPARENTING = "1";

      # Hyprshot screenshot directory
      HYPRSHOT_DIR = "${config.users.users.amadeus.home}/Pictures/hyprshot";
    };
  };
}
