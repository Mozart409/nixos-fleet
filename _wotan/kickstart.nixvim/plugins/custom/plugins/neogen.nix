{pkgs, ...}: {
  programs.nixvim.plugins.neogen = {
    enable = true;

    settings = {
      # Snippet engine
      snippet_engine = "luasnip";

      # Enable all languages
      enabled_languages = {};

      # Input after generating annotation
      input_after_comment = true;

      # Language-specific settings
      languages = {
        python = {
          template = {
            annotation_convention = "numpydoc";
          };
        };

        typescript = {
          template = {
            annotation_convention = "tsdoc";
          };
        };

        javascript = {
          template = {
            annotation_convention = "jsdoc";
          };
        };

        rust = {
          template = {
            annotation_convention = "rustdoc";
          };
        };

        lua = {
          template = {
            annotation_convention = "ldoc";
          };
        };
      };
    };
  };

  # Keymaps for generating documentation
  programs.nixvim.keymaps = [
    {
      mode = "n";
      key = "<leader>nf";
      action.__raw = ''
        function()
          require('neogen').generate({ type = 'func' })
        end
      '';
      options = {
        desc = "[N]eogen: Generate [F]unction doc";
      };
    }
    {
      mode = "n";
      key = "<leader>nc";
      action.__raw = ''
        function()
          require('neogen').generate({ type = 'class' })
        end
      '';
      options = {
        desc = "[N]eogen: Generate [C]lass doc";
      };
    }
    {
      mode = "n";
      key = "<leader>nt";
      action.__raw = ''
        function()
          require('neogen').generate({ type = 'type' })
        end
      '';
      options = {
        desc = "[N]eogen: Generate [T]ype doc";
      };
    }
    {
      mode = "n";
      key = "<leader>ng";
      action.__raw = ''
        function()
          require('neogen').generate()
        end
      '';
      options = {
        desc = "[N]eogen: [G]enerate doc (auto-detect)";
      };
    }
  ];
}
