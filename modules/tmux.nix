{...}: {
  # The fleet's tmux is wotan's home module (modules/home/packages/tmux.nix)
  # with the catppuccin theme. Shell helpers that pair with it live in
  # modules/server.nix:
  #   t <name>  attach-or-create a tmux session named <name>
  #   tk        kill the current tmux session (closes every window in it)
  imports = [./home/packages/tmux.nix];
  homelab.tmux.theme = "catppuccin";
}
