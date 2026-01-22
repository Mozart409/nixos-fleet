{pkgs, ...}: {
  programs.nixvim = {
    # nvim-lightbulb is available in nixvim as an extraPlugin
    extraPlugins = with pkgs.vimPlugins; [
      nvim-lightbulb
    ];

    # nvim-lightbulb configuration
    extraConfigLua = ''
      require("nvim-lightbulb").setup({
        -- Priority of the lightbulb for all handlers except float
        priority = 10,

        -- Hide lightbulb when buffer is not focused
        hide_in_unfocused_buffer = true,

        -- Link highlight groups automatically
        link_highlights = true,

        -- Validation config
        validate_config = "auto",

        -- Code action kinds to observe (nil = all)
        action_kinds = nil,

        -- Handlers configuration
        sign = {
          enabled = true,
          text = "💡",
          hl = "LightBulbSign",
        },

        virtual_text = {
          enabled = false,
          text = "💡",
          pos = "eol",
          hl = "LightBulbVirtualText",
          hl_mode = "combine",
        },

        float = {
          enabled = false,
          text = "💡",
          hl = "LightBulbFloatWin",
          win_opts = {
            focusable = false,
          },
        },

        status_text = {
          enabled = false,
          text = "💡",
          text_unavailable = "",
        },

        number = {
          enabled = false,
          hl = "LightBulbNumber",
        },

        line = {
          enabled = false,
          hl = "LightBulbLine",
        },

        -- Autocmd configuration
        autocmd = {
          enabled = true,
          updatetime = 200,
          events = { "CursorHold", "CursorHoldI" },
          pattern = { "*" },
        },

        -- Ignore configuration
        ignore = {
          clients = {},
          ft = {},
          actions_without_kind = false,
        },
      })
    '';
  };
}
