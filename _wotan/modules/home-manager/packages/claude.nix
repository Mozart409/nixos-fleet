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
        # HTTP only against the homelab and loopback; other URLs ask.
        "Bash(curl *.homelab.internal*)"
        "Bash(curl *localhost*)"
        "Bash(curl *127.0.0.1*)"
        "Bash(wget *.homelab.internal*)"
        "Bash(wget *localhost*)"
        "Bash(wget *127.0.0.1*)"
        "WebSearch"
        "Read(~/.config/nixpkgs/config.nix)"
        # agenix recipients file: public keys only.
        "Read(//etc/nixos/secrets.nix)"
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
        # Never push, and never bypass hooks or commit signing.
        "Bash(git push*)"
        "Bash(git *--no-verify*)"
        "Bash(git commit -n*)"
        "Bash(git commit * -n*)"
        "Bash(git *--no-gpg-sign*)"
        "Bash(git *commit.gpgsign=false*)"
        "Bash(git *core.hooksPath*)"
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
      sessionUrl = false;
    };
    language = "english";
    spinnerTipsEnabled = false;
    autoUpdatesChannel = "stable";
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
