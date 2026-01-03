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
      font = "JetBrainsMono 18";
      terminal = "alacritty";
      cycle = true;
      location = "center";
      theme = "DarkBlue";
      plugins = with pkgs; [
        rofi-calc
        rofi-nerdy
        rofi-file-browser
        rofi-pass-wayland
      ];
      modes = [
        "drun"
        "run"
        "window"
        "ssh"
      ];
      extraConfig = {
        show-icons = true;
      };
    };
  };
}
