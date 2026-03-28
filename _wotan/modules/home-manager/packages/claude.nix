{
  config,
  pkgs,
  lib,
  ...
}: let
  claudeSettings = {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    permissions = {
      allow = [
        "Bash(nix *)"
        "Bash(just *)"
        "Bash(git *)"
        "Bash(alejandra *)"
        "Read(~/.config/nixpkgs/config.nix)"
      ];
      ask = [
        "Bash(sudo *)"
        "Bash(nixos-rebuild *)"
      ];
      deny = [
        "Read(~/.ssh/*)"
        "Read(./.env*)"
        "Read(**/secrets/**)"
        "Read(**/.age*)"
        "Bash(curl *)"
        "Bash(wget *)"
      ];
      defaultMode = "auto";
    };
    env = {
      CLAUDE_CODE_ENABLE_TELEMETRY = "0";
      EDITOR = "nvim";
    };
    includeGitInstructions = true;
    attribution = {
      commit = "";
      pr = "";
    };
    language = "english";
    spinnerTipsEnabled = true;
    autoUpdatesChannel = "stable";
    cleanupPeriodDays = 7;
    respectGitignore = true;
    outputStyle = "Concise";
  };
in {
  home.packages = with pkgs; [
    claude-code
  ];

  home.file.".claude/settings.json".text = lib.generators.toJSON {} claudeSettings;
}
