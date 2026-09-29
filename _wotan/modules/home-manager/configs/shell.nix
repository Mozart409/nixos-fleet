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
      palette = "tokyonight";

      # Clean Tokyo Night two-line prompt: path + git / nix-shell / k8s /
      # duration as plain colored segments on line one, prompt char on line two.
      format = "$directory$git_branch$git_status$nix_shell$kubernetes$cmd_duration$line_break$character";

      palettes.tokyonight = {
        crust = "#1a1b26";
        base = "#24283b";
        surface = "#292e42";
        overlay = "#414868";
        fg = "#c0caf5";
        blue = "#7aa2f7";
        cyan = "#7dcfff";
        purple = "#bb9af7";
        green = "#9ece6a";
        red = "#f7768e";
        orange = "#ff9e64";
        yellow = "#e0af68";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
        vimcmd_symbol = "[❮](bold purple)";
      };
      directory = {
        format = "[$path]($style) ";
        style = "bold blue";
        truncation_length = 3;
        truncate_to_repo = false;
        read_only = " ";
        read_only_style = "bold red";
      };
      git_branch = {
        format = "[$symbol$branch]($style) ";
        symbol = " ";
        style = "bold green";
      };
      git_status = {
        format = "([$all_status$ahead_behind]($style) )";
        style = "bold purple";
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
        style = "bold cyan";
        impure_msg = "";
      };
      kubernetes = {
        disabled = false;
        format = "[$symbol$context( \\($namespace\\))]($style) ";
        symbol = "☸ ";
        style = "bold orange";
      };
      cmd_duration = {
        min_time = 2000;
        format = "[ $duration]($style) ";
        style = "bold yellow";
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

      # `tc` / `to`: like `t`, but window 1 runs claude / opencode, window 2 is
      # a plain shell and window 3 runs lazygit. Session "<dir>-claude" /
      # "<dir>-opencode", which the tmux session-created hook skips (no nvim).
      _tai() {
        local name="''${''${PWD:t}//[.:]/_}-$2"
        if ! tmux has-session -t "=$name" 2>/dev/null; then
          tmux new-session -d -s "$name" -c "$PWD" \; \
            send-keys -t "=$name:1" "$1" Enter \; \
            new-window -t "=$name" -c "$PWD" \; \
            new-window -t "=$name" -c "$PWD" \; \
            send-keys -t "=$name:3" lazygit Enter \; \
            select-window -t "=$name:1"
        fi
        tmux attach-session -t "=$name"
      }
      tc() { _tai claude claude; }
      to() { _tai opencode opencode; }

      # Interactive `opencode` (no args, or only flags like -c/-s) attaches to
      # the shared opencode-serve instance for $PWD instead of spawning its own
      # server. Subcommands (`opencode run`, `opencode models`, ...) pass through.
      # The basic-auth password is read from the agenix file per call and only
      # given to this one process — never exported, so other shell children
      # (e.g. sandboxed agents) can't use the server to escape their sandbox.
      opencode() {
        if (( $# == 0 )) || [[ $1 == -* ]]; then
          local pwfile="''${OPENCODE_SERVER_PASSWORD_FILE:-/run/agenix/opencode-server-password}"
          OPENCODE_SERVER_PASSWORD="$(sed 's/^OPENCODE_SERVER_PASSWORD=//' "$pwfile")" \
            command opencode attach "''${OPENCODE_SERVER_URL:-http://127.0.0.1:4096}" --dir "$PWD" "$@"
        else
          command opencode "$@"
        fi
      }

      # `tk` kills the current directory's `t`, `tc` and `to` sessions (run from
      # shell). `=` makes the target an exact match, not a name prefix.
      tk() {
        local base="''${''${PWD:t}//[.:]/_}" name killed=0
        for name in "$base" "$base-claude" "$base-opencode"; do
          tmux kill-session -t "=$name" 2>/dev/null \
            && echo "killed tmux session: $name" && killed=1
        done
        (( killed )) || echo "no tmux session: $base"
      }
    '';
  };
}
