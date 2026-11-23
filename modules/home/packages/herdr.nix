# herdr: terminal workspace for coding agents. config.toml is immutable from the
# store, so changes made in herdr's settings UI or `herdr config set` do not
# persist -- change them here. No herdr plugins or agent integrations are
# installed (decided against).
{...}: {
  programs.herdr = {
    enable = true;
    settings = {
      # Config is Nix-owned and read-only; the first-run flow would try to
      # install agent integrations into Nix-managed files.
      onboarding = false;
      # Under ~/code so the confined agent account can reach sidebar-created worktrees.
      worktrees.directory = "~/code/herdr-worktrees";
      # Follow kitty's palette.
      theme.name = "terminal";
      # Desktop notifications via the session's notification daemon.
      ui.toast.delivery = "system";
    };
  };
}
