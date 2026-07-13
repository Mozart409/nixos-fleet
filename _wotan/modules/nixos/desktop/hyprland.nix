{
  config,
  pkgs,
  lib,
  inputs,
  username,
  ...
}: {
  imports = [
    inputs.hyprland.nixosModules.default
    ./next-wallpaper.nix
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
    desktop.nextWallpaper.enable = true;

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

      # Hyprland plugins
      # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
      # hyprtrails disabled: incompatible with hyprland 0.54.0 (missing IPassElement::type() impl)
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
          user = username;
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
        # hyprbars disabled: testing if plugin causes session crash on reboot
        # inputs.hyprland-plugins.packages.${pkgs.stdenv.hostPlatform.system}.hyprbars
        # hyprtrails disabled: incompatible with hyprland 0.54.0
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
            "$mod, N, exec, neovim"

            # File manager
            "$mod, E, exec, thunar"

            # Wallpaper
            "$mod, W, exec, next-wallpaper"
            "$mod SHIFT, W, exec, previous-wallpaper"

            # Screenshot (saves to ~/Pictures/hyprshot and copies to clipboard)
            ", Print, exec, hyprshot -m region --freeze -o ~/Pictures/hyprshot"
            "$mod, Print, exec, hyprshot -m window -o ~/Pictures/hyprshot"
            "$mod SHIFT, Print, exec, hyprshot -m output --freeze -o ~/Pictures/hyprshot"

            # Lockscreen
            "$mod, L, exec, hyprlock"

            # Exit menu
            "$mod, Q, exec, wlogout"

            # Window controls
            "$mod, C, killactive"
            "$mod, M, fullscreen"
            "$mod, V, togglefloating"
            "$mod, R, layoutmsg, togglesplit"

            # Focus
            "$mod, left, movefocus, l"
            "$mod, right, movefocus, r"
            "$mod, up, movefocus, u"
            "$mod, down, movefocus, d"

            # Move/swap window within workspace; crosses to adjacent monitor only
            # when there is no window in that direction
            "$mod SHIFT, left, movewindow, l"
            "$mod SHIFT, right, movewindow, r"
            "$mod SHIFT, up, movewindow, u"
            "$mod SHIFT, down, movewindow, d"

            # Push window to an adjacent monitor unconditionally (works for
            # tiled and fullscreen windows, e.g. moving a fullscreen video)
            "$mod CTRL, left, movewindow, mon:l"
            "$mod CTRL, right, movewindow, mon:r"
            "$mod CTRL, up, movewindow, mon:u"
            "$mod CTRL, down, movewindow, mon:d"

            # Media keys (pass through to applications like Firefox)
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioStop, exec, playerctl stop"
            ", XF86AudioPrev, exec, playerctl previous"
            ", XF86AudioNext, exec, playerctl next"

            # Hyprsunset temperature adjustment (+/- 500K)
            "$mod, H, exec, hyprctl hyprsunset temperature +500"
            "$mod, B, exec, hyprctl hyprsunset temperature -500"
            "$mod SHIFT, H, exec, pkill hyprsunset; hyprsunset -i"

            # Window grouping (tabbed layout)
            "$mod, G, togglegroup"
            "$mod, TAB, changegroupactive, f"
            "$mod SHIFT, TAB, changegroupactive, b"
            "$mod SHIFT, G, moveoutofgroup"

            # Audio output switching (rofi menu / pwvucontrol GUI)
            "$mod, A, exec, audio-switch"
            "$mod SHIFT, A, exec, pwvucontrol"
          ]
          ++ (
            # Workspace bindings (number row: code:10-18)
            builtins.concatLists (builtins.genList (
                i: let
                  ws = i + 1;
                in [
                  "$mod, code:1${toString i}, workspace, ${toString ws}"
                  "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                ]
              )
              9)
          )
          ++ (
            # Numpad workspace bindings (KP_1-KP_9)
            # Numpad layout: 7(79) 8(80) 9(81) / 4(83) 5(84) 6(85) / 1(87) 2(88) 3(89)
            let
              numpadCodes = [87 88 89 83 84 85 79 80 81]; # KP_1 through KP_9
            in
              builtins.concatLists (builtins.genList (
                  i: let
                    ws = i + 1;
                    code = builtins.elemAt numpadCodes i;
                  in [
                    "$mod, code:${toString code}, workspace, ${toString ws}"
                    "$mod SHIFT, code:${toString code}, movetoworkspace, ${toString ws}"
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
          "sleep 1 && next-wallpaper --transition-type random --transition-fps 60"
          "hyprsunset -t 5000"
          "hypridle"
        ];

        # Plugin configurations
        # hyprtrails config commented out - plugin disabled
        # "plugin:hyprtrails" = {
        #   "bezier_points" = "0.1,0.1,0.9,0.9";
        #   "bezier_step" = 0.01;
        #   "bezier_curve" = "catmull-rom";
        #   "trail_color" = "rgba(33ccffee)";
        #   "trail_size" = 3;
        #   "trail_steps" = 5;
        # };

        # Window rules
        windowrule = [
          # Force Brave windows to open tiled (it sometimes requests floating)
          "tile on, match:class (?i)brave.*"

          # ueberzugpp (yazi image preview) must stay floating
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
      HYPRSHOT_DIR = "${config.users.users.${username}.home}/Pictures/hyprshot";
    };
  };
}
