{pkgs, ...}: {
  programs.nixvim = {
    # Disabled in favor of Telescope (fzf had Tab/selection issues)
    plugins.fzf-lua = {
      enable = false;

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
        # Override default action to always open files directly (not quickfix)
        actions = {
          files = {
            # Use file_edit instead of file_edit_or_qf to prevent quickfix on multi-select
            # NOTE: "default" is the internal fzf key for the accept action
            __raw = ''
              {
                ["default"] = require("fzf-lua").actions.file_edit,
                ["ctrl-s"] = require("fzf-lua").actions.file_split,
                ["ctrl-v"] = require("fzf-lua").actions.file_vsplit,
                ["ctrl-t"] = require("fzf-lua").actions.file_tabedit,
                ["alt-q"] = require("fzf-lua").actions.file_sel_to_qf,
                ["alt-Q"] = require("fzf-lua").actions.file_sel_to_ll,
                ["alt-i"] = require("fzf-lua").actions.toggle_ignore,
                ["alt-h"] = require("fzf-lua").actions.toggle_hidden,
                ["alt-f"] = require("fzf-lua").actions.toggle_follow,
              }
            '';
          };
        };
        # fzf binary options
        fzf_opts = {
          # --scheme=path: higher score to matches at the end (filename)
          # --tiebreak: when scores equal, prefer end position and shorter paths
          __raw = ''
            {
              ["--scheme"] = "path",
              ["--tiebreak"] = "end,length",
            }
          '';
        };

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

    # NOTE: Keymaps moved to telescope.nix since fzf-lua is disabled
  };
}
