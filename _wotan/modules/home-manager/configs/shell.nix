{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = true;
      format = "$directory$git_branch$git_status$nix_shell$kubernetes$cmd_duration$line_break$character";
      character = {
        success_symbol = "[ॐ](bold green)";
        error_symbol = "[ॐ](bold red)";
      };
      directory = {
        truncation_length = 3;
        truncate_to_repo = false;
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
      };
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        conflicted = "=";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "?\${count}";
        stashed = "$\${count}";
        modified = "!\${count}";
        staged = "+\${count}";
        deleted = "✘\${count}";
      };
      nix_shell = {
        format = "[$symbol$state]($style) ";
        symbol = " ";
        impure_msg = "";
      };
      kubernetes = {
        disabled = false;
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        symbol = "☸ ";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };
    };
  };

  # Directory jumping (replaces oh-my-zsh `z` plugin).
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # Fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C cd.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Per-directory dev shells via `use flake` in .envrc.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    zprof.enable = false;
    history = {
      expireDuplicatesFirst = true;
      extended = true;
      ignoreDups = true;
      save = 50000;
      size = 50000;
      saveNoDups = true;
      share = true;
    };
    setOptions = [
      "HIST_IGNORE_SPACE"
    ];
    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    shellAliases = {
      l = "eza -lah --git --icons --group-directories-first";
      lg = "lazygit";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      flk = "cd /etc/nixos";
      pup = "podman-compose up -d";
      pwn = "podman-compose down";
      n = "nvim .";
      t = "tmux";
      op = "opencode";
      s = "kitty +kitten ssh";
    };
  };
}
