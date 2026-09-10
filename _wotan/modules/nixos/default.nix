{...}: {
  # Aggregator for all shared NixOS modules. Hosts import this single directory
  # (`../../modules/nixos`) instead of listing each module. Every optional
  # module is gated by its own `enable` flag (default off), so importing the
  # whole set here is safe — a host only activates what it opts into:
  #
  #   desktop.enable                  -> desktop/*
  #   security.hardening.enable       -> security.nix
  #   hardware.razer.enable           -> razer.nix
  #   hardware.moza.enable            -> moza.nix
  #   services.vllm.enable            -> vllm.nix
  #   programs.claudeCodeMcp.enable   -> claude-code.nix
  #   services.opencode-serve.enable  -> opencode-serve.nix
  #
  # common-packages.nix (which pulls basics.nix) is baseline and always applies.
  imports = [
    ./common-packages.nix
    ./claude-code.nix
    ./security.nix
    ./razer.nix
    ./moza.nix
    ./vllm.nix
    ./opencode-serve.nix
    ./desktop/default.nix
    ./desktop/hyprland.nix
    ./desktop/file-managers.nix
    ./desktop/user-experience.nix
  ];
}
