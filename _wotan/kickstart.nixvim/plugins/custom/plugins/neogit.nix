{
  programs.nixvim = {
    plugins.neogit = {
      enable = true;
      settings = {
        kind = "auto";
        commit_popup.kind = "split";
        integrations = {
          diffview = true;
          fzf_lua = true;
        };
        signs = {
          hunk = ["" ""];
          item = ["" ""];
          section = ["" ""];
        };
      };
    };
    # Enable diffview for better diff viewing in Neogit
    plugins.diffview.enable = true;
  };
}
