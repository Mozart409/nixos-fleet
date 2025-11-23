{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    clock24 = true;
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
      set -g mouse off
      set-option -g allow-passthrough on

      unbind C-b
      set -g prefix C-Space
      bind C-Space send-prefix

      # Shift arrow to switch windows
      bind -n S-Left  previous-window
      bind -n S-Right next-window

      # Vim style pane selection
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      set-window-option -g mode-keys vi

      # keybindings
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

    '';
    plugins = with pkgs; [
      tmuxPlugins.cpu
      tmuxPlugins.yank
      tmuxPlugins.weather
      tmuxPlugins.urlview
      tmuxPlugins.sensible
      tmuxPlugins.rose-pine
      tmuxPlugins.tmux-floax
      tmuxPlugins.mode-indicator
      tmuxPlugins.tokyo-night-tmux
    ];
  };
}
