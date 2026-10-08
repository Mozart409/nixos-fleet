{
  config,
  pkgs,
  lib,
  ...
}: {
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
        the permission config. See opencode-secret-guard.js for the rationale.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.opencode.guardrails.enable {
      # Plugin = the actual enforcement. opencode loads {plugin,plugins}/*.{ts,js}
      # from the config dir (symlinks included) at startup.
      home.file.".config/opencode/plugins/secret-guard.js".source = ./opencode-secret-guard.js;

      # Permission rules = belt and suspenders. opencode merges config.json,
      # then opencode.json, then opencode.jsonc (later files win), so these are
      # the baseline and can still be overridden per-file / per-project.
      # Written as literal JSON, not builtins.toJSON: attribute order is
      # significant ("last matching rule wins") and toJSON sorts keys.
      home.file.".config/opencode/config.json".text = ''
        {
          "$schema": "https://opencode.ai/config.json",
          "permission": {
            "read": {
              "*": "allow",
              "*.env": "deny",
              "*.env.*": "deny",
              "*/.env*": "deny",
              "*.envrc": "deny",
              "*.pem": "deny",
              "*.key": "deny",
              "*.p12": "deny",
              "*.pfx": "deny",
              "*id_rsa*": "deny",
              "*id_ed25519*": "deny",
              "*id_ecdsa*": "deny",
              "*/.ssh/*": "deny",
              "*/.aws/*": "deny",
              "*/.gnupg/*": "deny",
              "*/.kube/*": "deny",
              "*/.docker/config.json": "deny",
              "*/.netrc": "deny",
              "*/.pgpass": "deny",
              "*/.git-credentials": "deny",
              "*/.config/gh/hosts.yml": "deny",
              "*/.local/share/opencode/auth.json": "deny",
              "*/.config/sops/age/*": "deny",
              "*/.config/age/*": "deny",
              "/run/agenix/*": "deny",
              "/etc/ssh/ssh_host_*": "deny",
              "*credentials*": "deny",
              "*.tfstate*": "deny",
              "*.env.example": "allow",
              "*.env.sample": "allow",
              "*.env.template": "allow",
              "*.pub": "allow"
            },
            "edit": {
              "*": "allow",
              "*.env": "deny",
              "*.env.*": "deny",
              "*/.env*": "deny",
              "*.pem": "deny",
              "*.key": "deny",
              "*/.ssh/*": "deny",
              "*/.aws/*": "deny",
              "*/.gnupg/*": "deny",
              "*/.kube/*": "deny",
              "*credentials*": "deny",
              "*.tfstate*": "deny",
              "*.env.example": "allow",
              "*.env.sample": "allow",
              "*.env.template": "allow"
            },
            "bash": {
              "*": "allow",
              "* .env*": "deny",
              "*/.env*": "deny",
              "* .envrc*": "deny",
              "printenv*": "deny",
              "env": "deny",
              "env |*": "deny",
              "env >*": "deny",
              "export -p*": "deny",
              "declare -x*": "deny",
              "*agenix* -d *": "deny",
              "*agenix* --decrypt *": "deny",
              "sops -d*": "deny",
              "sops --decrypt*": "deny",
              "age -d*": "deny",
              "age --decrypt*": "deny",
              "gh auth token*": "deny",
              "op read*": "deny",
              "op item get*": "deny",
              "pass show*": "deny",
              "gpg -d*": "deny",
              "gpg --decrypt*": "deny",
              "* ~/.ssh/*": "deny",
              "* ~/.aws/*": "deny",
              "* ~/.gnupg/*": "deny",
              "* $HOME/.ssh/*": "deny",
              "* $HOME/.aws/*": "deny",
              "* /proc/*/environ*": "deny",
              "* .env.example*": "allow",

              "git *": "ask",
              "git status*": "allow",
              "git diff*": "allow",
              "git log*": "allow",
              "git show*": "allow",
              "git blame*": "allow",
              "git rev-parse*": "allow",
              "git ls-files*": "allow",
              "git grep*": "allow",
              "git branch*": "allow",
              "git switch*": "allow",
              "git fetch*": "allow",
              "git stash*": "allow",
              "git add *": "allow",
              "git commit *": "allow",

              "nix *": "ask",
              "nix build *": "allow",
              "nix eval *": "allow",
              "nix flake *": "allow",
              "nix search *": "allow",
              "nix log *": "allow",
              "nix path-info *": "allow",
              "nix why-depends *": "allow",
              "nh *": "ask",
              "nh search *": "allow",
              "nh os build*": "allow",
              "nh home build*": "allow",
              "nixos-rebuild *": "ask",
              "nixos-rebuild build*": "allow",
              "nixos-rebuild dry-build*": "allow",

              "curl *": "ask",
              "wget *": "ask",
              "curl *.homelab.internal*": "allow",
              "curl *.homelab.local*": "allow",
              "curl *localhost*": "allow",
              "curl *127.0.0.1*": "allow",
              "wget *.homelab.internal*": "allow",
              "wget *.homelab.local*": "allow",
              "wget *localhost*": "allow",
              "wget *127.0.0.1*": "allow",

              "sudo *": "deny",
              "*nixos-rebuild*switch*": "deny",
              "*nixos-rebuild*boot*": "deny",
              "*nixos-rebuild*test*": "deny",
              "*os switch*": "deny",
              "*os boot*": "deny",
              "*os test*": "deny",
              "*home switch*": "deny",
              "*home-manager*switch*": "deny",
              "*switch-to-configuration*": "deny",
              "*switch.sh*": "deny",
              "*cleanup.sh*": "deny",
              "just switch*": "deny",
              "just test*": "deny",
              "nix profile *": "deny",
              "nix-env *": "deny",
              "nh clean*": "deny",

              "git push*": "deny",
              "just sync-remotes*": "deny",
              "git *--no-verify*": "deny",
              "git commit -n*": "deny",
              "git commit * -n*": "deny",
              "git *--no-gpg-sign*": "deny",
              "git *commit.gpgsign*": "deny",
              "git *core.hooksPath*": "deny",
              "*LEFTHOOK*": "deny",
              "*GIT_CONFIG_*": "deny",
              "git reset *--hard*": "deny",
              "git clean*": "deny",
              "git checkout -- *": "deny",
              "git checkout .*": "deny",
              "git restore .*": "deny"
            }
          }
        }
      '';
    })

    (lib.mkIf config.opencode.enable {
      home.file.".config/opencode/opencode.json" = {
        force = true;
        text = builtins.toJSON {
          "$schema" = "https://opencode.ai/config.json";
          mcp = {
            axon-gateway = {
              type = "remote";
              url = "https://axon.homelab.local/mcp";
              transport = "http";
              oauth = false;
              headers.Authorization = "Bearer {env:AXON_GATEWAY_TOKEN}";
              enabled = true;
            };
            ventara-gateway = {
              type = "remote";
              url = "https://ventara-vm01.dropbear-butterfly.ts.net:8093/mcp";
              transport = "http";
              oauth = false;
              headers.Authorization = "Bearer {env:VENTARA_GATEWAY_TOKEN}";
              enabled = true;
            };
            homeassistant = {
              type = "remote";
              url = "https://mcp.homelab.local/mcp";
              enabled = false;
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
          plugin = ["context-mode"];
          references = {
            "context-mode" = {
              path = "${config.opencode.referencesDir}/context-mode.md";
              description = "Rules and instructions for context-mode";
            };
          };
        };
      };

      home.file."${config.opencode.referencesDir}/context-mode.md" = {
        text = ''
                  # context-mode — MANDATORY routing rules

          context-mode MCP tools available. Rules protect context window from flooding. One unrouted command dumps 56 KB into context.

          ## Think in Code — MANDATORY

          Analyze/count/filter/compare/search/parse/transform data: **write code** via `context-mode_ctx_execute(language, code)`, `console.log()` only the answer. Do NOT read raw data into context. PROGRAM the analysis, not COMPUTE it. Pure JavaScript — Node.js built-ins only (`fs`, `path`, `child_process`). `try/catch`, handle `null`/`undefined`. One script replaces ten tool calls.

          ## BLOCKED — do NOT attempt

          ### curl / wget — BLOCKED
          Shell `curl`/`wget` intercepted and blocked. Do NOT retry.
          Use: `context-mode_ctx_fetch_and_index(url, source)` or `context-mode_ctx_execute(language: "javascript", code: "const r = await fetch(...)")`

          ### Inline HTTP — BLOCKED
          `fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(` — intercepted. Do NOT retry.
          Use: `context-mode_ctx_execute(language, code)` — only stdout enters context

          ### Direct web fetching — BLOCKED
          Use: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)`

          ## REDIRECTED — use sandbox

          ### Shell (>20 lines output)
          Shell ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`.
          Otherwise: `context-mode_ctx_batch_execute(commands, queries)` or `context-mode_ctx_execute(language: "javascript", code: "...")`. Use `language: "shell"` only when code matches the host shell.

          ### File reading (for analysis)
          Reading to **edit** → reading correct. Reading to **analyze/explore/summarize** → `context-mode_ctx_execute_file(path, language, code)`.

          ### grep / search (large results)
          Use `context-mode_ctx_execute(language: "javascript", code: "...")` in sandbox for portable filtering/counting.

          ## Tool selection

          0. **MEMORY**: `context-mode_ctx_search(sort: "timeline")` — after resume, check prior context before asking user.
          1. **GATHER**: `context-mode_ctx_batch_execute(commands, queries)` — runs all commands, auto-indexes, returns search. ONE call replaces 30+. Each command: `{label: "header", command: "..."}`.
          2. **FOLLOW-UP**: `context-mode_ctx_search(queries: ["q1", "q2", ...])` — all questions as array, ONE call (default relevance mode).
          3. **PROCESSING**: `context-mode_ctx_execute(language, code)` | `context-mode_ctx_execute_file(path, language, code)` — sandbox, only stdout enters context.
          4. **WEB**: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` — raw HTML never enters context.
          5. **INDEX**: `context-mode_ctx_index(content, source)` — store in FTS5 for later search.

          ## Parallel I/O batches

          For multi-URL fetches or multi-API calls, **always** include `concurrency: N` (1-8):

          - `context-mode_ctx_batch_execute(commands: [3+ network commands], concurrency: 5)` — gh, curl, dig, docker inspect, multi-region cloud queries
          - `context-mode_ctx_fetch_and_index(requests: [{url, source}, ...], concurrency: 5)` — multi-URL batch fetch

          **Use concurrency 4-8** for I/O-bound work (network calls, API queries). **Keep concurrency 1** for CPU-bound (npm test, build, lint) or commands sharing state (ports, lock files, same-repo writes).

          GitHub API rate-limit: cap at 4 for `gh` calls.

          ## Output

          Write artifacts to FILES — never inline. Return: file path + 1-line description.
          Descriptive source labels for `search(source: "label")`.

          ## Session Continuity

          Skills, roles, and decisions persist for the entire session. Do not abandon them as the conversation grows.

          ## Memory

          Session history is persistent and searchable. On resume, search BEFORE asking the user:

          | Need | Command |
          |------|---------|
          | What did we decide? | `context-mode_ctx_search(queries: ["decision"], source: "decision", sort: "timeline")` |
          | What constraints exist? | `context-mode_ctx_search(queries: ["constraint"], source: "constraint")` |

          DO NOT ask "what were we working on?" — SEARCH FIRST.
          If search returns 0 results, proceed as a fresh session.

          ## ctx commands

          | Command | Action |
          |---------|--------|
          | `ctx stats` | Call `stats` MCP tool, display full output verbatim |
          | `ctx doctor` | Call `doctor` MCP tool, run returned shell command, display as checklist |
          | `ctx upgrade` | Call `upgrade` MCP tool, run returned shell command, display as checklist |
          | `ctx purge` | Call `purge` MCP tool with confirm: true. Warns before wiping knowledge base. |

          After /clear or /compact: knowledge base and session stats preserved. Use `ctx purge` to start fresh.
        '';
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
