{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = true;
    shellIntegration.enableZshIntegration = true;
    # themeFile = "kanagawa_wave";
    # themeFile = "Ciapre";
    # themeFile = "cherry_midnight";
    # themeFile = "VividPunk";
    # themeFile = "Thayer_Bright";
    # Bolder alternatives (one-line swap): kanagawa_dragon, Cyberpunk-Neon, Carbonfox
    #
    # BACKUP -- the previous theme. To go back, uncomment this line and delete
    # the "Colours" block in settings below; themeFile and explicit colour
    # settings both write colours into kitty.conf, so only one should be
    # active at a time.
    # themeFile = "tokyo_night_storm";
    settings = {
      # Colours -- derived from quickshell/Theme.qml so the terminal, the bar,
      # the launcher and notifications share one palette. tokyo_night_storm
      # (kept above) is a fine theme, but its blue-grey #24283b base and blue
      # accent sat visibly apart from this desktop's near-black and cyan.
      background = "#111119"; # Theme.bar
      foreground = "#cfd6f4"; # Theme.text
      cursor = "#33ccff"; # Theme.accent
      cursor_text_color = "#12121a"; # Theme.inverse
      selection_background = "#33ccff";
      selection_foreground = "#12121a";
      url_color = "#33ccff";

      # ANSI pairs: normal then bright. The semantic four (red/green/yellow/
      # magenta) are Theme's crit/good/warn/special so a red in the terminal is
      # the same red as a critical alert on the desktop.
      color0 = "#1e1e28"; # Theme.surface
      color8 = "#6c7086"; # Theme.muted
      color1 = "#ff6b6b"; # Theme.crit
      color9 = "#ff8b8b";
      color2 = "#a6e3a1"; # Theme.good
      color10 = "#bdecb9";
      color3 = "#f5c542"; # Theme.warn
      color11 = "#f8d774";
      color4 = "#33ccff"; # Theme.accent
      color12 = "#7addff";
      color5 = "#cba6f7"; # Theme.special
      color13 = "#dcc2fa";
      color6 = "#94e2d5";
      color14 = "#b4ece1";
      color7 = "#cfd6f4"; # Theme.text
      color15 = "#e6e9ef";

      # Window
      window_padding_width = 5;
      hide_window_decorations = false;
      confirm_os_window_close = 0;

      # Scrollback
      scrollback_lines = 10000;

      # Bell
      enable_audio_bell = false;

      # Font
      # Berkeley Mono (licensed, installed locally under ~/.local/share/fonts,
      # NOT committed to this public repo). "auto" lets kitty derive bold/italic
      # from the family's discrete faces.
      font_family = "Berkeley Mono";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 13;

      # Berkeley Mono has no icon glyphs. Route Nerd Font codepoints to the
      # standalone Symbols Nerd Font (pkgs.nerd-fonts.symbols-only).
      symbol_map = "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,U+E000-U+E00A,U+E0A0-U+E0A3,U+E0B0-U+E0C8,U+E0CA,U+E0CC-U+E0D7,U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6B5,U+E700-U+E7C5,U+EA60-U+EC1E,U+ED00-U+EFCE,U+F000-U+F2FF,U+F300-U+F381,U+F400-U+F533,U+F0001-U+F1AF0 Symbols Nerd Font";

      # Misc
      update_check_interval = 0;
      background_opacity = "1.0";

      # Open in ~/code via a session file. kitty has no "working_directory"
      # key (that is an Alacritty/Ghostty option and is silently ignored).
      startup_session = "${config.xdg.configHome}/kitty/startup.session";
    };
  };

  xdg.configFile."kitty/startup.session".text = ''
    cd ${config.home.homeDirectory}/code
    launch
  '';

  programs.ghostty = {
    enable = false;
  };

  # Disabled: kitty is the only terminal in use. Kept for reference.
  programs.alacritty = {
    enable = false;
    theme = "kanagawa_wave";
    # theme = "kanagawa_dragon";
    settings = {
      window = {
        decorations = "Full";
        dynamic_padding = true;
        padding = {
          x = 5;
          y = 5;
        };
        startup_mode = "Windowed";
        dynamic_title = true;
      };

      general.working_directory = "${config.home.homeDirectory}/code";
      scrolling.history = 1000;

      # Berkeley Mono (licensed, installed locally, not in this repo).
      # Alacritty has no symbol_map; missing icon glyphs fall back through
      # fontconfig to Symbols Nerd Font automatically.
      font = {
        normal.family = "Berkeley Mono";
        bold.family = "Berkeley Mono";
        italic.family = "Berkeley Mono";
        size = 13;
      };

      window.opacity = 1.0;
    };
  };
}
