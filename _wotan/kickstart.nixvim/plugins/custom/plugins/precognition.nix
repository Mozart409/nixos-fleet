{pkgs, ...}: {
  programs.nixvim = {
    # precognition.nvim is available as an extraPlugin
    extraPlugins = with pkgs.vimPlugins; [
      precognition-nvim
    ];

    # precognition.nvim configuration
    extraConfigLua = ''
      require("precognition").setup({
        -- Start with hints visible
        startVisible = false,

        -- Show blank virtual line
        showBlankVirtLine = true,

        -- Highlight color configuration
        highlightColor = { link = "Comment" },

        -- Horizontal motion hints
        hints = {
          Caret = { text = "^", prio = 2 },
          Dollar = { text = "$", prio = 1 },
          MatchingPair = { text = "%", prio = 5 },
          Zero = { text = "0", prio = 1 },
          w = { text = "w", prio = 10 },
          b = { text = "b", prio = 9 },
          e = { text = "e", prio = 8 },
          W = { text = "W", prio = 7 },
          B = { text = "B", prio = 6 },
          E = { text = "E", prio = 5 },
        },

        -- Vertical motion hints (gutter)
        gutterHints = {
          G = { text = "G", prio = 10 },
          gg = { text = "gg", prio = 9 },
          PrevParagraph = { text = "{", prio = 8 },
          NextParagraph = { text = "}", prio = 8 },
        },

        -- Disabled filetypes
        disabled_fts = {
          "startify",
          "dashboard",
          "alpha",
          "neo-tree",
          "Trouble",
          "trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
          "lazyterm",
        },
      })
    '';

    # Optional keymaps for toggling precognition
    keymaps = [
      {
        mode = "n";
        key = "<leader>tp";
        action.__raw = ''
          function()
            if require("precognition").toggle() then
              vim.notify("Precognition ON")
            else
              vim.notify("Precognition OFF")
            end
          end
        '';
        options = {
          desc = "[T]oggle [P]recognition";
        };
      }
      {
        mode = "n";
        key = "<leader>up";
        action.__raw = ''
          function()
            require("precognition").peek()
          end
        '';
        options = {
          desc = "Precognition Peek";
        };
      }
    ];
  };
}
