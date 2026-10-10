# Claude Code settings that mean the same on every install in this repo, with
# no host-specific path, hook, plugin or secret in them. wotan's home-manager
# module (modules/home/packages/claude.nix) and the agents host's trust zones
# (hosts/agents/zones.nix) both start from this, so a change to the shared
# behaviour is made once. Permissions are not here: the shared deny floor is
# modules/claude-deny-core.nix, and each side keeps its own allow list.
{
  env = {
    CLAUDE_CODE_ENABLE_TELEMETRY = "0";
    # Updates come from Nix, not the built-in updater.
    DISABLE_AUTOUPDATER = "1";
  };
  includeGitInstructions = true;
  attribution = {
    commit = "";
    pr = "";
    sessionUrl = false;
  };
  language = "english";
  spinnerTipsEnabled = false;
  cleanupPeriodDays = 3;
  respectGitignore = true;
}
