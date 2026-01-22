{pkgs, ...}: {
  programs.nixvim.plugins.dressing = {
    enable = true;

    settings = {
      input = {
        enabled = true;
        default_prompt = "Input";
        trim_prompt = true;

        # Use fzf-lua for input
        prefer_width = 40;
        max_width = [0.9 90];
        min_width = [20 0.2];

        border = "rounded";
        relative = "cursor";

        win_options = {
          winblend = 0;
          wrap = false;
          list = true;
          listchars = "precedes:…,extends:…";
          sidescrolloff = 0;
        };
      };

      select = {
        enabled = true;

        # Use fzf-lua as backend
        backend = ["fzf_lua" "telescope" "builtin"];

        trim_prompt = true;

        fzf_lua = {
          winopts = {
            height = 0.5;
            width = 0.5;
          };
        };

        builtin = {
          show_numbers = true;
          border = "rounded";
          relative = "editor";

          win_options = {
            winblend = 0;
            cursorline = true;
            cursorlineopt = "both";
          };

          max_width = [0.8 140];
          min_width = [40 0.2];
          max_height = [0.9 30];
          min_height = [4 0.1];
        };
      };
    };
  };
}
