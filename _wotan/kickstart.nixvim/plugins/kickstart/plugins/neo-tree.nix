{
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;
      settings = {
        add_blank_line_at_top = true;
        auto_clean_after_session_restore = true;
        close_if_last_window = true;
        filesystem = {
          # Open in current window when running nvim . to avoid empty buffer
          hijack_netrw_behavior = "open_current";
          window = {
            mappings = {
              "\\" = "close_window";
            };
          };
        };
      };
    };

    # Use extraConfigLuaPost to set up autocmd that marks directory buffers as scratch
    # This fixes E141 "No file name for buffer" error when using :xa after nvim .
    extraConfigLuaPost = ''
      -- When opening a directory, Neovim creates a buffer for it before neo-tree hijacks.
      -- This buffer becomes orphaned and causes E141 on :xa. Mark it as scratch immediately.
      vim.api.nvim_create_autocmd("BufAdd", {
        callback = function(args)
          local bufnr = args.buf
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          -- Check if this buffer is for a directory
          if bufname ~= "" and vim.fn.isdirectory(bufname) == 1 then
            vim.bo[bufnr].buftype = "nofile"
            vim.bo[bufnr].bufhidden = "wipe"
            vim.bo[bufnr].swapfile = false
          end
        end,
        desc = "Mark directory buffers as scratch for neo-tree hijack",
      })
    '';

    # https://nix-community.github.io/nixvim/keymaps/index.html

    keymaps = [
      {
        key = "<leader>fe";
        action = "<cmd>Neotree reveal<cr>";
        options = {
          desc = "NeoTree reveal";
        };
      }
    ];
  };
}
