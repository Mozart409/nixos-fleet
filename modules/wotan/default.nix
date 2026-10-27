{...}: {
  # Aggregator for all shared NixOS modules. Hosts import this single directory
  # (`../../modules/wotan`) instead of listing each module. Every optional
  # module is gated by its own `enable` flag (default off), so importing the
  # whole set here is safe — a host only activates what it opts into:
  #
  #   desktop.enable                  -> desktop/*
  #   security.hardening.enable       -> security.nix
  #   hardware.moza.enable            -> moza.nix
  #   programs.claudeCodeMcp.enable   -> claude-code.nix
  #   services.opencode-serve.enable  -> opencode-serve.nix
  #   wotan.agentUser.enable          -> agent-user.nix
  #
  # common-packages.nix (which pulls basics.nix) is baseline and always applies.
  imports = [
    ./agent-user.nix
    ./common-packages.nix
    ./claude-code.nix
    ./security.nix
    ./moza.nix
    ./opencode-serve.nix
    ../desktop/default.nix
    ../desktop/hyprland.nix
    ../desktop/file-managers.nix
    ../desktop/user-experience.nix
  ];
}
