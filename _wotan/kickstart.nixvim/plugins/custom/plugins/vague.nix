{pkgs, ...}: {
  programs.nixvim = {
    # Add vague.nvim plugin
    extraPlugins = with pkgs.vimPlugins; [
      vague-nvim
    ];

    # Configure vague.nvim theme
    extraConfigLua = ''
      -- Configure vague.nvim
      require('vague').setup({
        transparent = true, -- Enable transparent background
        style = {
          boolean = "none",
          number = "none",
          float = "none",
          error = "none",
          comments = "italic",
          conditionals = "none",
          functions = "none",
          headings = "bold",
          operators = "none",
          strings = "none",
          variables = "none",

          -- Keywords
          keywords = "none",
          keyword_return = "none",
          keywords_loop = "none",
          keywords_label = "none",
          keywords_exception = "none",

          -- Builtin
          builtin_constants = "none",
          builtin_functions = "none",
          builtin_types = "none",
          builtin_variables = "none",
        },
        -- Custom color overrides (optional)
        colors = {
          -- You can customize colors here if needed
        },
      })

      -- Apply the colorscheme
      vim.cmd([[colorscheme vague]])
    '';
  };
}
