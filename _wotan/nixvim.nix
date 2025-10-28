{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      stylua
      dprint
      ruff
      fixjson
      rustfmt
      yamlfmt
      alejandra
      d2
      vimPlugins.lazygit-nvim
      vimPlugins.ollama-nvim
      vimPlugins.plenary-nvim
      vimPlugins.elixir-tools-nvim
      beam27Packages.elixir-ls
    ];
    enable = true;

    /*
       extraConfigLua = ''
      require("telescope").load_extension("lazygit-nvim")
    '';
    */

    colorschemes.catppuccin.enable = false;
    colorschemes.kanagawa.enable = true;

    # Settings
    opts = {
      expandtab = true;
      shiftwidth = 2;
      smartindent = true;
      tabstop = 2;
      number = true;
      relativenumber = true;
      clipboard = "unnamedplus";
      # Always show the signcolumn, otherwise text would be shifted when displaying error icons
      signcolumn = "yes";
    };

    # Keymaps
    globals = {
      mapleader = " ";
    };

    plugins = {
      # UI
      web-devicons.enable = true;
      lualine.enable = true;
      bufferline.enable = false;
      treesitter.enable = true;
      emmet.enable = true;
      image.enable = true;
      diffview.enable = true;
      comment.enable = true;
      spectre.enable = true;
      nvim-autopairs.enable = true;
      dashboard.enable = false;
      gitsigns.enable = true;
      notify.enable = true;
      which-key = {
        enable = true;
      };
      lspkind = {
        enable = true;
      };
      cmp = {
        autoEnableSources = true;
        settings.sources = [
          {name = "nvim_lsp";}
          {name = "path";}
          {name = "buffer";}
        ];
      };

      conform-nvim = {
        enable = true;
        settings = {
          notify_on_error = false;
          format_on_save = ''
            function(bufnr)
              -- Disable "format_on_save lsp_fallback" for lanuages that don't
              -- have a well standardized coding style. You can add additional
              -- lanuages here or re-enable it for the disabled ones.
              local disable_filetypes = { c = true, cpp = true }
              return {
                timeout_ms = 250,
                lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype]
              }
            end
          '';
          formatters_by_ft = {
            lua = ["stylua"];
            d2 = ["d2"];
            python = ["ruff"];
            json = ["fixjson"];
            javascript = [
              "dprint"
            ];
            typescript = ["dprint"];
            yaml = ["yamlfmt"];
            go = ["goimports" "gofmt"];
            nix = ["alejandra"];
            " " = ["trim_whitespace"];
          };

          keymaps = [
            {
              mode = "";
              key = "<leader>S";
              action = "<cmd>lua require('spectre').toggle()<CR>";
              options = {
                desc = "[S] to toggle Spectre";
              };
            }
            {
              mode = "";
              key = "<leader>sw";
              action = "<cmd>lua require('spectre').open_visual({select_word=true})<CR>";
              options = {
                desc = "[SW] Select word for Spectre";
              };
            }
            {
              mode = "";
              key = "<leader>m";
              action = ''
                function()
                  require('conform').format { async = true, lsp_fallback = true }
                end
              '';
              options = {
                desc = "[M] to Format buffer";
              };
            }
            {
              mode = "";
              key = "ff";
              action = ''
                function()
                  require('fff').find_files()
                end
              '';
              options = {
                desc = "[f] to fuzzy find files";
              };
            }
          ];
        };
      };

      mini = {
        enable = true;
        modules = {
          icons = {
            enable = true;
          };
        };
      };

      neo-tree = {
        enable = true;
        autoCleanAfterSessionRestore = true;
        closeIfLastWindow = true;
      };
      noice = {
        enable = false;
        settings.presets = {
          bottom_search = true;
          command_palette = true;
          long_message_to_split = true;
          #inc_rename = false;
          #lsp_doc_border = false;
        };
      };
      telescope = {
        enable = true;
        keymaps = {
          "<leader>sf" = {
            options.desc = "file finder";
            action = "find_files";
          };
          "<leader>sg" = {
            options.desc = "find via grep";
            action = "live_grep";
          };
          "<leader><space>" = {
            options.desc = "[ ] Find existing buffers";
            action = "buffers";
          };

          /*
             "<leader>/" = {
            options.desc = "[/] Fuzzily search in current buffer";

            action = ''
              function()
                require('telescope.builtin').current_buffer_fuzzy_find(
                  require('telescope.themes').get_dropdown {
                    winblend = 10,
                    previewer = false
                  }
                )
              end
            '';
          };
          */
          /*
          "<leader>s/" = {
            options.desc = "[S]earch [/] Fuzzily in open files";

            action = ''
              function()
              require('telescope.builtin').live_grep {
              grep_open_files = true,
              prompt_title = 'Live Grep in Open Files'
                }
              end
            '';
          };
          */
        };
        extensions = {
          file-browser.enable = true;
        };
      };

      # Dev
      lsp.servers = {
        "*" = {
          settings = {
            capabilities = {
              textDocument = {
                semanticTokens = {
                  multilineTokenSupport = true;
                };
              };
            };
            root_markers = [
              ".git"
            ];
          };
        };
      };
    };
  };
}
