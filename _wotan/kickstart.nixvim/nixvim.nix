{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # NOTE: The first thing you will want to do is uncommented on of the three imports below
    # depending on which module you chose to use to install Nixvim.
    #
    # Uncomment if you are using the home-manager module
    #    inputs.nixvim.homeManagerModules.nixvim
    #    Uncomment if you are using the nixos module
    #    inputs.nixvim.nixosModules.nixvim
    # Uncomment if you are using the nix-darwin module
    #inputs.nixvim.nixDarwinModules.nixvim

    # Plugins
    ./plugins/gitsigns.nix
    ./plugins/which-key.nix
    ./plugins/telescope.nix
    ./plugins/conform.nix
    ./plugins/lsp.nix
    ./plugins/nvim-cmp.nix
    ./plugins/mini.nix
    ./plugins/treesitter.nix

    # NOTE: Add/Configure additional plugins for Kickstart.nixvim
    #
    #  Here are some example plugins that I've included in the Kickstart repository.
    #  Uncomment any of the lines below to enable them (you will need to restart nvim).
    #
    ./plugins/kickstart/plugins/indent-blankline.nix
    ./plugins/kickstart/plugins/lint.nix
    ./plugins/kickstart/plugins/autopairs.nix
    ./plugins/kickstart/plugins/neo-tree.nix
    #
    # NOTE: Configure your own plugins `see https://nix-community.github.io/nixvim/`
    # Add your plugins to ./plugins/custom/plugins and import them below
    # Quick wins
    ./plugins/custom/plugins/todo-comments.nix
    ./plugins/custom/plugins/nvim-colorizer.nix
    ./plugins/custom/plugins/dressing.nix
    ./plugins/custom/plugins/inc-rename.nix
    # Code navigation
    ./plugins/custom/plugins/aerial.nix
    ./plugins/custom/plugins/nvim-navic.nix
    # Documentation
    ./plugins/custom/plugins/neogen.nix
    # Other plugins
    ./plugins/custom/plugins/fzf-lua.nix
    ./plugins/custom/plugins/nvim-bqf.nix
    #./plugins/custom/plugins/nvim-lightbulb.nix
    ./plugins/custom/plugins/precognition.nix
    ./plugins/custom/plugins/cyberdream.nix
    ./plugins/custom/plugins/zenburn.nix
    ./plugins/custom/plugins/vague.nix
    ./plugins/custom/plugins/oil.nix
    ./plugins/custom/plugins/opencode.nix
    # ./plugins/custom/plugins/snacks.nix
    ./plugins/custom/plugins/autocommands.nix
    ./plugins/custom/plugins/trouble.nix
    ./plugins/custom/plugins/dashboard.nix
    ./plugins/custom/plugins/drop.nix
    ./plugins/custom/plugins/comment.nix
    ./plugins/custom/plugins/noice.nix
    ./plugins/custom/plugins/neogit.nix
    ./plugins/custom/plugins/neoscroll.nix
    #./plugins/custom/plugins/fff.nix
    ./plugins/custom/plugins/typescript-tools.nix
    ./plugins/custom/plugins/roslyn.nix
    ./plugins/custom/plugins/spectre.nix
    ./plugins/custom/plugins/flash.nix
    # ./plugins/custom/plugins/schemastore.nix
    # ./plugins/custom/plugins/zk.nix
  ];

  /*
  =====================================================================
  ==================== READ THIS BEFORE CONTINUING ====================
  =====================================================================
  ========                                    .-----.          ========
  ========         .----------------------.   | === |          ========
  ========         |.-""""""""""""""""""-.|   |-----|          ========
  ========         ||                    ||   | === |          ========
  ========         ||  KICKSTART.NIXVIM  ||   |-----|          ========
  ========         ||                    ||   | === |          ========
  ========         ||                    ||   |-----|          ========
  ========         ||:Tutor              ||   |:::::|          ========
  ========         |'-..................-'|   |____o|          ========
  ========         `"")----------------(""`   ___________      ========
  ========        /::::::::::|  |::::::::::\  \ no mouse \     ========
  ========       /:::========|  |==hjkl==:::\  \ required \    ========
  ========      '""""""""""""'  '""""""""""""'  '""""""""""'   ========
  ========                                                     ========
  =====================================================================
  =====================================================================
  */
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    performance.byteCompileLua.enable = true;
    extraPlugins = with pkgs.vimPlugins; [
      # Useful for getting pretty icons, but requires a Nerd Font.
      plenary-nvim
      nvim-web-devicons
      vim-devicons
    ];

    # Cyberdream theme is configured in ./plugins/custom/plugins/cyberdream.nix
    # The colorscheme is enabled there via colorschemes.cyberdream.enable = true;

    # https://nix-community.github.io/nixvim/NeovimOptions/index.html?highlight=globals#globals
    globals = {
      # Set <space> as the leader key
      # See `:help mapleader`
      mapleader = " ";
      maplocalleader = " ";

      # Set to true if you have a Nerd Font installed and selected in the terminal
      have_nerd_font = true;
    };

    #  See `:help 'clipboard'`
    clipboard = {
      providers = {
        wl-copy.enable = true; # For Wayland
        xsel.enable = true; # For X11
      };

      # Sync clipboard between OS and Neovim
      #  Remove this option if you want your OS clipboard to remain independent.
      register = "unnamedplus";
    };

    # [[ Setting options ]]
    # See `:help vim.opt`
    # NOTE: You can change these options as you wish!
    #  For more options, you can see `:help option-list`
    # https://nix-community.github.io/nixvim/NeovimOptions/index.html?highlight=globals#opts
    opts = {
      # Show line numbers
      number = true;
      # You can also add relative line numbers, to help with jumping.
      #  Experiment for yourself to see if you like it!
      relativenumber = true;

      # Enable mouse mode, can be useful for resizing splits for example!
      mouse = "a";

      # Don't show the mode, since it's already in the statusline
      showmode = false;

      # Enable break indent
      breakindent = true;

      # Save undo history
      undofile = true;

      # Case-insensitive searching UNLESS \C or one or more capital letters in search term
      ignorecase = true;
      smartcase = true;

      # Keep signcolumn on by default
      signcolumn = "yes";

      # Decrease update time
      updatetime = 250;

      # Decrease mapped sequence wait time
      # Displays which-key popup sooner
      timeoutlen = 300;

      # Configure how new splits should be opened
      splitright = true;
      splitbelow = true;

      # Sets how neovim will display certain whitespace characters in the editor
      #  See `:help 'list'`
      #  See `:help 'listchars'`
      list = true;
      # NOTE: .__raw here means that this field is raw lua code
      listchars.__raw = "{ tab = '» ', trail = '·', nbsp = '␣' }";

      # Preview subsitutions live, as you type!
      inccommand = "split";

      # Show which line your cursor is on
      cursorline = true;

      # Minimal number of screen lines to keep above and below the cursor
      scrolloff = 10;

      # See `:help hlsearch`
      hlsearch = true;

      expandtab = true;
      shiftwidth = 2;
      smartindent = true;
      tabstop = 2;

      # Required for nvim-colorizer and proper color support
      termguicolors = true;
    };

    # [[ Basic Keymaps ]]
    #  See `:help vim.keymap.set()`
    # https://nix-community.github.io/nixvim/keymaps/index.html
    keymaps = [
      # Keymaps for custom plugin trouble
      {
        mode = "";
        key = "<leader>xx";
        action = "<cmd>Trouble diagnostics toggle<cr>";
        # action.__raw = ''
        #   function()
        #     require('Trouble').format { async = true, lsp_fallback = true }
        #   end
        # '';
        options = {
          desc = "Diagnostics (Trouble)";
        };
      }
      {
        mode = "";
        key = "<leader>xX";
        action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>";
        options = {
          desc = "Buffer Diagnostics (Trouble)";
        };
      }
      {
        mode = "";
        key = "<leader>cs";
        action = "<cmd>Trouble symbols toggle focus=false<cr>";
        options = {
          desc = "Symbols (Trouble)";
        };
      }
      {
        mode = "";
        key = "<leader>xL";
        action = "<cmd>Trouble loclist toggle<cr>";
        options = {
          desc = "Location List(Trouble)";
        };
      }
      {
        mode = "";
        key = "<leader>xQ";
        action = "<cmd>Trouble qflist toggle<cr>";
        options = {
          desc = "Quickfix List(Trouble)";
        };
      }

      # Clear highlights on search when pressing <Esc> in normal mode
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<CR>";
      }

      {
        mode = "n";
        key = "<leader>tt";
        action = "<cmd>Neogit<cr>";
        options = {
          desc = "Neogit";
        };
      }

      # Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
      # for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
      # is not what someone will guess without a bit more experience.
      #
      # NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
      # or just use <C-\><C-n> to exit terminal mode
      {
        mode = "t";
        key = "<Esc><Esc>";
        action = "<C-\\><C-n>";
        options = {
          desc = "Exit terminal mode";
        };
      }
      # TIP: Disable arrow keys in normal mode
      /*
      {
        mode = "n";
        key = "<left>";
        action = "<cmd>echo 'Use h to move!!'<CR>";
      }
      {
        mode = "n";
        key = "<right>";
        action = "<cmd>echo 'Use l to move!!'<CR>";
      }
      {
        mode = "n";
        key = "<up>";
        action = "<cmd>echo 'Use k to move!!'<CR>";
      }
      {
        mode = "n";
        key = "<down>";
        action = "<cmd>echo 'Use j to move!!'<CR>";
      }
      */
      # Keybinds to make split navigation easier.
      #  Use CTRL+<hjkl> to switch between windows
      #
      #  See `:help wincmd` for a list of all window commands
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w><C-h>";
        options = {
          desc = "Move focus to the left window";
        };
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w><C-l>";
        options = {
          desc = "Move focus to the right window";
        };
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w><C-j>";
        options = {
          desc = "Move focus to the lower window";
        };
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w><C-k>";
        options = {
          desc = "Move focus to the upper window";
        };
      }
      {
        key = "<leader>gg";
        mode = "n";
        action = "<cmd>Neogit<cr>";
        options = {
          desc = "Open Neogit";
        };
      }
      {
        key = "<leader>S";
        mode = "n";
        action = ''
          <cmd>lua require("spectre").open_visual({select_word=true})<CR>
        '';
        options = {
          desc = "Open Spectre";
        };
      }
      /*
         {
        key = "<leader>fe";
        mode = "n";
        action = "<cmd>lua require('snacks').reveal()<CR>";
        options = {
          desc = "Snacks File Explorer";
        };
      }
      */
    ];

    # https://nix-community.github.io/nixvim/NeovimOptions/autoGroups/index.html
    autoGroups = {
      kickstart-highlight-yank = {
        clear = true;
      };
    };

    # [[ Basic Autocommands ]]
    #  See `:help lua-guide-autocommands`
    # https://nix-community.github.io/nixvim/NeovimOptions/autoCmd/index.html
    autoCmd = [
      # Highlight when yanking (copying) text
      #  Try it with `yap` in normal mode
      #  See `:help vim.highlight.on_yank()`
      {
        event = ["TextYankPost"];
        desc = "Highlight when yanking (copying) text";
        group = "kickstart-highlight-yank";
        callback.__raw = ''
          function()
            vim.highlight.on_yank()
          end
        '';
      }
    ];

    plugins = {
      # Adds icons for plugins to utilize in ui
      better-escape.enable = false;
      web-devicons.enable = true;
      # Detect tabstop and shiftwidth automatically
      # https://nix-community.github.io/nixvim/plugins/sleuth/index.html
      sleuth = {
        enable = true;
      };

      # Highlight todo, notes, etc in comments
      # https://nix-community.github.io/nixvim/plugins/todo-comments/index.html
      todo-comments = {
        settings = {
          enable = true;
          signs = true;
        };
      };
    };

    # TODO: Figure out where to move this
    # https://nix-community.github.io/nixvim/NeovimOptions/index.html?highlight=extraplugins#extraconfigluapre
    extraConfigLuaPre = ''
      if vim.g.have_nerd_font then
        require('nvim-web-devicons').setup {}
      end
    '';

    # The line beneath this is called `modeline`. See `:help modeline`
    # https://nix-community.github.io/nixvim/NeovimOptions/index.html?highlight=extraplugins#extraconfigluapost
    extraConfigLuaPost = ''
      -- vim: ts=2 sts=2 sw=2 et
    '';
  };
}
