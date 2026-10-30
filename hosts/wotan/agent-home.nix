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
    ../../modules/home/packages/pi.nix
  ];

  home.username = osConfig.wotan.agentUser.user;
  home.homeDirectory = osConfig.wotan.agentUser.home;
  home.stateVersion = "24.11";

  opencode.enable = true;
  pi.enable = true;

  # The context-mode Claude plugin runs its hooks and MCP server with node,
  # by absolute path: ~/.nix-profile/bin/node. pi is the third harness
  # (`agent-run pi`); its OPENCODE_API_KEY comes in as an agent-run credential.
  # python3 is for the scripts the agents write and run; ripgrep and jq are
  # the everyday Bash tools no dev shell here provides (the harnesses' own
  # Grep tools bundle their ripgrep, but `rg` on PATH was missing).
  home.packages = with pkgs; [
    jq
    nodejs
    pi-coding-agent
    python3
    ripgrep
  ];

  # agent-run loads the directory's .envrc before starting the harness.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Commits keep amadeus as author, as before the move; they are signed with
  # the bot signing key (GIT_CONFIG_* from claude.nix / opencode-serve).
  # nix's libgit2 ignores the `codeDir/*` safe.directory in /etc/gitconfig,
  # so `nix develop` refused every flake in a repo amadeus owns. libgit2 does
  # honor a bare `*`. Trusting every repo gives this user nothing new: it can
  # already write all of codeDir, where the repos live.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Amadeus Mader";
        email = "amadeus@mozart409.com";
      };
      safe.directory = "*";
    };
  };
}
