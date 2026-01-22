{pkgs, ...}: {
  programs.nixvim = {
    # NvChad's nvim-colorizer.lua (maintained fork)
    extraPlugins = with pkgs.vimPlugins; [
      nvim-colorizer-lua
    ];

    extraConfigLua = ''
      require('colorizer').setup({
        filetypes = {
          '*', -- Highlight all files
          '!lazy', -- Exclude lazy.nvim
        },
        user_default_options = {
          RGB = true, -- #RGB hex codes
          RRGGBB = true, -- #RRGGBB hex codes
          names = true, -- "Name" codes like Blue or red
          RRGGBBAA = true, -- #RRGGBBAA hex codes
          AARRGGBB = true, -- 0xAARRGGBB hex codes
          rgb_fn = true, -- CSS rgb() and rgba() functions
          hsl_fn = true, -- CSS hsl() and hsla() functions
          css = true, -- Enable all CSS features: rgb_fn, hsl_fn, names, RGB, RRGGBB
          css_fn = true, -- Enable all CSS *functions*: rgb_fn, hsl_fn
          -- Available modes for `mode`: foreground, background,  virtualtext
          mode = "background", -- Set the display mode
          -- Available methods are false / "normal" / "lsp" / "both"
          tailwind = true, -- Enable tailwind colors
          sass = { enable = true, parsers = { "css" } }, -- Enable sass colors
          virtualtext = "■",
          always_update = false,
        },
        buftypes = {},
      })
    '';
  };
}
