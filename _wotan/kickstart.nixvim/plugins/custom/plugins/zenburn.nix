{pkgs, ...}: {
  programs.nixvim = {
    # Add zenburn plugin
    extraPlugins = with pkgs.vimPlugins; [
      phha-zenburn
    ];

    # Enable zenburn colorscheme
    colorschemes.base16 = {
      enable = true;
      colorscheme = "zenburn";
    };

    # Configure for warm, retro terminal aesthetic
    extraConfigLua = ''
      -- Enable zenburn colorscheme
      vim.cmd([[colorscheme zenburn]])

      -- Optional: Enhance the retro terminal feel
      vim.opt.termguicolors = true
    '';
  };
}
