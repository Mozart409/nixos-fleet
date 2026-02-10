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
    themeFile = "Ciapre";
    # themeFile = "cherry_midnight";
    # themeFile = "vividpunk";
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
      font_family = "JetBrainsMono Nerd Font";
      bold_font = "JetBrainsMono Nerd Font Bold";
      italic_font = "JetBrainsMono Nerd Font Italic";
      bold_italic_font = "JetBrainsMono Nerd Font Bold Italic";
      font_size = 13;

      # Misc
      update_check_interval = 0;
      background_opacity = "1.0";

      # Startup directory
      startup_session = "none";
    };
    extraConfig = ''
      # Set working directory
      cd /home/amadeus/code
    '';
  };

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

      general.working_directory = "/home/amadeus/code";
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
