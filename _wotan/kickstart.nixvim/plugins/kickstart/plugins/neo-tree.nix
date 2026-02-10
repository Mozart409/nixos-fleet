{
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;
      settings = {
        add_blank_line_at_top = true;
        auto_clean_after_session_restore = true;
        close_if_last_window = true;
        filesystem = {
          # Open in current window when running nvim . to avoid empty buffer
          hijack_netrw_behavior = "open_current";
          window = {
            mappings = {
              "\\" = "close_window";
            };
          };
        };
      };
    };

    # https://nix-community.github.io/nixvim/keymaps/index.html

    keymaps = [
      {
        key = "<leader>fe";
        action = "<cmd>Neotree reveal<cr>";
        options = {
          desc = "NeoTree reveal";
        };
      }
    ];
  };
}
