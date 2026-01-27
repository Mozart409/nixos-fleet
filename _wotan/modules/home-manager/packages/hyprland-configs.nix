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

    services.dunst = {
      enable = true;
      package = pkgs.dunst;
      settings = {
        global = {
          monitor = 0;
          follow = "keyboard";
          # Replaced deprecated geometry setting with width, height, origin, offset
          width = 320;
          height = "(0, 100)";
          origin = "top-right";
          offset = "(32, 48)";
          transparency = 0;
          separator_height = 2;
          padding = 18;
          horizontal_padding = 24;
          notification_limit = 2;
          font = "FiraCode Nerd Font 10";
          line_height = 0;
          format = "<b>%s</b>\\n%b";
          alignment = "left";
          icon_position = "left";
          min_icon_size = 48;
          max_icon_size = 80;
          frame_width = 2;
          corner_radius = 12;
          word_wrap = true;
          sort = true;
          indicate_hidden = true;
          show_indicators = false;
          idle_threshold = 120;
          enable_recursive_icon_lookup = true;
          stack_duplicates = true;
          mouse_left_click = "close_current";
          mouse_middle_click = "do_action";
          mouse_right_click = "close_all";
        };

        urgency_low = {
          background = "#1a1a1f";
          foreground = "#cfd6f4";
          frame_color = "#33ccff";
          timeout = 4;
        };

        urgency_normal = {
          background = "#1a1a1f";
          foreground = "#e6e9ef";
          frame_color = "#00ff99";
          timeout = 6;
        };

        urgency_critical = {
          background = "#2b1117";
          foreground = "#ffd7e2";
          frame_color = "#ff4d6d";
          timeout = 0;
        };
      };
    };
  };
}
