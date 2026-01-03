{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.desktop.ironbar;
in {
  options.desktop.ironbar = {
    enable = lib.mkEnableOption "ironbar";
  };

  config = lib.mkIf cfg.enable {
    programs.ironbar = {
      enable = true;
      systemd = false;
      # config = {};
    };
  };
}
