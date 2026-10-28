{
  osConfig,
  pkgs,
  ...
}: {
  # home-manager for `agent`, the account Claude Code and opencode run as
  # (modules/wotan/agent-user.nix). Only what the harnesses need: their
  # config, direnv for the dev shells, node for the plugins, and a git
  # identity.
  imports = [
    ../../modules/home/packages/claude.nix
    ../../modules/home/packages/opencode.nix
  ];

  home.username = osConfig.wotan.agentUser.user;
  home.homeDirectory = osConfig.wotan.agentUser.home;
  home.stateVersion = "24.11";

  opencode.enable = true;

  # The context-mode Claude plugin runs its hooks and MCP server with node,
  # by absolute path: ~/.nix-profile/bin/node. pi is the third harness
  # (`agent-run pi`); its OpenCode Zen key comes in as an agent-run credential.
  home.packages = [pkgs.nodejs pkgs.pi-coding-agent];

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
