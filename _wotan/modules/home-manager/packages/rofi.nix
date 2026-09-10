{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.desktop.rofi;
in {
  options.desktop.rofi = {
    enable = lib.mkEnableOption "rofi";
  };

  config = lib.mkIf cfg.enable {
    programs.rofi = {
      enable = true;
      # Font lives in the .rasi theme instead: setting it here too means two
      # places to change, and the theme's value wins anyway.
      terminal = "kitty";
      cycle = true;
      location = "center";
      # Matches the quickshell bar. See the header of that file before editing.
      theme = ./rofi/theme.rasi;
      plugins = with pkgs; [
        rofi-calc
        rofi-nerdy
        rofi-file-browser
      ];
      # Every plugin above also has to be listed here, or rofi enables its mode
      # ad-hoc on each invocation and nags on stderr.
      #
      # Mode names are not the package names, and `rofi -h` is the only
      # authority -- it prints a "Detected modes" list. Note file-browser-extended
      # is the one rofi-file-browser supplies; plain `filebrowser` and
      # `recursivebrowser` are rofi's own built-ins and need no plugin.
      modes = [
        "drun"
        "run"
        "window"
        "ssh"
        "calc"
        "nerdy"
        "file-browser-extended"
      ];
      extraConfig = {
        show-icons = true;
      };
    };
  };
}
