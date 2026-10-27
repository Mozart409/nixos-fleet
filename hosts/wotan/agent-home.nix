{osConfig, ...}: {
  # home-manager for `agent`, the account Claude Code and opencode run as
  # (modules/wotan/agent-user.nix). Only what the harnesses need: their
  # config, direnv for the dev shells, and a git identity.
  imports = [
    ../../modules/home/packages/claude.nix
    ../../modules/home/packages/opencode.nix
  ];

  home.username = osConfig.wotan.agentUser.user;
  home.homeDirectory = osConfig.wotan.agentUser.home;
  home.stateVersion = "24.11";

  opencode.enable = true;

  # agent-run loads the directory's .envrc before starting the harness.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Commits keep amadeus as author, as before the move; they are signed with
  # the bot signing key (GIT_CONFIG_* from claude.nix / opencode-serve).
  programs.git = {
    enable = true;
    settings.user = {
      name = "Amadeus Mader";
      email = "amadeus@mozart409.com";
    };
  };
}
