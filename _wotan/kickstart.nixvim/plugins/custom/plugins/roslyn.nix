{pkgs, ...}: {
  programs.nixvim = {
    # Roslyn.nvim - C#/.NET language server using Microsoft's Roslyn
    # https://github.com/seblj/roslyn.nvim
    plugins.roslyn = {
      enable = true;
    };

    # rzls.nvim - Razor Language Server support for Neovim
    # https://github.com/tris203/rzls.nvim
    # Requires roslyn plugin to be enabled
    plugins.rzls = {
      enable = true;
      # Automatically associate .razor files with razor filetype
      enableRazorFiletypeAssociation = true;
    };
  };
}
