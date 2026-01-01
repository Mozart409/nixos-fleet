{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.desktop.waybar;
in
{
  options.desktop.waybar = {
    enable = lib.mkEnableOption "waybar";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."waybar/config.jsonc".source = pkgs.writeTextFile {
      name = "waybar-config";
      text = builtins.toJSON {
        style = "${config.xdg.configHome}/waybar/style.css";
        include = "${config.xdg.configHome}/waybar/modules.jsonc";
        layer = "top";
        position = "top";
        height = 40;
        "modules-left" = [
          "hyprland/workspaces"
          "custom/weather"
        ];
        "modules-center" = [
          "clock"
          "memory"
          "cpu"
          "temperature"
        ];
        "modules-right" = [
          "keyboard-state"
          "pulseaudio"
          "network"
          "tray"
        ];
        clock = {
          format = "{:%H:%M}";
          "tooltip-format" = "{:%Y-%m-%d %A}";
          interval = 1;
        };
      };
    };

    xdg.configFile."waybar/style.css".source = pkgs.writeTextFile {
      name = "waybar-style";
      text = ''
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

        * {
          border: none;
          border-radius: 0;
          font-family: "SF Pro Display", "Segoe UI", sans-serif;
          font-size: 14px;
          min-height: 0;
        }

        window#waybar {
          background-color: @background-primary;
          color: @text;
          transition-property: background-color;
          transition-duration: 0.2s;
        }

        tooltip {
          background-color: @background-secondary;
          border: 1px solid @border-color;
          border-radius: 4px;
          color: @text;
        }

        #workspaces button {
          background-color: @bg-workspaces;
          color: @text;
          padding: 4px 8px;
          margin: 0 2px;
          border-radius: 4px;
          min-width: 24px;
        }

        #workspaces button.active {
          background-color: @blue;
          color: @crust;
        }

        #workspaces button.urgent {
          background-color: @red;
          color: @text;
        }

        #clock,
        #memory,
        #cpu,
        #temperature {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }

        #keyboard-state {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }

        #pulseaudio,
        #network,
        #tray {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }

        #battery {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }

        #battery.charging,
        #battery.full {
          color: @green;
        }

        #battery.warning {
          color: @yellow;
        }

        #battery.critical {
          color: @red;
        }

        #custom-launcher {
          background-color: @bg-launcher;
          color: @crust;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px 0 0 4px;
        }

        #custom-weather,
        #custom-updates,
        #custom-cava {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }

        #idle_inhibitor {
          background-color: @bg-system;
          color: @text;
          padding: 4px 12px;
          margin: 0 4px;
          border-radius: 4px;
        }
      '';
    };

    xdg.configFile."waybar/modules.jsonc".source = pkgs.writeTextFile {
      name = "waybar-modules";
      text = builtins.toJSON {
        "custom/launcher" = {
          format = "";
          "on-click" = "wofi --show drun";
          tooltip = false;
        };

        "hyprland/workspaces" = {
          "on-scroll-up" = "hyprctl dispatch workspace r-1";
          "on-scroll-down" = "hyprctl dispatch workspace r+1";
          "on-click" = "activate";
          "active-only" = false;
          "all-outputs" = true;
          format = "{}";
          "format-icons" = {
            urgent = "";
            active = "";
            default = "";
          };
          "persistent-workspaces" = {
            "*" = 5;
          };
        };

        "custom/weather" = {
          exec = "${config.xdg.configHome}/waybar/scripts/weather.sh";
          interval = 1800;
          format = "{}";
          tooltip = false;
        };

        "custom/updates" = {
          format = "{}";
          "return-type" = "json";
          escape = true;
          tooltip = true;
          exec = "${config.xdg.configHome}/waybar/scripts/check_updates.sh";
          interval = 1800;
          signal = 1;
          "hide-empty-text" = true;
          "on-click" = "${config.xdg.configHome}/waybar/scripts/update_system.sh";
        };

        "custom/cava" = {
          exec = "${config.xdg.configHome}/waybar/scripts/cava.sh";
          format = "♪ {}";
          "on-click-middle" = "playerctl play-pause";
          "on-click-right" = "playerctl next";
          "on-click-left" = "playerctl previous";
        };

        memory = {
          format = " {: >3}%";
          "on-click" = "neohtop";
        };

        cpu = {
          format = "󰘚 {usage: >3}%";
          "on-click" = "neohtop";
        };

        temperature = {
          "hwmon-path" = "/sys/class/hwmon/hwmon1/temp1_input";
          "critical-threshold" = 80;
          format = "  {temperatureC}°C";
          "on-click" = "neohtop";
        };

        idle_inhibitor = {
          format = "{icon}";
          "format-icons" = {
            activated = "󰌾";
            deactivated = "󰌵";
          };
          "tooltip-format-activated" = "Idle inhibitor: ON";
          "tooltip-format-deactivated" = "Idle inhibitor: OFF";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{icon} {capacity: >3}%";
          "format-icons" = ["" "" "" "" ""];
        };

        "hyprland/language" = {
          format = "󰌌 {short}";
          "tooltip-format" = "Language: {long}";
        };

        "keyboard-state" = {
          capslock = true;
          format = "{name} {icon} ";
          "format-icons" = {
            locked = " ";
            unlocked = "";
          };
        };

        backlight = {
          format = "{icon} {percent: >3}%";
          "format-icons" = ["" ""];
          "on-scroll-down" = "brightnessctl set 5%-";
          "on-scroll-up" = "brightnessctl set +5%";
        };

        pulseaudio = {
          "scroll-step" = 1;
          format = "{icon} {volume: >3}%";
          "format-bluetooth" = "{icon} {volume: >3}%";
          "format-muted" = " muted";
          "format-icons" = {
            headphones = "";
            handsfree = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" ""];
          };
          "on-click" = "pavucontrol";
          "on-scroll-up" = "pamixer -ui 2 && pamixer --get-volume > $SWAYSOCK.wob";
          "on-scroll-down" = "pamixer -ud 2 && pamixer --get-volume > $SWAYSOCK.wob";
        };

        network = {
          format = "{ifname}";
          "format-wifi" = " {essid} ({signalStrength}%)";
          "format-ethernet" = "  {ifname}";
          "format-disconnected" = "Disconnected ⚠";
          "tooltip-format" = " {ifname} via {gwaddri}";
          "tooltip-format-wifi" = "  {ifname} @ {essid}\nIP: {ipaddr}\nStrength: {signalStrength}%\nFreq: {frequency}MHz\nUp: {bandwidthUpBits} Down: {bandwidthDownBits}";
          "tooltip-format-ethernet" = " {ifname}\nIP: {ipaddr}\n up: {bandwidthUpBits} down: {bandwidthDownBits}";
          "tooltip-format-disconnected" = "Disconnected";
          "max-length" = 50;
          "on-click" = "nm-connection-editor";
          "on-click-right" = "nm-connection-editor";
        };

        "custom/vpn" = {
          format = "{}";
          exec = "${config.xdg.configHome}/waybar/scripts/vpn_status.sh";
          "on-click" = "${config.xdg.configHome}/waybar/scripts/vpn_status.sh --toggle";
          interval = 5;
          "return-type" = "text";
          tooltip = true;
        };

        clock = {
          format = "  {:%H:%M %a}";
          "format-alt" = "  {:%d/%m/%Y  %H:%M:%S}";
          "tooltip-format" = "<tt><small>{calendar}</small></tt>";
          calendar = {
            mode = "month";
            "mode-mon-col" = 3;
            "weeks-pos" = "right";
            "on-scroll" = 1;
            "on-click-right" = "mode";
            format = {
              months = "<span color='#ffead3'><b>{}</b></span>";
              days = "<span color='#ecc6d9'><b>{}</b></span>";
              weeks = "<span color='#99ffdd'><b>W{}</b></span>";
              weekdays = "<span color='#ffcc66'><b>{}</b></span>";
              today = "<span color='#ff6699'><b><u>{}</u></b></span>";
            };
          };
          interval = 1;
        };

        "custom/notification" = {
          "tooltip-format" = "Left: Notifications\nRight: Do not disturb";
          format = "{icon}";
          "format-icons" = {
            notification = "<span rise='8pt'><span foreground='red'><sup></sup></span></span>";
            none = "";
            "dnd-notification" = "<span rise='8pt'><span foreground='red'><sup></sup></span></span>";
            "dnd-none" = "";
            "inhibited-notification" = "<span rise='8pt'><span foreground='red'><sup></sup></span></span>";
            "inhibited-none" = "";
            "dnd-inhibited-notification" = "<span rise='8pt'><span foreground='red'><sup></sup></span></span>";
            "dnd-inhibited-none" = "";
          };
          "return-type" = "json";
          "exec-if" = "which swaync-client";
          exec = "swaync-client -swb";
          "on-click" = "swaync-client -t -sw";
          "on-click-right" = "swaync-client -d -sw";
          escape = true;
        };

        tray = {
          "icon-size" = 20;
          spacing = 10;
          "show-passive-items" = true;
          "reverse-direction" = false;
          "smooth-scrolling-threshold" = 1.0;
        };
      };
    };

    xdg.configFile."waybar/scripts/weather.sh".source = pkgs.writeTextFile {
      name = "waybar-weather";
      executable = true;
      text = ''
        #!/bin/bash

        API_KEY="ed9e1f66545f2f25d7bb0655c4116045"
        CITY_ID="2867714"
        UNITS="metric"
        LANG="en"

        check_api_key() {
            local test_request=$(curl -s "api.openweathermap.org/data/2.5/weather?q=London&appid=$API_KEY")
            if [[ $test_request == *"Invalid API key"* ]]; then
                echo "󰖙 Invalid API key"
                exit 1
            fi
        }

        get_icon() {
            local condition=$1
            local is_day=$2

            case $condition in
                "Clear")
                    if [ "$is_day" = "true" ]; then
                        echo "󰖙"
                    else
                        echo "󰖔"
                    fi
                    ;;
                "Clouds")
                    case $3 in
                        "few clouds") echo "󰖕" ;;
                        "scattered clouds") echo "󰖕" ;;
                        *) echo "󰖐" ;;
                    esac
                    ;;
                "Rain")
                    if [[ $3 == *"light"* ]]; then
                        echo "󰖖"
                    else
                        echo "󰖗"
                    fi
                    ;;
                "Drizzle")
                    echo "󰖖"
                    ;;
                "Thunderstorm")
                    echo "󰖓"
                    ;;
                "Snow")
                    echo "󰖘"
                    ;;
                "Mist"|"Fog"|"Haze")
                    echo "󰖑"
                    ;;
                *)
                    echo "󰖜"
                    ;;
            esac
        }

        check_api_key

        WEATHER_DATA=$(curl -s "api.openweathermap.org/data/2.5/weather?id=$CITY_ID&appid=$API_KEY&units=$UNITS&lang=$LANG")

        if [ -n "$WEATHER_DATA" ]; then
            TEMP=$(echo $WEATHER_DATA | jq -r '.main.temp')
            DESCRIPTION=$(echo $WEATHER_DATA | jq -r '.weather[0].main')
            DETAILED_DESC=$(echo $WEATHER_DATA | jq -r '.weather[0].description')
            FEELS_LIKE=$(echo $WEATHER_DATA | jq -r '.main.feels_like')
            SUNRISE=$(echo $WEATHER_DATA | jq -r '.sys.sunrise')
            SUNSET=$(echo $WEATHER_DATA | jq -r '.sys.sunset')

            CURRENT_TIME=$(date +%s)
            IS_DAY="true"
            if [ $CURRENT_TIME -lt $SUNRISE ] || [ $CURRENT_TIME -gt $SUNSET ]; then
                IS_DAY="false"
            fi

            TEMP=$(printf "%.0f" $TEMP)
            FEELS_LIKE=$(printf "%.0f" $FEELS_LIKE)

            ICON=$(get_icon "$DESCRIPTION" "$IS_DAY" "$DETAILED_DESC")

            echo "$ICON $TEMP°C 󰤾 $FEELS_LIKE°C"
        else
            echo "󰖙 Weather unavailable"
        fi
      '';
    };
  };
}
