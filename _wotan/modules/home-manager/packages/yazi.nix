{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    settings = {
      mgr = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        show_symlink = true;
      };

      preview = {
        # Use kitty graphics protocol when in kitty terminal
        # Falls back to ueberzugpp for other terminals like alacritty
        max_width = 1920;
        max_height = 1080;
        image_quality = 90;
      };
    };

    # Keybindings - yazi uses vim-like keys by default
    keymap = {
      mgr.keymap = [
        {
          on = ["<Esc>"];
          run = "escape";
          desc = "Exit visual mode, clear selected, or cancel search";
        }
        {
          on = ["q"];
          run = "quit";
          desc = "Quit yazi";
        }
        {
          on = ["Q"];
          run = "quit --no-cwd-file";
          desc = "Quit without changing directory";
        }
        {
          on = ["<C-q>"];
          run = "close";
          desc = "Close current tab";
        }

        # Navigation
        {
          on = ["k"];
          run = "arrow -1";
          desc = "Move up";
        }
        {
          on = ["j"];
          run = "arrow 1";
          desc = "Move down";
        }
        {
          on = ["h"];
          run = "leave";
          desc = "Go to parent directory";
        }
        {
          on = ["l"];
          run = "enter";
          desc = "Enter directory";
        }
        {
          on = ["<Up>"];
          run = "arrow -1";
        }
        {
          on = ["<Down>"];
          run = "arrow 1";
        }
        {
          on = ["<Left>"];
          run = "leave";
        }
        {
          on = ["<Right>"];
          run = "enter";
        }

        # Quick jumps
        {
          on = ["g" "g"];
          run = "arrow -99999999";
          desc = "Jump to top";
        }
        {
          on = ["G"];
          run = "arrow 99999999";
          desc = "Jump to bottom";
        }
        {
          on = ["g" "h"];
          run = "cd ~";
          desc = "Go home";
        }
        {
          on = ["g" "c"];
          run = "cd ~/code";
          desc = "Go to code directory";
        }
        {
          on = ["g" "d"];
          run = "cd ~/Downloads";
          desc = "Go to Downloads";
        }
        {
          on = ["g" "n"];
          run = "cd /etc/nixos";
          desc = "Go to NixOS config";
        }

        # Selection
        {
          on = ["<Space>"];
          run = ["select --state=none" "arrow 1"];
          desc = "Toggle selection";
        }
        {
          on = ["v"];
          run = "visual_mode";
          desc = "Enter visual mode";
        }
        {
          on = ["V"];
          run = "visual_mode --unset";
          desc = "Enter visual mode (unset)";
        }
        {
          on = ["<C-a>"];
          run = "select_all --state=true";
          desc = "Select all";
        }
        {
          on = ["<C-r>"];
          run = "select_all --state=none";
          desc = "Invert selection";
        }

        # File operations
        {
          on = ["o"];
          run = "open";
          desc = "Open file";
        }
        {
          on = ["O"];
          run = "open --interactive";
          desc = "Open interactively";
        }
        {
          on = ["<Enter>"];
          run = "open";
          desc = "Open file";
        }
        {
          on = ["y"];
          run = "yank";
          desc = "Yank (copy)";
        }
        {
          on = ["x"];
          run = "yank --cut";
          desc = "Cut";
        }
        {
          on = ["p"];
          run = "paste";
          desc = "Paste";
        }
        {
          on = ["P"];
          run = "paste --force";
          desc = "Paste (overwrite)";
        }
        {
          on = ["-"];
          run = "link";
          desc = "Symlink (absolute)";
        }
        {
          on = ["_"];
          run = "link --relative";
          desc = "Symlink (relative)";
        }
        {
          on = ["d"];
          run = "remove";
          desc = "Move to trash";
        }
        {
          on = ["D"];
          run = "remove --permanently";
          desc = "Delete permanently";
        }
        {
          on = ["a"];
          run = "create";
          desc = "Create file/directory";
        }
        {
          on = ["r"];
          run = "rename --cursor=before_ext";
          desc = "Rename";
        }
        {
          on = ["."];
          run = "hidden toggle";
          desc = "Toggle hidden files";
        }

        # Search
        {
          on = ["/"];
          run = "search fd";
          desc = "Search with fd";
        }
        {
          on = ["?"];
          run = "search rg";
          desc = "Search with ripgrep";
        }
        {
          on = ["n"];
          run = "search_next";
          desc = "Next search result";
        }
        {
          on = ["N"];
          run = "search_prev";
          desc = "Previous search result";
        }

        # Tabs
        {
          on = ["t"];
          run = "tab_create --current";
          desc = "Create new tab";
        }
        {
          on = ["1"];
          run = "tab_switch 0";
          desc = "Switch to tab 1";
        }
        {
          on = ["2"];
          run = "tab_switch 1";
          desc = "Switch to tab 2";
        }
        {
          on = ["3"];
          run = "tab_switch 2";
          desc = "Switch to tab 3";
        }
        {
          on = ["["];
          run = "tab_switch -1 --relative";
          desc = "Previous tab";
        }
        {
          on = ["]"];
          run = "tab_switch 1 --relative";
          desc = "Next tab";
        }

        # Sorting
        {
          on = ["," "m"];
          run = "sort modified --reverse=no";
          desc = "Sort by modified time";
        }
        {
          on = ["," "M"];
          run = "sort modified --reverse";
          desc = "Sort by modified (reverse)";
        }
        {
          on = ["," "n"];
          run = "sort natural --reverse=no";
          desc = "Sort naturally";
        }
        {
          on = ["," "N"];
          run = "sort natural --reverse";
          desc = "Sort naturally (reverse)";
        }
        {
          on = ["," "s"];
          run = "sort size --reverse=no";
          desc = "Sort by size";
        }
        {
          on = ["," "S"];
          run = "sort size --reverse";
          desc = "Sort by size (reverse)";
        }

        # Preview
        {
          on = ["z"];
          run = "plugin zoxide";
          desc = "Jump with zoxide";
        }
        {
          on = ["Z"];
          run = "plugin fzf";
          desc = "Jump with fzf";
        }

        # Copy path
        {
          on = ["c" "c"];
          run = "copy path";
          desc = "Copy path";
        }
        {
          on = ["c" "d"];
          run = "copy dirname";
          desc = "Copy directory path";
        }
        {
          on = ["c" "f"];
          run = "copy filename";
          desc = "Copy filename";
        }
        {
          on = ["c" "n"];
          run = "copy name_without_ext";
          desc = "Copy filename without extension";
        }

        # Help
        {
          on = ["~"];
          run = "help";
          desc = "Open help";
        }
      ];
    };

    # Theme - matching kanagawa style
    theme = {
      mgr = {
        cwd = {fg = "#7E9CD8";};

        find_keyword = {
          fg = "#E6C384";
          bold = true;
        };
        find_position = {
          fg = "#C8C093";
          bg = "reset";
        };

        marker_selected = {
          fg = "#98BB6C";
          bg = "#98BB6C";
        };
        marker_copied = {
          fg = "#E6C384";
          bg = "#E6C384";
        };
        marker_cut = {
          fg = "#FF5D62";
          bg = "#FF5D62";
        };

        border_symbol = "│";
        border_style = {fg = "#54546D";};
      };

      tabs = {
        active = {
          fg = "#1F1F28";
          bg = "#7E9CD8";
        };
        inactive = {
          fg = "#DCD7BA";
          bg = "#2A2A37";
        };
      };

      mode = {
        normal_main = {
          fg = "#1F1F28";
          bg = "#7E9CD8";
          bold = true;
        };
        normal_alt = {
          fg = "#7E9CD8";
          bg = "#2A2A37";
        };
        select_main = {
          fg = "#1F1F28";
          bg = "#98BB6C";
          bold = true;
        };
        select_alt = {
          fg = "#98BB6C";
          bg = "#2A2A37";
        };
        unset_main = {
          fg = "#1F1F28";
          bg = "#FF5D62";
          bold = true;
        };
        unset_alt = {
          fg = "#FF5D62";
          bg = "#2A2A37";
        };
      };

      status = {
        progress_label = {
          fg = "#DCD7BA";
          bold = true;
        };
        progress_normal = {
          fg = "#7E9CD8";
          bg = "#2A2A37";
        };
        progress_error = {
          fg = "#FF5D62";
          bg = "#2A2A37";
        };

        perm_type = {fg = "#7E9CD8";};
        perm_read = {fg = "#E6C384";};
        perm_write = {fg = "#FF5D62";};
        perm_exec = {fg = "#98BB6C";};
        perm_sep = {fg = "#54546D";};
      };

      input = {
        border = {fg = "#7E9CD8";};
        title = {};
        value = {};
        selected = {reversed = true;};
      };

      pick = {
        border = {fg = "#7E9CD8";};
        active = {fg = "#E6C384";};
        inactive = {};
      };

      tasks = {
        border = {fg = "#7E9CD8";};
        title = {};
        hovered = {underline = true;};
      };

      which = {
        mask = {bg = "#1F1F28";};
        cand = {fg = "#7AA89F";};
        rest = {fg = "#54546D";};
        desc = {fg = "#C8C093";};
        separator = "  ";
        separator_style = {fg = "#54546D";};
      };

      help = {
        on = {fg = "#E6C384";};
        run = {fg = "#C8C093";};
        desc = {};
        hovered = {
          bg = "#2A2A37";
          bold = true;
        };
        footer = {
          fg = "#1F1F28";
          bg = "#DCD7BA";
        };
      };

      filetype = {
        rules = [
          {
            mime = "image/*";
            fg = "#E6C384";
          }
          {
            mime = "video/*";
            fg = "#957FB8";
          }
          {
            mime = "audio/*";
            fg = "#7AA89F";
          }
          {
            mime = "application/zip";
            fg = "#FF5D62";
          }
          {
            mime = "application/gzip";
            fg = "#FF5D62";
          }
          {
            mime = "application/x-tar";
            fg = "#FF5D62";
          }
          {
            mime = "application/x-bzip2";
            fg = "#FF5D62";
          }
          {
            mime = "application/x-7z-compressed";
            fg = "#FF5D62";
          }
          {
            mime = "application/x-rar";
            fg = "#FF5D62";
          }
          {
            url = "*";
            fg = "#DCD7BA";
          }
          {
            url = "*/";
            fg = "#7E9CD8";
          }
        ];
      };
    };
  };

  # Install ueberzugpp for image previews in terminals without native support (like Alacritty)
  home.packages = with pkgs; [
    ueberzugpp
    # Additional tools yazi can use
    # keep-sorted start
    fd # Fast file finder
    ffmpegthumbnailer # Video thumbnails
    fzf # Fuzzy finder
    jq # JSON preview
    p7zip # Archive preview
    poppler # PDF previews
    ripgrep # Fast text search
    unzip # Archive preview
    zoxide # Smart directory jumping
    # keep-sorted end
  ];
}
