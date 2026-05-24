{
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;
      settings = {
        add_blank_line_at_top = true;
        auto_clean_after_session_restore = true;
        close_if_last_window = true;
        filesystem = {
          # Let neo-tree open in its configured position when starting with a directory
          hijack_netrw_behavior = "open_default";
          # Watch filesystem for changes and auto-refresh (not just on focus)
          use_libuv_file_watcher = true;
          window = {
            mappings = {
              "\\" = "close_window";
            };
          };
        };
      };
    };

    # Ensure directory startup uses neo-tree without leaving an unnamed buffer
    # This prevents :xa from hitting E141 when starting with `nvim .`
    extraConfigLuaPost = ''
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function(data)
          -- If we started with a directory argument
          if data.file ~= nil and data.file ~= "" and vim.fn.isdirectory(data.file) == 1 then
            -- Close the initial directory buffer so it is not written by :xa
            if data.buf ~= nil and vim.api.nvim_buf_is_valid(data.buf) then
              vim.api.nvim_buf_delete(data.buf, { force = true })
            end

            -- Change into the directory (mirrors netrw behavior); neo-tree will
            -- auto-open via hijack_netrw_behavior = "open_default"
            vim.cmd.cd(data.file)
          end
        end,
        desc = "Use neo-tree on directory startup and remove initial dir buffer",
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
