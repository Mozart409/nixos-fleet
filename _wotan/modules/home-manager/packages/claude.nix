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
        # Nix: evaluate, build and search only. Anything that activates a
        # generation is denied below.
        "Bash(nix build *)"
        "Bash(nix eval *)"
        "Bash(nix flake *)"
        "Bash(nix search *)"
        "Bash(nix log *)"
        "Bash(nix path-info *)"
        "Bash(nix why-depends *)"
        "Bash(nh search *)"
        "Bash(nh os build*)"
        "Bash(nh home build*)"
        "Bash(nixos-rebuild build*)"
        "Bash(nixos-rebuild dry-build*)"
        "Bash(just *)"
        "Bash(alejandra *)"
        # git: local, non-destructive subcommands only; everything else asks.
        "Bash(git status*)"
        "Bash(git diff*)"
        "Bash(git log*)"
        "Bash(git show*)"
        "Bash(git blame*)"
        "Bash(git rev-parse*)"
        "Bash(git ls-files*)"
        "Bash(git grep*)"
        "Bash(git branch*)"
        "Bash(git switch*)"
        "Bash(git fetch*)"
        "Bash(git stash*)"
        "Bash(git add *)"
        "Bash(git commit *)"
        # HTTP against the homelab and loopback skips the prompt. This only
        # matches command text; sandbox.network below is the actual boundary.
        "Bash(curl *.homelab.internal*)"
        "Bash(curl *.homelab.local*)"
        "Bash(curl *localhost*)"
        "Bash(curl *127.0.0.1*)"
        "Bash(wget *.homelab.internal*)"
        "Bash(wget *.homelab.local*)"
        "Bash(wget *localhost*)"
        "Bash(wget *127.0.0.1*)"
        "WebSearch"
        # Homelab gateway (managed-mcp.json); pg*_run_query is read-only.
        "mcp__axon-gateway"
        "Read(~/.config/nixpkgs/config.nix)"
        # agenix recipients file: public keys only.
        "Read(//etc/nixos/secrets.nix)"
      ];
      # Read(...) denies are also merged into sandbox.filesystem.denyRead, so
      # with the sandbox on they block `cat` & co. in Bash too, not just the
      # Read tool.
      deny = [
        "Read(~/.ssh/**)"
        "Read(~/.gnupg/**)"
        "Read(~/.claude/.credentials.json)"
        "Read(~/.local/share/opencode/auth.json)"
        "Read(~/.config/sops/age/**)"
        "Read(~/.config/age/**)"
        "Read(//etc/ssh/ssh_host_*)"
        # /run/agenix is a symlink to /run/agenix.d/<gen>; bwrap can't mount
        # over a symlink, so deny the real directory.
        "Read(//run/agenix.d/**)"
        "Read(**/.env*)"
        "Read(**/secrets/**)"
        "Read(**/.age*)"
        # No root, and nothing that switches the system or home generation.
        "Bash(sudo *)"
        "Bash(*nixos-rebuild*switch*)"
        "Bash(*nixos-rebuild*boot*)"
        "Bash(*nixos-rebuild*test*)"
        "Bash(*os switch*)"
        "Bash(*os boot*)"
        "Bash(*os test*)"
        "Bash(*home switch*)"
        "Bash(*home-manager*switch*)"
        "Bash(*switch-to-configuration*)"
        "Bash(*switch.sh*)"
        "Bash(*cleanup.sh*)"
        "Bash(just switch*)"
        "Bash(just test*)"
        "Bash(nix profile *)"
        "Bash(nix-env *)"
        "Bash(nh clean*)"
        # Never push, and never bypass hooks or commit signing.
        "Bash(git push*)"
        "Bash(just sync-remotes*)"
        "Bash(git *--no-verify*)"
        "Bash(git commit -n*)"
        "Bash(git commit * -n*)"
        "Bash(git *--no-gpg-sign*)"
        "Bash(git *commit.gpgsign*)"
        "Bash(git *core.hooksPath*)"
        "Bash(*LEFTHOOK*)"
        "Bash(*GIT_CONFIG_*)"
        # Destructive working-tree operations.
        "Bash(git reset *--hard*)"
        "Bash(git clean*)"
        "Bash(git checkout -- *)"
        "Bash(git checkout .*)"
        "Bash(git restore .*)"
      ];
      defaultMode = "auto";
    };
    # OS-level isolation (bubblewrap + seccomp) for Bash commands.
    sandbox = {
      enabled = true;
      failIfUnavailable = true;
      # Ignore dangerouslyDisableSandbox; anything that must run outside goes
      # through excludedCommands, which still passes the permission rules.
      allowUnsandboxedCommands = false;
      # Only commands that need the nix-daemon socket run outside, and only
      # the build/eval/search ones. Everything else (just recipes, nix run,
      # ...) stays sandboxed, where sudo cannot escalate (no_new_privs), so
      # nothing can switch the system even if it slips past the deny rules.
      # git commit needs gpg-agent + ~/.gnupg for signing.
      excludedCommands = [
        "nix build *"
        "nix eval *"
        "nix flake *"
        "nix search *"
        "nix log *"
        "nix path-info *"
        "nix why-depends *"
        "nh search *"
        "nh os build*"
        "nh home build*"
        "nixos-rebuild build*"
        "nixos-rebuild dry-build*"
        "git commit *"
      ];
      network = {
        # Unlisted hosts prompt instead of failing.
        allowedDomains = [
          "*.homelab.internal"
          "*.homelab.local"
          "localhost"
          "127.0.0.1"
        ];
        allowLocalBinding = true;
      };
      filesystem.allowWrite = ["~/.cache"];
    };
    env = {
      CLAUDE_CODE_ENABLE_TELEMETRY = "0";
      # Updates come from the flake, not the built-in updater.
      DISABLE_AUTOUPDATER = "1";
      EDITOR = "nvim";
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
    outputStyle = "Concise";
    model = "opus";
    effortLevel = "high";
    modelSettings."claude-opus-5-5".effortLevel = "medium";
    tui = "fullscreen";
    autoCompactEnabled = true;
    agentPushNotifEnabled = true;
    enabledPlugins = {
      "context7@claude-plugins-official" = true;
      "commit-commands@claude-plugins-official" = true;
      "security-guidance@claude-plugins-official" = true;
      "playwright@claude-plugins-official" = false;
      "rust-analyzer-lsp@claude-plugins-official" = true;
      "context-mode@context-mode" = true;
    };
    extraKnownMarketplaces.context-mode.source = {
      source = "github";
      repo = "mksglu/context-mode";
    };
  };

  # Personal skill teaching Claude this repo's commit conventions. Lives under
  # ~/.claude/skills, so it is available to every Claude Code session for this
  # user across all projects (not scoped to /etc/nixos).
  commitSkill = ''
    ---
    name: commits
    description: Create git commits in this repo's conventional-commit style. Use whenever asked to commit, stage and commit, or write a commit message.
    ---

    # Commit handling

    This NixOS config enforces Conventional Commits via cocogitto (`cog verify` in
    the commit-msg hook) and auto-formats staged Nix with alejandra (lefthook
    pre-commit). Honor both — a bad message or unformatted file fails the commit.

    ## Message format

    `type(scope): summary`

    - **lowercase** summary, concise, no trailing period
    - plain descriptive wording — match the most recent `git log`
    - single line; add a body only when the change genuinely needs explaining
    - scope = the module/area touched (e.g. `easyeffects`, `lsp`, `switch`, `vllm`)

    Common types: `fix`, `feat`, `docs`, `refactor`, `chore`, `style`, `build`.

    Examples (verbatim style from this repo):
    - `fix(easyeffects): raise autogain history to curb silence pumping`
    - `docs(easyeffects): add document with tuning options`
    - `fix(lsp): add biome binary`

    ## Workflow

    1. Stage only the files relevant to the change (`git add <paths>`), not `-A`.
    2. Run the commit with the sandbox disabled — the commit-msg / signing hooks
       need askpass, which fails inside the sandbox.
    3. Never add AI or co-author attribution (already disabled in settings.json).
    4. Do not push unless explicitly asked.
    5. If the pre-commit hook reformats a staged file, re-stage it and retry.
  '';
in {
  # The claude-code package itself is installed system-wide
  # (modules/nixos/common-packages.nix).
  home.file.".claude/settings.json" = {
    text = lib.generators.toJSON {} claudeSettings;
    force = true;
  };
  home.file.".claude/skills/commits/SKILL.md".text = commitSkill;
}
