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
              "curl *.homelab.internal*": "allow",
              "curl *localhost*": "allow",
              "curl *127.0.0.1*": "allow",
              "wget *.homelab.internal*": "allow",
              "wget *.homelab.internal*": "allow",
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
        };
      };

      # v2 TUI settings. Read-only from the store, so `/settings` changes in
      # the TUI no longer persist: change them here instead.
      home.file.".config/opencode/cli.json" = {
        force = true;
        text = builtins.toJSON {
          "$schema" = "https://opencode.ai/v2/cli.json";
          theme.name = "osaka-jade";
          diffs.wrap = "word";
          session = {
            sidebar = "auto";
            scrollbar = false;
            thinking = "show";
          };
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
