{
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;
      settings = {
        addBlankLineAtTop = true;
        autoCleanAfterSessionRestore = true;
        closeIfLastWindow = true;
        filesystem = {
          window = {
            mappings = {
              "\\" = "close_window";
            };
          };
        };
      };
    };

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
