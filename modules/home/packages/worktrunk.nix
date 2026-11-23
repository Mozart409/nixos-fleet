# worktrunk (`wt`): git worktree manager. Imported by both home.nix (amadeus)
# and agent-home.nix (agent), so both accounts share one worktree layout.
# Claude Code integration stays off: claude.nix writes ~/.claude/settings.json
# itself.
{...}: {
  programs.worktrunk = {
    enable = true;
    settings = {
      # Sibling checkouts like ../yggdrasil-<branch>, matching the existing
      # worktree naming and staying inside ~/code.
      "worktree-path" = "{{ repo_path }}/../{{ repo }}-{{ branch | sanitize }}";
      # Forgejo speaks the Gitea API; the remote's ssh host carries port 2222,
      # the API is on the plain hostname.
      projects."forgejo.homelab.internal:2222/*".forge = {
        platform = "gitea";
        hostname = "forgejo.homelab.internal";
      };
    };
  };
}
