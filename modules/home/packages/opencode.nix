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

  readOnlyShell = [
    "cd *"
    "ls *"
    "cat *"
    "head *"
    "tail *"
    "wc *"
    "pwd"
    "which *"
    "file *"
    "stat *"
    "rg *"
    "grep *"
    "tree *"
    "echo *"
    "sort *"
    "uniq *"
    "cut *"
    "true"
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
  };
in {
  options.opencode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable opencode custom commands configuration";
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

    # One opencode.json: the permission rules (guardrails) and the MCP servers.
    # v2 reads only opencode.json(c), so a config.json would be ignored.
    (lib.mkIf (config.opencode.enable || config.opencode.guardrails.enable) {
      home.file.".config/opencode/opencode.json" = {
        force = true;
        text = builtins.toJSON (
          {"$schema" = "https://opencode.ai/config.json";}
          // lib.optionalAttrs config.opencode.guardrails.enable {inherit permissions;}
          // lib.optionalAttrs config.opencode.enable {inherit mcp;}
        );
      };
    })

    (lib.mkIf config.opencode.enable {
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
            thinking = "show";
            tps = true;
          };
          debug.turn_tokens = true;
          animations = true;
          # No tab strip: tabs were persisted and reopened (plus a new one) on
          # every launch against the shared opencode-serve instance.
          tabs.mode = "off";
        };
      };

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
