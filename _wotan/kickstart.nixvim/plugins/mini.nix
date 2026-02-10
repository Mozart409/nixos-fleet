{
  programs.nixvim = {
    # Collection of various small independent plugins/modules
    # https://nix-community.github.io/nixvim/plugins/mini.html
    plugins.mini = {
      enable = true;

      mockDevIcons = true;
      modules = {
        # Better Around/Inside textobjects
        #
        # Examples:
        #  - va)  - [V]isually select [A]round [)]paren
        #  - yinq - [Y]ank [I]nside [N]ext [Q]uote
        #  - ci'  - [C]hange [I]nside [']quote

        # ai = {
        #   enable = true;
        #   n_lines = 500;
        # };

        # Add/delete/replace surroundings (brackets, quotes, etc.)
        #
        # Examples:
        #  - saiw) - [S]urround [A]dd [I]nner [W]ord [)]Paren
        #  - sd'   - [S]urround [D]elete [']quotes
        #  - sr)'  - [S]urround [R]eplace [)] [']

        # surround = {
        #   enable = true;
        # };
        #
        icons = {
          enable = true;
        };

        # Disable mini.statusline in favor of heirline
        statusline = {
          enable = false;
        };

        # ... and there is more!
        # Check out: https://github.com/echasnovski/mini.nvim
      };
    };
  };
}
