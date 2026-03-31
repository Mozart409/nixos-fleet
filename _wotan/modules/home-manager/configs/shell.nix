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
      format = "$directory$git_branch$git_status$nix_shell$cmd_duration$line_break$character";
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
      cmd_duration = {
        min_time = 2000;
        format = "[$duration]($style) ";
      };
    };
  };

  programs.zsh = {
    enable = true;
    zprof.enable = false;
    history = {
      expireDuplicatesFirst = true;
      extended = true;
      ignoreDups = true;
      save = 5000;
      size = 5000;
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
      l = "ls -lah";
      lg = "lazygit";
      ld = "lazydocker";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      flk = "cd /etc/nixos";
      dps = "docker compose ps";
      dup = "docker compose up -d --build --remove-orphans";
      dwn = "docker compose down";
      pup = "podman-compose up -d";
      pwn = "podman-compose down";
      n = "nvim .";
      t = "tmux";
      op = "opencode";
      zkdir = "cd ~/code/zettelkasten/";
      s = "kitty +kitten ssh";
    };
    oh-my-zsh = {
      enable = true;
      theme = ""; # disabled — using starship for prompt
      plugins = [
        "git"
        "z"
      ];
    };
  };
}
