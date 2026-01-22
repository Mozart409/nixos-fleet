{pkgs, ...}: {
  programs.nixvim = {
    # Add zenburn plugin (disabled)
    # extraPlugins = with pkgs.vimPlugins; [
    #   phha-zenburn
    # ];

    # Enable zenburn colorscheme (disabled)
    # colorschemes.base16 = {
    #   enable = false;
    #   colorscheme = "zenburn";
    # };

    # Configure for warm, retro terminal aesthetic (disabled)
    # extraConfigLua = ''
    #   -- Enable zenburn colorscheme
    #   vim.cmd([[colorscheme zenburn]])
    #
    #   -- Optional: Enhance the retro terminal feel
    #   vim.opt.termguicolors = true
    # '';
  };
}
