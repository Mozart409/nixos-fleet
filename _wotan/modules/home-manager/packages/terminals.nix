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
    themeFile = "Thayer_Bright";
    settings = {
      # Window
      window_padding_width = 5;
      hide_window_decorations = false;
      confirm_os_window_close = 0;

      # Scrollback
      scrollback_lines = 10000;

      # Bell
      enable_audio_bell = false;

      # Font
      # Use "auto" for styled faces so kitty derives bold/italic from the
      # JetBrainsMono family. Explicit names like "JetBrainsMono Nerd Font Bold"
      # do not match any face and silently fall back to NotoSansMono.
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      font_size = 13;

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

  programs.alacritty = {
    enable = true;
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

      font = {
        normal.family = "JetBrainsMono Nerd Font";
        bold.family = "JetBrainsMono Nerd Font";
        italic.family = "JetBrainsMono Nerd Font";
        size = 13;
      };

      window.opacity = 1.0;
    };
  };
}
