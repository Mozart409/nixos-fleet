{pkgs, ...}: {
  programs.nixvim = {
    # Linting
    # https://nix-community.github.io/nixvim/plugins/lint/index.html
    plugins.lint = {
      enable = true;

      # NOTE: Enabling these will cause errors unless these tools are installed
      lintersByFt = {
        nix = ["nix"];
        markdown = [
          # "vale"
        ];
        #clojure = ["clj-kondo"];
        #inko = ["inko"];
        #janet = ["janet"];
        # json = [ "jsonlint" ];
        #rst = ["vale"];
        #ruby = ["ruby"];
        #terraform = ["tflint"];
        # text = ["vale"];  # Disabled: vale exits with code 2 without .vale.ini config
      };

      # Create autocommand which carries out the actual linting
      # on the specified events.
      autoCmd = {
        callback.__raw = ''
          function()
            require('lint').try_lint()
          end
        '';
        group = "lint";
        event = [
          "BufEnter"
          "BufWritePost"
          "InsertLeave"
        ];
      };
    };

    # https://nix-community.github.io/nixvim/NeovimOptions/autoGroups/index.html
    autoGroups = {
      lint = {
        clear = true;
      };
    };
  };
}
