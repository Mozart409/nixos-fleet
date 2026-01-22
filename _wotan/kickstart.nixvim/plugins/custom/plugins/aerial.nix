{pkgs, ...}: {
  programs.nixvim.plugins.aerial = {
    enable = true;

    settings = {
      # Priority list of preferred backends for aerial
      backends = ["treesitter" "lsp" "markdown" "asciidoc" "man"];

      layout = {
        max_width = [40 0.2];
        width = null;
        min_width = 10;

        default_direction = "prefer_right";
        placement = "window";

        resize_to_content = true;
        preserve_equality = false;
      };

      # Determine how the aerial window should be attached
      attach_mode = "window";

      # When jumping to a symbol, highlight the line for this many ms
      highlight_on_hover = true;
      highlight_on_jump = 300;

      # Automatically open aerial when entering supported buffer
      open_automatic = false;

      # Show box drawing characters for the tree hierarchy
      show_guides = true;

      # Filter kind types
      filter_kind = false;

      # Icons and symbols
      icons = {};

      # Control which windows aerial will ignore
      ignore = {
        unlisted_buffers = false;
        diff_windows = true;
        filetypes = {};
        buftypes = "special";
        wintypes = "special";
      };

      # Use symbol tree for folding
      manage_folds = false;
      link_folds_to_tree = false;
      link_tree_to_folds = true;

      # LSP symbol kinds to show
      lsp = {
        diagnostics_trigger_update = true;
        update_when_errors = true;
        update_delay = 300;
      };

      treesitter = {
        update_delay = 300;
      };
    };

    # Keymaps
  };

  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>a";
      action = "<cmd>AerialToggle!<CR>";
      options = {
        desc = "[A]erial symbols toggle";
      };
    }
  ];
}
