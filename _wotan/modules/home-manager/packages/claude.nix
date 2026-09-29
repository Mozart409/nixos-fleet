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
        "Bash(git *)"
        "Bash(alejandra *)"
        "Read(~/.config/nixpkgs/config.nix)"
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
        "Bash(curl *)"
        "Bash(wget *)"
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
  home.packages = with pkgs; [
    claude-code
  ];

  home.file.".claude/settings.json".text = lib.generators.toJSON {} claudeSettings;
  home.file.".claude/skills/commits/SKILL.md".text = commitSkill;
}
