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

      # Active icon theme: Colloid.
      #
      # The name must match the theme directory exactly -- it is
      # "Colloid-Dark", with a capital D, and icon theme lookup is
      # case-sensitive. This read "Colloid-dark" until 2026-09-10, which
      # resolved to nothing at all: every themed icon silently fell back, and
      # in Qt apps `QIcon::hasThemeIcon` returned false even for icons that
      # plainly exist. Verify with `ls ~/.nix-profile/share/icons` and
      # `grep '^Name=' .../Colloid-Dark/index.theme` before changing.
      iconTheme = {
        name = "Colloid-Dark";
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
      # keep-sorted start
      # XCursor fallback
      bibata-cursors
      # Active icon theme
      colloid-icon-theme
      # Hyprcursor theme
      inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
      # Inactive but available icon themes
      papirus-icon-theme
      # keep-sorted end
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
