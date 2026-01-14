{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    desktop.gtk.enable = lib.mkEnableOption "GTK theme configuration";
  };

  config = lib.mkIf config.desktop.gtk.enable {
    gtk = {
      enable = true;

      theme = {
        name = "Orchis-Dark";
        package = pkgs.orchis-theme;
      };

      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };

      cursorTheme = {
        # name = "Bibata-Modern-Classic";
        # package = pkgs.bibata-cursors;
        name = "Layan-cursors";
        package = pkgs.layan-cursors;
        size = 24;
      };

      font = {
        name = "Sans";
        size = 11;
      };

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    # Ensure theme packages are available
    home.packages = with pkgs; [
      orchis-theme
      papirus-icon-theme
      # bibata-cursors
      layan-cursors
    ];

    # Set environment variables for GTK and cursor theme
    home.sessionVariables = {
      GTK_THEME = "Orchis-Dark";
      # XCURSOR_THEME = "Bibata-Modern-Classic";
      XCURSOR_THEME = "Layan-cursors";
      XCURSOR_SIZE = "24";
    };
  };
}
