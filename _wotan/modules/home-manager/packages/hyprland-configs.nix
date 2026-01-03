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

    xdg.configFile."hypr/hyprpaper.conf".text = ''
      splash = false
      preload = /home/amadeus/Pictures/Wallpapers/nier.jpeg
      wallpaper = DP-3,/home/amadeus/Pictures/Wallpapers/nier.jpeg
      wallpaper = DP-2,/home/amadeus/Pictures/Wallpapers/nier.jpeg
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
