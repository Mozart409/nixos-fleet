{pkgs, ...}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      gcc15
    ];
    # Highlight, edit, and navigate code
    # https://nix-community.github.io/nixvim/plugins/treesitter/index.html
    plugins.treesitter = {
      enable = true;

      # TODO: Don't think I need this as nixGrammars is true which should auto install these???
      settings = {
        ensureInstalled = [
          "bash"
          "c"
          "c_sharp"
          "css"
          "cue"
          "diff"
          "gitcommit"
          "go"
          "html"
          "javascript"
          "json"
          "jsonc"
          "lua"
          "luadoc"
          "markdown"
          "markdown_inline"
          "nix"
          "proto"
          "query"
          "razor"
          "rust"
          "sql"
          "tsx"
          "typescript"
          "vim"
          "vimdoc"
          "yaml"
        ];

        highlight = {
          enable = true;

          # Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
          additional_vim_regex_highlighting = true;
        };

        indent = {
          enable = true;
          disable = [
            "ruby"
          ];
        };

        # There are additional nvim-treesitter modules that you can use to interact
        # with nvim-treesitter. You should go explore a few and see what interests you:
        #
        #    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
        #    - Show your current context: https://nix-community.github.io/nixvim/plugins/treesitter-context/index.html
        #    - Treesitter + textobjects: https://nix-community.github.io/nixvim/plugins/treesitter-textobjects/index.html
      };
    };

    plugins.treesitter-textobjects = {
      enable = true;
      settings = {
        select = {
          enable = true;
          lookahead = true;
          keymaps = {
            "af" = "@function.outer";
            "if" = "@function.inner";
            "ac" = "@class.outer";
            "ic" = "@class.inner";
            "aa" = "@parameter.outer";
            "ia" = "@parameter.inner";
          };
        };

        move = {
          enable = true;
          set_jumps = true;
          goto_next_start = {
            "]m" = "@function.outer";
            "]a" = "@parameter.inner";
          };
          goto_next_end = {
            "]M" = "@function.outer";
            "]A" = "@parameter.inner";
          };
          goto_previous_start = {
            "[m" = "@function.outer";
            "[a" = "@parameter.inner";
          };
          goto_previous_end = {
            "[M" = "@function.outer";
            "[A" = "@parameter.inner";
          };
        };

        swap = {
          enable = true;
          swap_next = {
            ">a" = "@parameter.inner";
          };
          swap_previous = {
            "<a" = "@parameter.inner";
          };
        };
      };
    };
  };
}
