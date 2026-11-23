{
  config,
  pkgs,
  lib,
  ...
}: let
  home = config.home.homeDirectory;

  # wotan's rules in Claude's syntax (agent-permissions.nix), translated below.
  shared = import ./agent-permissions.nix;

  # `Bash(x)` -> "x" for kind "Bash"; null for rules of another kind
  # (WebSearch, mcp__x, ...).
  ruleArg = kind: rule: let
    m = builtins.match "${kind}\\((.*)\\)" rule;
  in
    if m == null
    then null
    else builtins.head m;
  args = kind: rules: builtins.filter (a: a != null) (map (ruleArg kind) rules);

  # Claude path -> opencode globs. `~/x` is the home dir, a leading `//` is an
  # absolute path, `**` is `*` (opencode's `*` already crosses `/`). A leading
  # `**/` also yields the bare relative form, so `**/.env*` matches `.env` too.
  claudeGlobs = arg: let
    path =
      if lib.hasPrefix "~/" arg
      then "${home}/${lib.removePrefix "~/" arg}"
      else if lib.hasPrefix "//" arg
      then lib.removePrefix "/" arg
      else arg;
    glob = lib.replaceStrings ["**"] ["*"] path;
  in
    [glob] ++ lib.optional (lib.hasPrefix "**/" arg) (lib.removePrefix "*/" glob);

  rule = action: effect: resource: {inherit action resource effect;};
  rules = action: effect: map (rule action effect);

  # Pure reads. Deliberately no command executors: `bash`, `sh`, `env`,
  # `xargs`, `timeout`, `find -exec`, `sed e`/`awk system()` take a command
  # line or a script and would re-open the deny list (same rule as Claude's
  # allow list; see infra/AGENTS.md).
  readOnlyShell = [
    "cd *"
    "ls *"
    "cat *"
    "head *"
    "tail *"
    "wc *"
    "pwd"
    "which *"
    "command -v *"
    "type *"
    "file *"
    "stat *"
    "readlink *"
    "realpath *"
    "basename *"
    "dirname *"
    "rg *"
    "grep *"
    "tree *"
    "echo *"
    "printf *"
    "sort *"
    "uniq *"
    "cut *"
    "tr *"
    "seq *"
    "diff *"
    "jq *"
    "du *"
    "df *"
    "whoami"
    "id"
    "uname *"
    "hostname"
    "sha256sum *"
    "md5sum *"
    "true"
    "false"
    "date *"
  ];

  # Commands whose purpose is to reveal secrets, whatever file they touch.
  secretShell = [
    "* .env*"
    "*/.env*"
    "* .envrc*"
    "printenv*"
    "env"
    "env |*"
    "env >*"
    "export -p*"
    "declare -x*"
    "*agenix* -d *"
    "*agenix* --decrypt *"
    "sops -d*"
    "sops --decrypt*"
    "age -d*"
    "age --decrypt*"
    "gh auth token*"
    "op read*"
    "op item get*"
    "pass show*"
    "gpg -d*"
    "gpg --decrypt*"
    "* ~/.ssh/*"
    "* ~/.aws/*"
    "* ~/.gnupg/*"
    "* $HOME/.ssh/*"
    "* $HOME/.aws/*"
    "* /proc/*/environ*"
  ];

  secretFiles = [
    "*.env"
    "*.env.*"
    "*/.env*"
    "*.pem"
    "*.key"
    "*/.ssh/*"
    "*/.aws/*"
    "*/.gnupg/*"
    "*/.kube/*"
    "*credentials*"
    "*.tfstate*"
  ];
  templateFiles = [
    "*.env.example"
    "*.env.sample"
    "*.env.template"
  ];

  # The deny floor: Claude's deny list, as opencode resources.
  floorShell = args "Bash" shared.deny;
  floorFiles = lib.concatMap claudeGlobs (args "Read" shared.deny);

  # Order matters: the LAST matching rule wins. Broad asks and allows come
  # first, narrower denies after them, and the Claude-derived floor is last so
  # no allow above it can win over a floor deny. A project's opencode.json
  # loads after this file and can still append rules, which is why the
  # deny-floor plugin repeats the shell half of the floor.
  permissions =
    [(rule "shell" "ask" "*")]
    ++ rules "shell" "allow" (args "Bash" shared.allow ++ readOnlyShell)
    ++ rules "shell" "deny" secretShell
    ++ [(rule "read" "allow" "*")]
    ++ rules "read" "deny" (secretFiles
      ++ [
        "*.envrc"
        "*.p12"
        "*.pfx"
        "*id_rsa*"
        "*id_ed25519*"
        "*id_ecdsa*"
        "*/.docker/config.json"
        "*/.netrc"
        "*/.pgpass"
        "*/.git-credentials"
        "*/.config/gh/hosts.yml"
        "*/.local/share/opencode/auth.json"
        "*/.config/sops/age/*"
        "*/.config/age/*"
        "/run/agenix/*"
        "/etc/ssh/ssh_host_*"
      ])
    ++ rules "read" "allow" (templateFiles ++ ["*.pub"])
    ++ [(rule "edit" "allow" "*")]
    ++ rules "edit" "deny" secretFiles
    ++ rules "edit" "allow" templateFiles
    ++ [(rule "external_directory" "ask" "*")]
    ++ rules "external_directory" "allow" [
      "/nix/store/*"
      "/tmp/*"
      "${home}/.config/opencode/*"
      "${home}/.local/share/opencode/tool-output/*"
    ]
    ++ rules "edit" "deny" [
      "${home}/.config/opencode/*"
      "${home}/.claude/*"
    ]
    ++ rules "shell" "deny" floorShell
    ++ rules "read" "deny" floorFiles
    ++ rules "edit" "deny" floorFiles;

  mcp = {
    axon-gateway = {
      type = "remote";
      url = "https://axon.homelab.internal/mcp";
      transport = "http";
      oauth = false;
      headers.Authorization = "Bearer {env:AXON_GATEWAY_TOKEN}";
      enabled = true;
    };
    ventara-gateway = {
      type = "remote";
      url = "https://axon.int.oyabu.cc/mcp";
      transport = "http";
      oauth = false;
      headers.Authorization = "Bearer {env:VENTARA_GATEWAY_TOKEN}";
      enabled = true;
    };
    gh_grep = {
      type = "remote";
      url = "https://mcp.grep.app";
    };
    context7 = {
      type = "remote";
      url = "https://mcp.context7.com/mcp";
      headers = {
        CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
      };
    };
    # Local browser automation; same server as Claude's managed-mcp.json
    # (modules/wotan/claude-code.nix).
    playwright = {
      type = "local";
      command = [(lib.getExe pkgs.playwright-mcp) "--headless"];
      enabled = true;
    };
  };

  # The agent/model lineup (2026-11-16): GLM-5.3 supervises (default agent,
  # planning, research, review), big-pickle (the `opencode` provider)
  # implements, GLM-5.3 Flash does the rest of the high-volume work (docs,
  # code search, session metadata). No DeepSeek anywhere in the lineup. IDs
  # are verified against https://opencode.ai/docs/console/go/; big-pickle is
  # not on Go, so it needs its own `opencode` credential in auth.json (the
  # env key below only covers `opencode-go`). `compaction`
  # stays unpinned — it inherits the session model, and its summary quality
  # drives long sessions.
  supervisorModel = "opencode-go/glm-5.3";
  workerModel = "opencode-go/glm-5.3-flash";

  # Model pins for the built-in agents (same-ID overrides). Overriding
  # `build` in place keeps its built-in prompt; the supervisor role comes
  # from the model pin plus the subagent lineup below, not a rewritten
  # system prompt.
  agentModels = {
    build.model = supervisorModel;
    plan.model = supervisorModel;
    general.model = supervisorModel;
    explore.model = workerModel;
    title.model = workerModel;
    summary.model = workerModel;
  };
in {
  options.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the opencode harness config: MCP servers, TUI settings, custom commands, and the agent/model lineup (GLM-5.3 supervisor, GLM-5.3 Flash workers)";
    };

    commandsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/opencode/command";
      description = "Directory where opencode custom commands are stored";
    };

    referencesDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/.config/opencode/reference";
      description = "Directory where opencode references are stored";
    };

    goApiKeyEnvironment = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Name of an environment variable the OpenCode server reads the
        OpenCode Go API key from. When set, the generated config gets
        providers.opencode-go.settings.apiKey = "{env:<NAME>}", so the Go
        subscription authenticates declaratively (the variable comes from
        services.opencode-serve.credentialEnvironment) instead of /connect.
      '';
    };

    guardrails.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Install secret guardrails for opencode, independent of `opencode.enable`:
        a plugin that blocks tool calls touching .env files, private keys,
        credential stores and decrypt/reveal commands (and redacts
        secret-looking values from tool output), plus matching deny rules in
        the permission config (opencode.json) and a deny-floor plugin that
        mirrors Claude's deny list. See opencode-secret-guard.js for the rationale.
      '';
    };
  };

  config = lib.mkMerge [
    # Hindsight recall/retain rules (modules/agent-memory.nix). OpenCode has no
    # session hooks; it reads the global AGENTS.md next to each project's.
    {
      home.file.".config/opencode/AGENTS.md".text =
        (import ../../agent-memory.nix {
          inherit pkgs lib;
          agent = "opencode-wotan";
        }).instructions;
    }
    (lib.mkIf config.opencode.guardrails.enable {
      # Plugin = the actual enforcement. opencode loads {plugin,plugins}/*.{ts,js}
      # from the config dir (symlinks included) at startup.
      home.file.".config/opencode/plugins/secret-guard.js".source = ./opencode-secret-guard.js;

      # Same deny floor as Claude's, enforced in a plugin because a project's
      # .opencode/opencode.json loads after this config and can override its
      # permission rules; a plugin it cannot remove.
      home.file.".config/opencode/plugins/deny-floor.js".text =
        "const DENY = ${builtins.toJSON floorShell};\n" + builtins.readFile ./opencode-deny-floor.js;
    })

    # One opencode.json: the permission rules (guardrails), the MCP servers,
    # and (with opencode.enable) the agent/model lineup, compaction and
    # experimental settings. v2 reads only opencode.json(c), so a config.json
    # would be ignored.
    (lib.mkIf (config.opencode.enable || config.opencode.guardrails.enable) {
      home.file.".config/opencode/opencode.json" = {
        force = true;
        text = builtins.toJSON (
          {"$schema" = "https://opencode.ai/config.json";}
          // lib.optionalAttrs config.opencode.guardrails.enable {inherit permissions;}
          // lib.optionalAttrs config.opencode.enable {
            inherit mcp;
            # OpenCode Go authenticates with the Console API key; the agent's
            # server gets it as $OPENCODE_GO_API_KEY (services.opencode-serve.
            # credentialEnvironment) instead of a /connect entry in auth.json.
            providers = lib.optionalAttrs (config.opencode.goApiKeyEnvironment != null) {
              "opencode-go".settings.apiKey = "{env:${config.opencode.goApiKeyEnvironment}}";
            };
            # New sessions start on the supervisor's model (existing sessions
            # keep their stored one); build stays the default agent.
            model = supervisorModel;
            default_agent = "build";
            agents = agentModels;
            # The binary is Nix-managed; self-updates can never land.
            update = "disable";
            # Compact once the conversation reaches ~400k of the 1M-token
            # windows the lineup uses (buffer = the share of the window kept
            # free), keeping 20k of exact recent context beside the summary.
            compaction = {
              keep.tokens = 20000;
              buffer = "60%";
            };
            experimental = {
              # Write the compaction summary ahead of time so compaction does
              # not pause the session (experimental).
              background_compaction = true;
              # todowrite tool for multi-step delegation tracking.
              todo = true;
            };
          }
        );
      };
    })

    (lib.mkIf config.opencode.enable {
      # What `wt config plugins opencode install` would write, taken from the
      # packaged source so it matches the installed wt. Adds activity tracking
      # and worktree isolation.
      home.file.".config/opencode/plugins/worktrunk.ts".source = "${pkgs.worktrunk.src}/dev/opencode-plugin.ts";

      # v2 TUI settings. Read-only from the store, so `/settings` changes in
      # the TUI no longer persist: change them here instead.
      home.file.".config/opencode/cli.json" = {
        force = true;
        text = builtins.toJSON {
          "$schema" = "https://opencode.ai/v2/cli.json";
          theme.name = "vesper";
          diffs.wrap = "word";
          session = {
            sidebar = "auto";
            scrollbar = false;
            # The model still reasons; the transcript just does not render it.
            thinking = "hide";
            tps = true;
          };
          # Match the hidden thinking in the mini interface, and ping the
          # desktop when a turn finishes while the terminal is unfocused (a
          # silent no-op if the agent confinement hides the notification
          # daemon's session socket — herdr's state panel still shows work).
          mini.thinking = "hide";
          attention.notifications = true;
          debug.turn_tokens = true;
          animations = true;
          # No tab strip: tabs were persisted and reopened (plus a new one) on
          # every launch against the shared opencode-serve instance.
          tabs.mode = "off";
        };
      };

      # The custom subagents of the supervisor lineup (V2 markdown agents:
      # YAML frontmatter, body = the system prompt). Global, so every project
      # gets them; each project's own AGENTS.md chain still provides the
      # project context on top.
      home.file.".config/opencode/agents/implement.md".text = ''
        ---
        description: Implements well-specified coding tasks — edits, new code, tests
        mode: subagent
        model: opencode/big-pickle
        ---

        You are the implementation worker. The supervising agent handed you a task with its context and specification; land exactly that.

        - Read the AGENTS.md of the repo and of the directory you are changing first, and follow its conventions, tooling and commands.
        - Make the smallest change that satisfies the task. Do not refactor, rename or fix unrelated code.
        - Verify your work with the project's own checks (tests, linters, just recipes) where available, and report what you ran and what it said. Do not reformat code: the repo's hooks and formatters own formatting and run on their own.
        - Do not commit or push, and never read or change secrets — agenix-encrypted files, environment or credential files. If the task needs either, stop and report back instead.
        - End with a short report: files changed, verification done, anything left open.
      '';

      home.file.".config/opencode/agents/docs.md".text = ''
        ---
        description: Writes and updates documentation — READMEs, AGENTS.md, guides
        mode: subagent
        model: opencode-go/glm-5.3-flash
        ---

        You are the documentation writer.

        - Match the structure, tone and formatting of the docs that already surround your change; follow the repo's AGENTS.md conventions.
        - Write for a reader who arrives cold: what the thing is, where it lives, how to run it, and what bites.
        - Keep every claim verifiable: point at real files, commands and paths rather than paraphrasing them.
        - Touch only what the docs task needs (documents, doc comments, examples); do not commit or push, and never read or change secrets.
        - End with a short report of every file created or edited.
      '';

      home.file.".config/opencode/agents/review.md".text = ''
        ---
        description: Read-only review of a diff, branch or the current changes
        mode: subagent
        model: opencode-go/glm-5.3
        permissions:
          - action: edit
            resource: "*"
            effect: deny
        ---

        You are the reviewer. Review the changes you were given (diff, branch or working tree) for correctness, security, performance and maintainability.

        - Read-only: never edit files or run state-changing commands. Read-only shell (git diff/log/show, rg, ls) and cheap checks and tests are fine.
        - Judge the change against the repo's own conventions (its AGENTS.md), not generic taste.
        - Report findings in severity order with file and line references; say what is wrong, why, and what to do instead.
        - End with a verdict: ship, or fix these first.
      '';

      home.file."${config.opencode.commandsDir}/cc.md" = {
        text = ''
          ---
          description: Create conventional commits based on analyzed changes
          agent: build
          ---

          # Conventional Commit Analysis

          ## Git Status
          !`git status --porcelain`

          ## Staged Changes
          !`git diff --cached --name-only`

          ## Unstaged Changes
          !`git diff --name-only`

          ## Recent Commits (for context)
          !`git log --oneline -5`

          ## Analysis & Commit Strategy

          Based on the above changes, I'll analyze what has been modified and suggest appropriate conventional commits following the specification:

          ### Commit Types:
          - **feat**: New feature
          - **fix**: Bug fix
          - **docs**: Documentation changes
          - **style**: Code style changes (formatting, missing semi-colons, etc)
          - **refactor**: Code refactoring
          - **test**: Adding or updating tests
          - **chore**: Maintenance tasks, dependency updates, etc

          ### Commit Format:
          ```
          <type>[optional scope]: <description>

          [NO body]

          [NO footer(s)]
          ```

          ## Analysis Process

          1. **Categorize changes** by examining file paths and content
          2. **Group related changes** that should be committed together
          3. **Determine commit type** based on the nature of changes
          4. **Create descriptive commit messages** following conventional commit spec

          ## Staging & Commit Commands

          I'll now stage the appropriate files and create conventional commits:

          !`git add .`

          !`git commit -m "$(cat <<'EOF'
          <type>: <description>

          EOF
          )"`

          ## Verification

          !`git log --oneline -3`
        '';
      };

      # Ensure the commands directory exists
      home.file."${config.opencode.commandsDir}/.gitkeep" = {
        text = "";
      };

      # Ensure the references directory exists
      home.file."${config.opencode.referencesDir}/.gitkeep" = {
        text = "";
      };
    })
  ];
}
