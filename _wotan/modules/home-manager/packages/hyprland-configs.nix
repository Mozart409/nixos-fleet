{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.desktop.hyprland-configs;
in {
  options.desktop.hyprland-configs = {
    enable = lib.mkEnableOption "hyprland configs";
  };

  config = lib.mkIf cfg.enable {
    xdg.configFile."hypr/hyprsunset.conf".text = ''
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

    # Wallpaper rotation script for awww
    home.file.".local/bin/awww-random-wallpaper" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        WALLPAPER_DIR="/home/amadeus/Pictures/Wallpapers"
        WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' -o -name '*.gif' -o -name '*.webp' \) | shuf -n1)
        if [ -n "$WALLPAPER" ]; then
          awww img "$WALLPAPER" --transition-type grow --transition-fps 60 --transition-step 90
        fi
      '';
    };

    # Systemd service for wallpaper rotation
    systemd.user.services.awww-wallpaper-rotate = {
      Unit = {
        Description = "Rotate wallpaper using awww";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "%h/.local/bin/awww-random-wallpaper";
        Environment = [
          "PATH=${pkgs.findutils}/bin:${pkgs.coreutils}/bin"
        ];
      };
    };

    # Systemd timer for wallpaper rotation every 10 minutes
    systemd.user.timers.awww-wallpaper-rotate = {
      Unit = {
        Description = "Rotate wallpaper every 10 minutes";
      };
      Timer = {
        OnActiveSec = "10min";
        OnUnitActiveSec = "10min";
        Unit = "awww-wallpaper-rotate.service";
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };

    xdg.configFile."hypr/hypridle.conf".text = ''
      general {
          lock_cmd = pidof hyprlock || hyprlock       # avoid starting multiple hyprlock instances
          before_sleep_cmd = loginctl lock-session    # lock before suspend
          after_sleep_cmd = hyprctl dispatch dpms on  # turn on display after sleep
          ignore_dbus_inhibit = false                 # respect idle-inhibit requests (e.g., from firefox, steam)
          ignore_systemd_inhibit = false              # respect systemd-inhibit --what=idle inhibitors
      }

      # Screen dimming after 5 minutes
      listener {
          timeout = 300                               # 5 minutes
          on-timeout = if [ "$(playerctl status 2>/dev/null)" != "Playing" ]; then brightnessctl -s set 10; fi        # dim screen
          on-resume = brightnessctl -r                # restore brightness
      }

      # Screen off after 10 minutes
      listener {
          timeout = 600                               # 10 minutes
          on-timeout = if [ "$(playerctl status 2>/dev/null)" != "Playing" ]; then hyprctl dispatch dpms off; fi      # turn off screen
          on-resume = hyprctl dispatch dpms on        # turn on screen
      }

      # Lock screen after 20 minutes
      listener {
          timeout = 1200                              # 20 minutes
          on-timeout = if [ "$(playerctl status 2>/dev/null)" != "Playing" ]; then loginctl lock-session; fi          # lock screen
      }

      # Suspend after 60 minutes
      listener {
          timeout = 3600                              # 60 minutes
          on-timeout = if [ "$(playerctl status 2>/dev/null)" != "Playing" ]; then systemctl suspend; fi              # suspend system
      }
    '';

    xdg.configFile."hypr/hyprlock.conf".text = ''
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
  };
}
