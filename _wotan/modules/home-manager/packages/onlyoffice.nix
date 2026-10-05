{
  config,
  pkgs,
  lib,
  ...
}: let
  # Build a minimal blank .docx / .xlsx with Noto Sans 14pt as the default
  # style. OOXML stores defaults inside the document, so this is the only
  # reliable way to override Calibri 11pt for new files.
  mkTemplate = name: src:
    pkgs.runCommand name {nativeBuildInputs = [pkgs.zip];} ''
      cd ${src}
      zip -rX $out . -x '*.swp'
    '';

  blankDocx = mkTemplate "blank.docx" ./onlyoffice-templates/docx;
  blankXlsx = mkTemplate "blank.xlsx" ./onlyoffice-templates/xlsx;
in {
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
    };
  };

  # Blank templates with Noto Sans 14pt as default. Use via:
  #   - Thunar right-click "Create Document" / "Create Spreadsheet"
  #   - OnlyOffice: File -> Open -> ~/Templates/blank.docx (then Save As)
  xdg.userDirs = {
    enable = true;
    templates = "${config.home.homeDirectory}/Templates";
    setSessionVariables = true;
  };

  home.file = {
    "Templates/Empty Document.docx".source = blankDocx;
    "Templates/Empty Spreadsheet.xlsx".source = blankXlsx;
  };
}
