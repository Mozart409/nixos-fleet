{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.kitty = {
    enable = false;
    shellIntegration.enableZshIntegration = true;
    # font = "FiraCode";
    themeFile = "kanagawa_dragon";
    settings = {
      scrollback_lines = 10000;
      enable_audio_bell = false;
      update_check_interval = 0;
    };
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
      scrolling.history = 10000;

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
