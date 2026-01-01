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
      playerctl

      # Bar and launcher
      waybar
      eww
      wofi
      wlogout

      # Lockscreen and background
      hyprlock
      hyprpaper
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

        # Blue light filter (wlsunset)
        exec-once = [
          "hyprpaper"
          "waybar"
          "eww open bar"
          # Start hyprsunset at 8 PM with 3400K, stop at 6 AM
          "hyprsunset"
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

    environment.etc."waybar/weather.sh".text = ''
      #!/bin/bash

      # Configuration
      API_KEY="ed9e1f66545f2f25d7bb0655c4116045"
      CITY_ID="2867714"
      UNITS="metric"
      LANG="en"

      # Function to check if API key is valid
      check_api_key() {
          local test_request=$(curl -s "api.openweathermap.org/data/2.5/weather?q=London&appid=$API_KEY")
          if [[ $test_request == *"Invalid API key"* ]]; then
              echo "󰖙 Invalid API key"

              exit 1
          fi
      }

      # Function to get weather icon based on conditions and time
      get_icon() {
          local condition=$1
          local is_day=$2

          case $condition in
              "Clear")
                  if [ "$is_day" = "true" ]; then
                      echo "󰖙"  # Clear day
                  else
                      echo "󰖔"  # Clear night
                  fi
                  ;;
              "Clouds")
                  case $3 in
                      "few clouds") echo "󰖕" ;;  # Few clouds
                      "scattered clouds") echo "󰖕" ;;  # Scattered clouds
                      *) echo "󰖐" ;;  # Cloudy
                  esac
                  ;;
              "Rain")
                  if [[ $3 == *"light"* ]]; then
                      echo "󰖖"  # Light rain
                  else
                      echo "󰖗"  # Rain
                  fi
                  ;;
              "Drizzle")
                  echo "󰖖"  # Drizzle
                  ;;
              "Thunderstorm")
                  echo "󰖓"  # Thunderstorm
                  ;;
              "Snow")
                  echo "󰖘"  # Snow
                  ;;
              "Mist"|"Fog"|"Haze")
                  echo "󰖑"  # Mist
                  ;;
              *)
                  echo "󰖜"  # Default icon
                  ;;
          esac
      }

      # Check API key first
      check_api_key

      # Get weather data
      WEATHER_DATA=$(curl -s "api.openweathermap.org/data/2.5/weather?id=$CITY_ID&appid=$API_KEY&units=$UNITS&lang=$LANG")

      if [ -n "$WEATHER_DATA" ]; then
          # Extract data
          TEMP=$(echo $WEATHER_DATA | jq -r '.main.temp')
          DESCRIPTION=$(echo $WEATHER_DATA | jq -r '.weather[0].main')
          DETAILED_DESC=$(echo $WEATHER_DATA | jq -r '.weather[0].description')
          FEELS_LIKE=$(echo $WEATHER_DATA | jq -r '.main.feels_like')
          SUNRISE=$(echo $WEATHER_DATA | jq -r '.sys.sunrise')
          SUNSET=$(echo $WEATHER_DATA | jq -r '.sys.sunset')

          # Determine if it's day or night
          CURRENT_TIME=$(date +%s)
          IS_DAY="true"
          if [ $CURRENT_TIME -lt $SUNRISE ] || [ $CURRENT_TIME -gt $SUNSET ]; then
              IS_DAY="false"
          fi

          # Round temperatures
          TEMP=$(printf "%.0f" $TEMP)
          FEELS_LIKE=$(printf "%.0f" $FEELS_LIKE)

          # Get weather icon
          ICON=$(get_icon "$DESCRIPTION" "$IS_DAY" "$DETAILED_DESC")

          # Format output
          echo "$ICON $TEMP°C 󰤾 $FEELS_LIKE°C"
      else
          echo "󰖙 Weather unavailable"
      fi
    '';

    # Custom css for waybar
    environment.etc."waybar/style.css".text = ''
      /*
      * Kanagawa palette
      */

      /* Base colors */
      @define-color base   #1f1f28;
      @define-color mantle #16161d;
      @define-color crust  #0d0d14;

      /* Text colors */
      @define-color text     #dcd7ba;
      @define-color subtext0 #a89984;
      @define-color subtext1 #c8c093;

      /* Surface colors */
      @define-color surface0 #2a2a37;
      @define-color surface1 #363646;
      @define-color surface2 #43436f;

      /* Overlay colors */
      @define-color overlay0 #565575;
      @define-color overlay1 #727169;
      @define-color overlay2 #8b8b8b;

      /* Accent colors */
      @define-color blue      #7aa89f;
      @define-color lavender  #a4b9ef;
      @define-color sapphire  #7fb4ca;
      @define-color sky       #7dc4e4;
      @define-color teal      #6a9589;
      @define-color green     #76946a;
      @define-color yellow    #dca561;
      @define-color peach     #ffa066;
      @define-color maroon    #e46876;
      @define-color red       #e82424;
      @define-color mauve     #957fb8;
      @define-color pink      #d27e99;
      @define-color flamingo  #e82424;
      @define-color rosewater #dcd7ba;

      /* Additional styling variables - using solid colors instead of rgba */
      @define-color background-primary   #1f1f28;
      @define-color background-secondary #2a2a37;
      @define-color background-hover     #363646;
      @define-color border-color         #565575;

      /* Status colors */
      @define-color success @green;
      @define-color warning @yellow;
      @define-color error   @red;
      @define-color info    @blue;

      /* Module-specific background colors */
      @define-color bg-workspaces #2a2a37;
      @define-color bg-clock      #7aa89f;
      @define-color bg-system     #363646;
      @define-color bg-network    #363646;
      @define-color bg-audio      #363646;
      @define-color bg-launcher   #957fb8;
      @define-color bg-power      #e82424;
    '';

    environment.etc."waybar/modules.jsonc".text = ''

           {
        // Launcher
        "custom/launcher": {
          "format": "",
          "on-click": "rofi -show drun",
          "tooltip": false
        },

        // Workspaces (Hyprland)
        "hyprland/workspaces": {
          "on-scroll-up": "hyprctl dispatch workspace r-1",
          "on-scroll-down": "hyprctl dispatch workspace r+1",
          "on-click": "activate",
          "active-only": false,
          "all-outputs": true,
          "format": "{}",
          "format-icons": {
            "urgent": "",
            "active": "",
            "default": ""
          },
          "persistent-workspaces": {
            "*": 5
          }
        },

        // Weather
        "custom/weather": {
          "exec": "~/.config/waybar/scripts/openweathermap.sh",
          "interval": 1800,
          "format": "{}",
          "tooltip": false
        },

        // Check updates pacman or aur
        "custom/updates": {
          "format": "{}",
          "return-type": "json",
          "escape": true,
          "tooltip": true,
          "exec": "~/.config/waybar/scripts/check_updates.sh",
          "interval": 1800,
          "signal": 1,
          "hide-empty-text": true,
          "on-click": "~/.config/waybar/scripts/update_system.sh"
        },

        // CAVA Audio Visualizer
        "custom/cava": {
          "exec": "~/.config/waybar/scripts/cava.sh",
          "format": "♪ {}",
          "on-click-middle": "playerctl play-pause",
          "on-click-right": "playerctl next",
          "on-click-left": "playerctl previous"
        },

        // Memory / CPU / Temp
        "memory": {
          "format": " {: >3}%",
          "on-click": "neohtop"
        },
        "cpu": {
          "format": "󰘚 {usage: >3}%",
          "on-click": "neohtop"
        },
        "temperature": {
          "hwmon-path": "/sys/class/hwmon/hwmon1/temp1_input",
          "critical-threshold": 80,
          "format": "  {temperatureC}°C",
          "on-click": "neohtop"
        },

        // Idle inhibitor
        "idle_inhibitor": {
          "format": "{icon}",
          "format-icons": {
            "activated": "󰌾",
            "deactivated": "󰌵"
          },
          "tooltip-format-activated": "Idle inhibitor: ON",
          "tooltip-format-deactivated": "Idle inhibitor: OFF"
        },

        // Battery
        "battery": {
          "states": {
            "warning": 30,
            "critical": 15
          },
          "format": "{icon} {capacity: >3}%",
          "format-icons": ["", "", "", "", ""]
        },

        // Language (Hyprland)
        "hyprland/language": {
          "format": "󰌌 {short}",
          "tooltip-format": "Language: {long}"
        },

        // Keyboard state
        "keyboard-state": {
          //"numlock": true,
          "capslock": true,
          "format": "{name} {icon} ",
          "format-icons": {
            "locked": " ",
            "unlocked": ""
          }
        },

        // Backlight
        "backlight": {
          "format": "{icon} {percent: >3}%",
          "format-icons": ["", ""],
          "on-scroll-down": "brightnessctl set 5%-",
          "on-scroll-up": "brightnessctl set +5%"
        },

        // Audio
        "pulseaudio": {
          "scroll-step": 1,
          "format": "{icon} {volume: >3}%",
          "format-bluetooth": "{icon} {volume: >3}%",
          "format-muted": " muted",
          "format-icons": {
            "headphones": "",
            "handsfree": "",
            "headset": "",
            "phone": "",
            "portable": "",
            "car": "",
            "default": ["", ""]
          },
          "on-click": "pavucontrol",
          "on-scroll-up": "pamixer -ui 2 && pamixer --get-volume > $SWAYSOCK.wob",
          "on-scroll-down": "pamixer -ud 2 && pamixer --get-volume > $SWAYSOCK.wob"
        },

        // Network
        "network": {
          "format": "{ifname}",
          "format-wifi": " {essid} ({signalStrength}%)",
          "format-ethernet": "  {ifname}",
          "format-disconnected": "Disconnected ⚠",
          "tooltip-format": " {ifname} via {gwaddri}",
          "tooltip-format-wifi": "  {ifname} @ {essid}\nIP: {ipaddr}\nStrength: {signalStrength}%\nFreq: {frequency}MHz\nUp: {bandwidthUpBits} Down: {bandwidthDownBits}",
          "tooltip-format-ethernet": " {ifname}\nIP: {ipaddr}\n up: {bandwidthUpBits} down: {bandwidthDownBits}",
          "tooltip-format-disconnected": "Disconnected",
          "max-length": 50,
          "on-click": "nm-connection-editor",
          "on-click-right": "nm-connection-editor"
        },

        // VPN (nmcli, JSON)
        "custom/vpn": {
          "format": "{}",
          "exec": "~/.config/waybar/scripts/vpn_status.sh",
          "on-click": "~/.config/waybar/scripts/vpn_status.sh --toggle",
          "interval": 5,
          "return-type": "text",
          "tooltip": true
        },

        // Clock
        "clock": {
          "format": "  {:%H:%M %a}",
          "format-alt": "  {:%d/%m/%Y  %H:%M:%S}",
          "tooltip-format": "<tt><small>{calendar}</small></tt>",
          "calendar": {
            "mode": "month",
            "mode-mon-col": 3,
            "weeks-pos": "right",
            "on-scroll": 1,
            "on-click-right": "mode",
            "format": {
              "months": "<span color='#ffead3'><b>{}</b></span>",
              "days": "<span color='#ecc6d9'><b>{}</b></span>",
              "weeks": "<span color='#99ffdd'><b>W{}</b></span>",
              "weekdays": "<span color='#ffcc66'><b>{}</b></span>",
              "today": "<span color='#ff6699'><b><u>{}</u></b></span>"
            }
          },
          "interval": 1
        },

        // Notifications (SwayNC)
        "custom/notification": {
          "tooltip-format": "Left: Notifications\nRight: Do not disturb",
          "format": "{icon}",
          "format-icons": {
            "notification": "<span rise='8pt'><span foreground='red'><sup></sup></span></span>",
            "none": "",
            "dnd-notification": "<span rise='8pt'><span foreground='red'><sup></sup></span></span>",
            "dnd-none": "",
            "inhibited-notification": "<span rise='8pt'><span foreground='red'><sup></sup></span></span>",
            "inhibited-none": "",
            "dnd-inhibited-notification": "<span rise='8pt'><span foreground='red'><sup></sup></span></span>",
            "dnd-inhibited-none": ""
          },
          "return-type": "json",
          "exec-if": "which swaync-client",
          "exec": "swaync-client -swb",
          "on-click": "swaync-client -t -sw",
          "on-click-right": "swaync-client -d -sw",
          "escape": true
        },

        // Tray
        "tray": {
          "icon-size": 20,
          "spacing": 10,
          "show-passive-items": true,
          "reverse-direction": false,
          "smooth-scrolling-threshold": 1.0
        }
      }
    '';

    # Waybar configuration
    environment.etc."waybar/config.jsonc".text = ''
      {

        "style": "./style.css",

        "include": "./modules.jsonc",

        "layer": "top",
        "position": "top",
        "height": 40,
        "modules-left": [
          "hyprland/workspaces",
          "custom/weather"
        ],
        "modules-center": [
          "clock",
          "memory",
          "cpu",
          "temperature"
        ],
        "modules-right": [
          "keyboard-state",
          "pulseaudio",
          "network",
          "tray"
        ],
        "clock": {
          "format": "{:%H:%M}",
          "tooltip-format": "{:%Y-%m-%d %A}",
          "interval": 1
        }
      }
    '';

    # EWW configuration
    /*
       environment.etc."eww/bar.yuck".text = ''
      (defwindow bar
        :geometry (geometry :x "0%"
                         :y "0%"
                         :width "40%"
                         :height "30px"
                         :anchor "top center")
        (centerbox :class "bar"
          (label :text "''${time.hour == 12 ? 12 : time.hour % 12}:''${time.minute < 10 ? \"0\" : \"\"}''${time.minute} ''${time.hour < 12 ? \"AM\" : \"PM\"}"))
      )
    '';
    */

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

    # Hyprsunset configuration file
    environment.etc."hypr/hyprsunset.conf".text = ''
      general {
          temperature = 3400
          sunset_time = "20:00"
          sunrise_time = "06:00"
          day_temperature = 6500
          mode = 1
          transition = 1
          ramp = 1
      }
    '';

    environment.etc."hypr/hyprpaper.conf".text = ''
      splash = false
      preload = /home/amadeus/Pictures/Wallpapers/nier.jpeg
      wallpaper = DP-3,/home/amadeus/Pictures/Wallpapers/nier.jpeg
      wallpaper = DP-2,/home/amadeus/Pictures/Wallpapers/nier.jpeg
    '';

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
