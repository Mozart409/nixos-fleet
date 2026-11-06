{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # Commit signing via Claude's own signing-only agent (signing.agents in
  # modules/wotan/opencode-serve.nix): Claude never gets the login keys.
  signing = osConfig.services.opencode-serve.signing;

  # Hindsight recall/retain rules, as a SessionStart hook (modules/agent-memory.nix).
  memory = import ../../agent-memory.nix {
    inherit pkgs lib;
    agent = "claude-wotan";
  };
  signingEnv = lib.optionalAttrs (signing.keyFile != null) {
    SSH_AUTH_SOCK = signing.sockets.claude;
    GIT_CONFIG_COUNT = "3";
    GIT_CONFIG_KEY_0 = "user.signingkey";
    GIT_CONFIG_VALUE_0 = "key::${signing.publicKey}";
    GIT_CONFIG_KEY_1 = "gpg.format";
    GIT_CONFIG_VALUE_1 = "ssh";
    GIT_CONFIG_KEY_2 = "commit.gpgsign";
    GIT_CONFIG_VALUE_2 = "true";
  };

  # `git commit *` in sandbox.excludedCommands only matches a bare command.
  # Compound forms (`git add … && git commit …`, `… | tail`, `nix develop -c
  # git commit`) run sandboxed, where seccomp blocks the signing-agent socket
  # ("Couldn't get agent socket?"). Linux can't allowlist one socket path, so
  # reject those forms and tell Claude to rerun the commit on its own.
  gitCommitGuard = pkgs.writeShellScript "claude-git-commit-guard" ''
    cmd=$(${lib.getExe pkgs.jq} -r '.tool_input.command // ""')
    cmd=''${cmd//$'\n'/;}
    detect='(^|[;&|(])[[:space:]]*((env|command|exec)[[:space:]]+|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+|nix[[:space:]]+develop([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+(-c|--command)[[:space:]]+)*git([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+commit([[:space:]]|$)'
    bare='^[[:space:]]*git[[:space:]]+commit([[:space:]]+[^;&|<>`]*)?$'
    [[ $cmd =~ $detect ]] || exit 0
    [[ $cmd =~ $bare && $cmd != *'$('* ]] && exit 0
    echo 'Blocked: git commit must be its own Bash call (exactly `git commit -m "type(scope): summary"`): no cd/&&/;/pipes/redirects/$(...)/nix develop wrapper. Only that bare form runs outside the sandbox and can reach the commit-signing agent. Stage files in a separate call first.' >&2
    exit 2
  '';

  # Points every session at the delegate-implementation skill below, so the
  # model loads it for implementation work instead of relying on the
  # description match alone.
  delegateHook = pkgs.writeShellScript "claude-delegate-hint" ''
    echo 'Standing instruction: before changing any code (Nix files included, any language), config or docs beyond a one- or two-line edit, load the `delegate-implementation` skill and follow it (Haiku/Sonnet subagents implement without running tests/lints/fmt; you run the final fmt, lint and test pass).'
  '';

  # Settings shared with the agents host's zones (modules/claude-settings-common.nix).
  common = import ../../claude-settings-common.nix;

  claudeSettings = {
    inherit (common) includeGitInstructions attribution language spinnerTipsEnabled cleanupPeriodDays respectGitignore;
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    permissions = {
      inherit (import ./agent-permissions.nix) allow deny;
      # Read(...) denies are also merged into sandbox.filesystem.denyRead, so
      # with the sandbox on they block `cat` & co. in Bash too, not just the
      # Read tool. The rules live in agent-permissions.nix (shared with opencode).
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
      # git commit needs the signing agent socket (seccomp blocks unix sockets
      # inside the sandbox) and runs the lefthook hooks.
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
          "localhost"
          "127.0.0.1"
        ];
        allowLocalBinding = true;
      };
      filesystem.allowWrite = ["~/.cache"];
    };
    env =
      common.env
      // {EDITOR = "nvim";}
      // signingEnv;
    hooks.SessionStart =
      memory.claudeHooks.SessionStart
      ++ [
        {
          hooks = [
            {
              type = "command";
              command = "${delegateHook}";
            }
          ];
        }
      ];
    hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = "${gitCommitGuard}";
          }
        ];
      }
    ];
    outputStyle = "Concise";
    model = "opus";
    effortLevel = "high";
    modelSettings."claude-opus-5-5".effortLevel = "high";
    tui = "fullscreen";
    autoCompactEnabled = true;
    # Compact at 300k tokens instead of the window Claude Code tunes per model.
    # Set here (not left to /autocompact, which would save the choice under
    # modelSettings) so the value survives this file being regenerated. Valid
    # range is 100000-1000000 tokens; Claude Code still caps it at the model's
    # own context window.
    autoCompactWindow = 300000;
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
  # user across all projects (not scoped to one repo).
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

    1. Stage only the files relevant to the change (`git add <paths>`), not `-A`,
       in its own Bash call.
    2. Commit in a separate Bash call that is exactly
       `git commit -m "type(scope): summary"` — no `cd`, `&&`, pipes, redirects,
       `$(...)` or `nix develop -c` wrapper. Only that bare form runs outside the
       sandbox, where it can reach the commit-signing agent; anything else fails
       with "Couldn't get agent socket?" (a PreToolUse hook rejects it up front).
    3. Never add AI or co-author attribution (already disabled in settings.json).
    4. Do not push unless explicitly asked.
    5. If the pre-commit hook reformats a staged file, re-stage it and retry.
  '';
in {
  # The claude-code package itself is installed system-wide
  # (modules/wotan/common-packages.nix).
  home.file.".claude/settings.json" = {
    text = lib.generators.toJSON {} claudeSettings;
    force = true;
  };
  home.file.".claude/skills/commits/SKILL.md".text = commitSkill;
  home.file.".claude/skills/delegate-implementation/SKILL.md".source = ./claude-skills/delegate-implementation/SKILL.md;
}
