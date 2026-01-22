{
  programs.nixvim = {
    plugins.fzf-lua = {
      enable = true;

      # FZF-lua keymaps
      keymaps = {
        # File pickers
        "<leader>sf" = {
          action = "files";
          options = {
            desc = "[S]earch [F]iles";
          };
        };
        "<leader>sg" = {
          action = "live_grep";
          options = {
            desc = "[S]earch by [G]rep";
          };
        };
        "<leader>sw" = {
          action = "grep_cword";
          options = {
            desc = "[S]earch current [W]ord";
          };
        };
        "<leader><leader>" = {
          action = "buffers";
          options = {
            desc = "[ ] Find existing buffers";
          };
        };
        "<leader>sh" = {
          action = "helptags";
          options = {
            desc = "[S]earch [H]elp";
          };
        };
        "<leader>sk" = {
          action = "keymaps";
          options = {
            desc = "[S]earch [K]eymaps";
          };
        };
        "<leader>ss" = {
          action = "builtin";
          options = {
            desc = "[S]earch [S]elect fzf-lua";
          };
        };
        "<leader>sd" = {
          action = "diagnostics_document";
          options = {
            desc = "[S]earch [D]iagnostics";
          };
        };
        "<leader>sr" = {
          action = "resume";
          options = {
            desc = "[S]earch [R]esume";
          };
        };
        "<leader>s." = {
          action = "oldfiles";
          options = {
            desc = "[S]earch Recent Files";
          };
        };
      };

      settings = {
        winopts = {
          height = 0.85;
          width = 0.80;
          preview = {
            layout = "flex";
            flip_columns = 120;
          };
        };
        files = {
          prompt = "Files❯ ";
          multiprocess = true;
          git_icons = true;
          file_icons = true;
          color_icons = true;
        };
        grep = {
          prompt = "Rg❯ ";
          input_prompt = "Grep For❯ ";
          multiprocess = true;
          git_icons = false;
          file_icons = true;
          color_icons = true;
          rg_opts = "--column --line-number --no-heading --color=always --smart-case --max-columns=4096 -e";
        };
        buffers = {
          prompt = "Buffers❯ ";
          file_icons = true;
          color_icons = true;
          sort_lastused = true;
        };
      };
    };

    # Additional keymaps for fzf-lua (custom functions)
    keymaps = [
      # Search in current buffer
      {
        mode = "n";
        key = "<leader>/";
        action.__raw = ''
          function()
            require('fzf-lua').blines()
          end
        '';
        options = {
          desc = "[/] Fuzzily search in current buffer";
        };
      }
      # Search in open files
      {
        mode = "n";
        key = "<leader>s/";
        action.__raw = ''
          function()
            require('fzf-lua').live_grep({ grep_open_files = true })
          end
        '';
        options = {
          desc = "[S]earch [/] in Open Files";
        };
      }
      # Search Neovim config files
      {
        mode = "n";
        key = "<leader>sn";
        action.__raw = ''
          function()
            require('fzf-lua').files({ cwd = vim.fn.stdpath('config') })
          end
        '';
        options = {
          desc = "[S]earch [N]eovim files";
        };
      }
    ];
  };
}
