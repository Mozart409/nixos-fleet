{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.gitSync;

  git-sync = pkgs.writeShellApplication {
    name = "git-sync";
    runtimeInputs = [pkgs.git];
    text = ''
      CODE_DIR="${cfg.codeDir}"

      if [ ! -d "$CODE_DIR" ]; then
        echo "git-sync: no such directory: $CODE_DIR"
        exit 0
      fi

      # Fast-forward-only pull + push for one branch that already has an
      # upstream configured. Never rebases, merges non-ff, or force-pushes,
      # and never touches a branch without a pre-existing upstream (so it
      # can't create a new branch on the remote).
      sync_branch() {
        local repo="$1" branch="$2" current_branch="$3"
        local remote merge_ref upstream_ref local_rev upstream_rev

        remote="$(git -C "$repo" config --get "branch.$branch.remote" 2>/dev/null || true)"
        merge_ref="$(git -C "$repo" config --get "branch.$branch.merge" 2>/dev/null || true)"
        if [ -z "$remote" ] || [ -z "$merge_ref" ]; then
          return 0
        fi

        upstream_ref="refs/remotes/$remote/''${merge_ref#refs/heads/}"
        if ! git -C "$repo" rev-parse --verify -q "$upstream_ref" >/dev/null; then
          echo "  $branch: no remote-tracking ref for $remote/''${merge_ref#refs/heads/}, skipping"
          return 0
        fi

        local_rev="$(git -C "$repo" rev-parse "refs/heads/$branch")"
        upstream_rev="$(git -C "$repo" rev-parse "$upstream_ref")"

        if [ "$local_rev" != "$upstream_rev" ]; then
          if git -C "$repo" merge-base --is-ancestor "refs/heads/$branch" "$upstream_ref"; then
            if [ "$branch" = "$current_branch" ]; then
              git -C "$repo" merge --ff-only --quiet "$upstream_ref"
            else
              git -C "$repo" update-ref "refs/heads/$branch" "$upstream_ref"
            fi
            echo "  $branch: fast-forwarded to $remote/''${merge_ref#refs/heads/}"
          elif git -C "$repo" merge-base --is-ancestor "$upstream_ref" "refs/heads/$branch"; then
            : # local is ahead of upstream, nothing to pull
          else
            echo "  $branch: diverged from $remote/''${merge_ref#refs/heads/}, skipping (no rebase/merge attempted)"
            return 0
          fi
        fi

        local_rev="$(git -C "$repo" rev-parse "refs/heads/$branch")"
        if [ "$local_rev" != "$upstream_rev" ]; then
          if git -C "$repo" push "$remote" "refs/heads/$branch:$merge_ref"; then
            echo "  $branch: pushed to $remote/''${merge_ref#refs/heads/}"
          else
            echo "  $branch: push failed (rejected or diverged?), skipping" >&2
          fi
        fi
      }

      sync_repo() {
        local repo="$1" current_branch

        if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
          return 0
        fi

        if [ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]; then
          echo "$repo: working tree not clean, skipping"
          return 0
        fi

        if ! git -C "$repo" symbolic-ref -q HEAD >/dev/null; then
          echo "$repo: detached HEAD, skipping"
          return 0
        fi

        if ! git -C "$repo" fetch --prune --quiet; then
          echo "$repo: fetch failed, skipping" >&2
          return 0
        fi

        echo "$repo:"
        current_branch="$(git -C "$repo" symbolic-ref --short HEAD)"

        local branch
        while IFS= read -r branch; do
          [ -n "$branch" ] || continue
          sync_branch "$repo" "$branch" "$current_branch"
        done < <(git -C "$repo" for-each-ref --format='%(refname:short)' refs/heads/)
      }

      while IFS= read -r -d ${"''"} git_dir; do
        repo="''${git_dir%/.git}"
        sync_repo "$repo" || echo "$repo: unexpected error, skipping" >&2
      done < <(find "$CODE_DIR" -type d -name .git -prune -print0)
    '';
  };
in {
  options.gitSync = {
    enable = lib.mkEnableOption "periodic fast-forward-only git pull/push for every repo under ~/code";

    codeDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/code";
      description = "Directory tree to scan for git repositories.";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "0/4:00:00";
      description = "systemd OnCalendar expression for how often to run git-sync.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Only ever fast-forwards branches that already have an upstream, and
    # skips any repo whose working tree isn't clean -- never commits, never
    # rebases/merges non-fast-forward, never force-pushes, and never pushes a
    # branch that has no pre-existing upstream (so it can't create new
    # branches on the remote).
    systemd.user.services.git-sync = {
      Unit = {
        Description = "Fast-forward-only git pull/push for repos under ${cfg.codeDir}";
        After = ["gpg-agent-ssh.socket"];
      };

      Service = {
        Type = "oneshot";
        # Reuse the desktop session's gpg-agent SSH support for git auth
        # instead of a dedicated key (see programs.gpg-agent.enableSSHSupport
        # in modules/wotan/common-packages.nix).
        Environment = "SSH_AUTH_SOCK=%t/gnupg/S.gpg-agent.ssh";
        ExecStart = "${git-sync}/bin/git-sync";
      };
    };

    systemd.user.timers.git-sync = {
      Unit.Description = "Run git-sync periodically";

      Timer = {
        OnCalendar = cfg.interval;
        Persistent = true;
        RandomizedDelaySec = "5m";
      };

      Install.WantedBy = ["timers.target"];
    };
  };
}
