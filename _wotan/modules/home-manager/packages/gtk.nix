{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    desktop.gtk.enable = lib.mkEnableOption "GTK cursor and icon theme configuration";
  };

  config = lib.mkIf config.desktop.gtk.enable {
    # GTK enabled for dconf portal support but no theming
    gtk = {
      enable = true;

      # No GTK3 theme
      theme = null;

      # No GTK4 theme
      gtk4.theme = null;

      # Keep icon theme for file dialogs in non-GTK apps
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      cursorTheme = {
        name = "Layan-cursors";
        package = pkgs.layan-cursors;
        size = 24;
      };

      font = {
        name = "Sans";
        size = 11;
      };
    };

    # dconf for portal settings
    dconf.enable = true;

    home.packages = with pkgs; [
      papirus-icon-theme
      layan-cursors
    ];

    home.sessionVariables = {
      XCURSOR_THEME = "Layan-cursors";
      XCURSOR_SIZE = "24";
    };
  };
}
