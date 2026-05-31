{
  config,
  pkgs,
  lib,
  ...
}: {
  # OnlyOffice Desktop Editors — declarative companion to LibreOffice.
  # Use for new spreadsheets / documents; LibreOffice remains the default
  # MIME handler until migration is complete.
  #
  # To discover more settings: tweak in the GUI, then read
  # ~/.config/onlyoffice/DesktopEditors.conf and copy keys here.
  programs.onlyoffice = {
    enable = true;

    settings = {
      UITheme = "theme-dark";

      # Autosave + recovery
      "asc.editor.autosave" = true;
      "asc.editor.recover" = true;

      # Locale (region-specific number/date formatting)
      "asc.editor.region" = "de-DE";

      # Window state
      maximized = true;
      titlebar = "custom";

      # Default editor font for new documents (Noto Sans @ 14pt).
      # NOTE: These key names are best-effort. After first launch, run
      #   cat ~/.config/onlyoffice/DesktopEditors.conf
      # and align the keys below with what OnlyOffice actually persisted.
      "fonts/default-name" = "Noto Sans";
      "fonts/default-size" = 14;
      "editor.font-name" = "Noto Sans";
      "editor.font-size" = 14;
    };
  };
}
