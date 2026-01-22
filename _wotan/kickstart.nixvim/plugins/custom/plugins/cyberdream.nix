{pkgs, ...}: {
  programs.nixvim = {
    colorschemes.cyberdream = {
      enable = false;
      settings = {
        # Enable transparency for terminal backgrounds
        transparent = true;

        # Use italic comments for better readability
        italic_comments = true;

        # Hide file tree background for cleaner look
        hide_fillchars = true;

        # High-contrast borders
        borderless_telescope = false;

        # Terminal colors for consistent theming
        terminal_colors = true;

        # Cache for better performance
        cache = true;

        # Theme variant (cyberdream is dark-only, this is the default)
        theme = {
          variant = "default";

          # Color overrides for extra neon punch
          colors = {
            # Enhance neon accents
            cyan = "#00ffff";
            magenta = "#ff00ff";
            pink = "#ff1493";
            purple = "#9d00ff";
          };
        };
      };
    };
  };
}
