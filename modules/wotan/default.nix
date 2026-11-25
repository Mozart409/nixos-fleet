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
  #   wotan.agentUser.enable          -> agent-clipboard.nix
  #   wotan.minecraft.enable          -> minecraft.nix
  #   wotan.vulnScan.enable           -> vuln-scan.nix
  #   wotan.agentVm.<name>            -> agent-vm.nix
  #
  # common-packages.nix (which pulls basics.nix) is baseline and always applies.
  imports = [
    ./agent-clipboard.nix
    ./agent-user.nix
    ./agent-vm.nix
    ./common-packages.nix
    ./claude-code.nix
    ./security.nix
    ./moza.nix
    ./minecraft.nix
    ./opencode-serve.nix
    ./vuln-scan.nix
    ../desktop/default.nix
    ../desktop/hyprland.nix
    ../desktop/file-managers.nix
    ../desktop/user-experience.nix
  ];
}
