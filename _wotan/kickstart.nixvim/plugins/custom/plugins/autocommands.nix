{
  programs.nixvim.autoCmd = [
    # Vertically center document when entering insert mode
    {
      event = "InsertEnter";
      command = "norm zz";
    }

    # Open help in a vertical split
    {
      event = "FileType";
      pattern = "help";
      command = "wincmd L";
    }

    # Enable spellcheck for some filetypes
    {
      event = "FileType";
      pattern = [
        "tex" # inria
        "latex" # inria
        "markdown"
      ];
      command = "setlocal spell spelllang=en";
    }

    # Delete empty unnamed buffers when dashboard opens
    # Only when starting nvim without arguments (not nvim . or nvim <file>)
    {
      event = "FileType";
      pattern = "snacks_dashboard";
      callback.__raw = ''
        function()
          -- Only clean up if we started with no arguments
          if vim.fn.argc() == 0 then
            vim.schedule(function()
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_valid(buf)
                  and vim.api.nvim_buf_get_name(buf) == ""
                  and vim.api.nvim_get_option_value("buftype", { buf = buf }) == ""
                  and vim.api.nvim_buf_line_count(buf) <= 1
                  and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
                then
                  vim.api.nvim_buf_delete(buf, { force = true })
                end
              end
            end)
          end
        end
      '';
    }
  ];
}
