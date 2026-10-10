{
  config,
  pkgs,
  lib,
  osConfig,
  ...
}: let
  # Commit signing via the signing-only agent from opencode-serve (see
  # modules/wotan/opencode-serve.nix): Claude never gets the login keys.
  signing = osConfig.services.opencode-serve.signing;
  signingEnv = lib.optionalAttrs (signing.keyFile != null) {
    SSH_AUTH_SOCK = "/run/opencode-signing/agent.sock";
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

  # Settings shared with the agents host's zones (modules/claude-settings-common.nix).
  common = import ../../claude-settings-common.nix;

  claudeSettings = {
    inherit (common) includeGitInstructions attribution language spinnerTipsEnabled cleanupPeriodDays respectGitignore;
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
        "mcp__ventara-gateway"
        "Read(~/.config/nixpkgs/config.nix)"
        # agenix recipients file: public keys only.
        "Read(~/code/yggdrasil/infra/secrets/agenix-rules.nix)"
      ];
      # Read(...) denies are also merged into sandbox.filesystem.denyRead, so
      # with the sandbox on they block `cat` & co. in Bash too, not just the
      # Read tool.
      # The shared floor (credentials, deploys, GitHub, hook bypass,
      # destructive git) is modules/claude-deny-core.nix, also used by the
      # fleet; below are wotan's own additions.
      deny =
        import ../../claude-deny-core.nix {home = "~";}
        ++ [
          "Read(**/.env*)"
          # agenix ciphertext anywhere, not whole secrets/ dirs: deny beats
          # allow, so a dir-wide deny would also hide the recipients file
          # allowed above.
          "Read(**/.age*)"
          # No root.
          "Bash(sudo *)"
          # Running switch.sh only. A bare *switch.sh* also matched git add,
          # cat and sed on it, so it could not be edited or staged.
          "Bash(infra/hosts/wotan/switch.sh*)"
          "Bash(./infra/hosts/wotan/switch.sh*)"
          "Bash(./switch.sh*)"
          "Bash(bash *switch.sh*)"
          "Bash(sh *switch.sh*)"
          "Bash(*cleanup.sh*)"
          "Bash(just test*)"
          # Never push: wotan's pushes go through the user's switch.
          "Bash(git push*)"
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
          "*.homelab.local"
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
}
