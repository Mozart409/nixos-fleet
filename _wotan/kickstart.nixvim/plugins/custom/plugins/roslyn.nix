{pkgs, ...}: {
  programs.nixvim = {
    # Roslyn.nvim - C#/.NET language server using Microsoft's Roslyn
    # https://github.com/seblyng/roslyn.nvim
    # NOTE: Razor/CSHTML support is now built-in via co-hosting (rzls.nvim is deprecated)
    plugins.roslyn = {
      enable = true;
    };

    # Register .razor and .cshtml file types
    filetype = {
      extension = {
        razor = "razor";
        cshtml = "razor";
      };
    };
  };
}
