{
  programs.nixvim = {
    # Drop.nvim - Animated screensaver plugin
    # DISABLED - Enable if you want animated effects when idle
    # Works well alongside alpha-nvim
    plugins.drop = {
      enable = false;
      settings = {
        # Theme options: "stars", "snow", "xmas", "spring", "summer", "leaves", "rain"
        theme = "stars";

        # Maximum number of drops on the screen
        max = 40;

        # Time in milliseconds before screensaver starts (5 minutes)
        interval = 300000;

        # Enable screensaver mode (starts after interval)
        screensaver = true;

        # File types to exclude from drop effects
        filetypes = [
          "dashboard"
          "alpha"
          "neo-tree"
          "TelescopePrompt"
          "lazy"
          "mason"
          "notify"
          "toggleterm"
          "fzf"
        ];
      };
    };

    # Optional: Add keybinding to manually trigger drop animation
    # Uncomment when enabled
    # keymaps = [
    #   {
    #     mode = "n";
    #     key = "<leader>ud";
    #     action = "<cmd>Drop<cr>";
    #     options = {
    #       desc = "Toggle Drop animation";
    #       silent = true;
    #     };
    #   }
    # ];
  };
}
