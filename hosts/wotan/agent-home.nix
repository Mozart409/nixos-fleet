{
  osConfig,
  pkgs,
  lib,
  ...
}: {
  # home-manager for `agent`, the account Claude Code and opencode run as
  # (modules/wotan/agent-user.nix). Only what the harnesses need: their
  # config, direnv for the dev shells, node for the plugins, and a git
  # identity.
  imports = [
    ../../modules/home/packages/claude.nix
    ../../modules/home/packages/opencode.nix
    ../../modules/home/packages/worktrunk.nix
  ];

  home.username = osConfig.wotan.agentUser.user;
  home.homeDirectory = osConfig.wotan.agentUser.home;
  home.stateVersion = "24.11";

  opencode.enable = true;

  # OpenCode Go authenticates with the raw Console API key
  # (secrets/opencode-go-api-key.age); the server exports it as
  # $OPENCODE_GO_API_KEY via services.opencode-serve.credentialEnvironment.
  # Gated on the .age file, exactly like the host module does.
  opencode.goApiKeyEnvironment = lib.mkIf (
    builtins.pathExists ../../secrets/opencode-go-api-key.age
  ) "OPENCODE_GO_API_KEY";

  # The context-mode Claude plugin runs its hooks and MCP server with node,
  # by absolute path: ~/.nix-profile/bin/node.
  # python3 is for the scripts the agents write and run; ripgrep and jq are
  # the everyday Bash tools no dev shell here provides (the harnesses' own
  # Grep tools bundle their ripgrep, but `rg` on PATH was missing). just runs
  # the repo's justfile recipes, which the dev shell otherwise hides from the
  # agent's PATH.
  home.packages = with pkgs; [
    jq
    just
    nodejs
    python3
    ripgrep
  ];

  # agent-run loads the directory's .envrc before starting the harness.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Commits keep amadeus as author, as before the move; they are signed with
  # the bot signing key (GIT_CONFIG_* from claude.nix, opencode-serve for the
  # server).
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
