{
  config,
  pkgs,
  lib,
  ...
}: {
  programs = {
    fastfetch.enable = true;
    ripgrep.enable = true;
    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
    k9s.enable = true;
    direnv = {
      enable = true;
      enableZshIntegration = true;
    };
    git = {
      enable = true;
      signing = {
        format = "ssh";
        signByDefault = true;
      };
      settings = {
        user.name = "Amadeus Mader";
        user.email = "amadeus@mozart409.com";
        user.signingkey = "/home/amadeus/.ssh/id_ed25519.pub";
        aliases = {
          ci = "commit";
          s = "status";
          f = "fetch";
        };
        init.defaultBranch = "main";
        pull.rebase = "true";
        credential = {
          helper = "oauth";
          cache = "--timeout 21600";
        };
      };
      ignores = [
        "*~"
        "*.swp"
      ];
    };
    lazygit = {
      enable = true;
      settings.gui.theme = {
        activeBorderColor = ["#89b4fa" "bold"];
        inactiveBorderColor = ["#a6adc8"];
        optionsTextColor = ["#89b4fa"];
        selectedLineBgColor = ["#313244"];
        selectedRangeBgColor = ["#313244"];
        unstagedChangesColor = ["#f38ba8"];
        defaultFgColor = ["#cdd6f4"];
        searchingActiveBorderColor = ["#f9e2af"];
      };
    };
  };
}
