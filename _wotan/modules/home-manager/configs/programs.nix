{
  config,
  pkgs,
  lib,
  ...
}: {
  home.file.".ssh/allowed_signers".text = ''
    amadeus@mozart409.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan
  '';

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
        gpg.ssh.allowedSignersFile = "/home/amadeus/.ssh/allowed_signers";
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
    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "Amadeus Mader";
          email = "amadeus@mozart409.com";
        };
        signing = {
          behavior = "own";
          backend = "ssh";
          key = "/home/amadeus/.ssh/id_ed25519.pub";
          backends.ssh."allowed-signers" = "/home/amadeus/.ssh/allowed_signers";
        };
        ui = {
          pager = "delta";
          diff-formatter = ":git";
        };
      };
    };
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Catppuccin Mocha";
        dark = true;
        hyperlinks = true;
      };
    };
    mangohud = {
      enable = true;
      settings = {
        fps = true;
        frametime = true;
        cpu_stats = true;
        cpu_temp = true;
        gpu_stats = true;
        gpu_temp = true;
        ram = true;
        vram = true;
        engine_version = true;
        vulkan_driver = true;
        wine = true;
        frame_timing = true;
        position = "top-left";
        background_alpha = "0.5";
        font_size = 18;
        toggle_hud = "Shift_R+F12";
      };
    };
    lazygit = {
      enable = true;
      settings = {
        gui = {
          showIcons = true;
          showFileTree = true;
          showListFooter = false;
          showRandomTip = false;
          showCommandLog = false;
          nerdFontsVersion = "3";
          border = "rounded";
          expandFocusedSidePanel = true;
          mouseEvents = true;
          skipDiscardChangeWarning = false;
          theme = {
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
        git = {
          pagers = [
            {
              pager = "delta --dark --paging=never";
              colorArg = "always";
            }
          ];
          autoFetch = false;
          autoRefresh = true;
          branchLogCmd = "git log --graph --color=always --abbrev-commit --decorate --date=relative --pretty=medium {{branchName}} --";
        };
        promptToReturnFromSubprocess = false;
        os.editPreset = "nvim";
      };
    };
  };
}
