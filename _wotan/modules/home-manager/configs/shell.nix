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
        stashed = "\\$\${count}";
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
      # Directory traversal (previously provided by oh-my-zsh core lib).
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      l = "eza -lah --git --icons --group-directories-first";
      lg = "lazygit";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      flk = "cd /etc/nixos";
      pup = "podman-compose up -d";
      pwn = "podman-compose down";
      n = "nvim .";
      op = "opencode";
      s = "kitty +kitten ssh";
    };
    initContent = ''
      # Keep vi keybindings (zsh auto-selects vi mode because $EDITOR=nvim), but
      # make Alt+word combos act on words *while staying in insert mode*. Without
      # these, Alt sends ESC and drops into vi command mode: Alt+b/Alt+w happen to
      # run vi b/w motions, but Alt+d triggers the `d` delete-operator that waits
      # for a motion, so it appears to do nothing.
      bindkey -M viins '\eb' backward-word    # Alt+b  - jump word left
      bindkey -M viins '\ew' forward-word      # Alt+w  - jump word right
      bindkey -M viins '\ed' kill-word         # Alt+d  - delete word forward
      bindkey -M viins '\ef' forward-word      # Alt+f  - (emacs-style alias)
      bindkey -M viins '^W' backward-kill-word # Ctrl+W - delete word backward

      # `t` opens (or re-attaches to) ONE tmux session per directory.
      # Session name = sanitized folder basename. `new-session -A` attaches to
      # an existing session of that name instead of spawning a duplicate, so
      # running `t` again in the same folder never opens a second nvim.
      t() {
        local name="''${''${PWD:t}//[.:]/_}"
        tmux new-session -A -s "$name"
      }

      # `tk` kills the tmux session for the current directory (run from shell).
      tk() {
        local name="''${''${PWD:t}//[.:]/_}"
        tmux kill-session -t "$name" 2>/dev/null \
          && echo "killed tmux session: $name" \
          || echo "no tmux session: $name"
      }
    '';
  };
}
