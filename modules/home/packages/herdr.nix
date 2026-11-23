# herdr: terminal workspace for coding agents. config.toml is immutable from the
# store, so changes made in herdr's settings UI or `herdr config set` do not
# persist -- change them here. No herdr plugins or agent integrations are
# installed (decided against). zsh completion needs nothing here: nixpkgs'
# herdr installs `_herdr` into share/zsh/site-functions, which home-manager's
# zsh puts on fpath.
{...}: {
  programs.herdr = {
    enable = true;
    settings = {
      # Config is Nix-owned and read-only; the first-run flow would try to
      # install agent integrations into Nix-managed files.
      onboarding = false;
      # Under ~/code so the confined agent account can reach sidebar-created worktrees.
      worktrees.directory = "~/code/herdr-worktrees";
      # catppuccin base (the desktop palette is catppuccin-derived), recoloured
      # to kitty's colours and quickshell/Theme.qml so herdr matches the
      # terminal and the bar.
      theme = {
        name = "catppuccin";
        custom = {
          accent = "#33ccff"; # Theme.accent
          panel_bg = "#111119"; # Theme.bar, kitty background
          sidebar_bg = "#111119";
          surface_dim = "#16161f";
          surface0 = "#1e1e28"; # Theme.surface
          surface1 = "#2b2b33"; # Theme.module over the bar
          active_row_bg = "#1e1e28";
          selection_bg = "#3e3e45"; # Theme.moduleHover over the bar
          overlay0 = "#6c7086"; # Theme.muted
          text = "#cfd6f4"; # Theme.text
          subtext0 = "#a6adc8"; # Theme.subtext
          blue = "#33ccff"; # Theme.accent
          yellow = "#f5c542"; # Theme.warn
          red = "#ff6b6b"; # Theme.crit
        };
      };
      # Desktop notifications via the session's notification daemon.
      ui.toast.delivery = "system";
      # New tabs get a generated name instead of a name prompt.
      ui.prompt_new_tab_name = false;
      # Distinct static symbols per agent state instead of the default
      # colour-only dots, same as the fleet's infra/modules/herdr.nix.
      ui.status_indicators = "symbols";
      keys = {
        # Same leader as tmux (tmux.nix). Bindings are "prefix+<key>", not a
        # "ctrl+space+<key>" chord, which herdr rejects.
        prefix = "ctrl+space";
        # Prefix-free ctrl+alt chords, the set from the fleet's
        # infra/modules/herdr.nix: nothing inside a pane uses them and
        # Hyprland binds only SUPER.
        focus_pane_left = ["prefix+h" "ctrl+alt+h"];
        focus_pane_down = ["prefix+j" "ctrl+alt+j"];
        focus_pane_up = ["prefix+k" "ctrl+alt+k"];
        focus_pane_right = ["prefix+l" "ctrl+alt+l"];
        # shift+left/right switch tabs like tmux's S-Left/S-Right.
        previous_tab = ["prefix+p" "ctrl+alt+[" "shift+left"];
        next_tab = ["prefix+n" "ctrl+alt+]" "shift+right"];
        new_tab = ["prefix+c" "ctrl+alt+c"];
        # tmux's % (side by side) and " (stacked) next to herdr's v / minus.
        split_vertical = ["prefix+v" "prefix+percent" "ctrl+alt+d"];
        split_horizontal = ["prefix+minus" "prefix+double_quote" "ctrl+alt+shift+d"];
        zoom = ["prefix+z" "ctrl+alt+z"];
        workspace_picker = ["prefix+w" "ctrl+alt+w"];
        switch_tab = "prefix+1..9";
        switch_workspace = "prefix+alt+1..9";
        # Scratch shell over the current tab; exit it to restore the view.
        command = [
          {
            key = "prefix+t";
            type = "popup";
            command = "exec \"\${SHELL:-sh}\"";
            description = "open scratch terminal";
            width = "80%";
            height = "80%";
          }
        ];
      };
    };
  };
}
