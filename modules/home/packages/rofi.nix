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
      # Matches the quickshell bar. See the header of that file before editing.
      theme = ./rofi/theme.rasi;
      plugins = with pkgs; [
        rofi-calc
        rofi-nerdy
        rofi-file-browser
      ];
      # Native rofi names and values (rendered into the `configuration {}`
      # block of config.rasi). Font lives in the .rasi theme instead: setting
      # it here too means two places to change, and the theme's value wins
      # anyway.
      settings = {
        terminal = "kitty";
        cycle = true;
        # Numeric rofi location: 0 is center.
        location = 0;
        show-icons = true;
        # Every plugin above also has to be listed here, or rofi enables its
        # mode ad-hoc on each invocation and nags on stderr.
        #
        # Mode names are not the package names, and `rofi -h` is the only
        # authority -- it prints a "Detected modes" list. Note
        # file-browser-extended is the one rofi-file-browser supplies; plain
        # `filebrowser` and `recursivebrowser` are rofi's own built-ins and
        # need no plugin.
        modes = [
          "drun"
          "run"
          "window"
          "ssh"
          "calc"
          "nerdy"
          "file-browser-extended"
        ];
      };
    };

    # rofi -password (what pinentry-rofi uses) masks input with literal '*'.
    # Berkeley Mono's calt ligates a run of exactly three asterisks into a
    # single glyph one cell wide (advance 600) with a -920 left side bearing,
    # so it draws backwards over the two preceding cells -- a 3-character
    # passphrase prefix renders as an overlapping cluster instead of "***".
    # Four or more asterisks are suppressed by the font's own chain context,
    # which is why the field looks normal again from the fourth keystroke.
    # Scoped to rofi by prgname so terminal and editor ligatures are untouched;
    # ligatures buy nothing in a launcher anyway.
    xdg.configFile."fontconfig/conf.d/99-rofi-no-ligatures.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <match target="font">
          <test target="pattern" name="prgname" compare="eq">
            <string>rofi</string>
          </test>
          <test name="family" compare="eq">
            <string>Berkeley Mono</string>
          </test>
          <edit name="fontfeatures" mode="append">
            <string>calt off</string>
          </edit>
        </match>
      </fontconfig>
    '';
  };
}
