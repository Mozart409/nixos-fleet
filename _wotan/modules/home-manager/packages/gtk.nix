{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  options = {
    desktop.gtk.enable = lib.mkEnableOption "GTK cursor and icon theme configuration";
  };

  config = lib.mkIf config.desktop.gtk.enable {
    # GTK with Catppuccin theming
    gtk = {
      enable = true;

      # Adwaita dark theme
      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };

      # GTK4 uses libadwaita, no theme override
      gtk4.theme = null;

      # Active icon theme: Colloid
      iconTheme = {
        name = "Colloid-dark";
        package = pkgs.colloid-icon-theme;
      };

      # XCursor fallback for apps that don't support hyprcursor (GTK, Qt)
      cursorTheme = {
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
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
      # Active icon theme
      colloid-icon-theme
      # Inactive but available icon themes
      papirus-icon-theme
      # XCursor fallback
      bibata-cursors
      # Hyprcursor theme
      inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    # Cursor environment variables
    home.sessionVariables = {
      # Hyprcursor for Wayland-native apps
      HYPRCURSOR_THEME = "rose-pine-hyprcursor";
      HYPRCURSOR_SIZE = "24";
      # XCursor fallback for GTK/Qt apps
      XCURSOR_THEME = "Bibata-Modern-Ice";
      XCURSOR_SIZE = "24";
    };
  };
}
