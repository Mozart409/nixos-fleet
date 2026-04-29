{pkgs, ...}: {
  programs.nixvim = {
    extraPlugins = with pkgs.vimPlugins; [
      d2-vim
    ];

    # Lazy-load on d2 filetype
    autoCmd = [
      {
        event = ["FileType"];
        pattern = ["d2"];
        callback.__raw = ''
          function()
            vim.bo.commentstring = "# %s"
          end
        '';
      }
    ];
  };
}
