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
  };

  config = lib.mkIf config.opencode.enable {
    home.file.".config/opencode/opencode.json" = {
      text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        provider = {
          "llama.cpp" = {
            npm = "@ai-sdk/openai-compatible";
            name = "llama-server (local)";
            options = {
              baseURL = "http://127.0.0.1:10808/v1";
            };
            models = {
              "ibm-granite_granite-4.0-h-tiny-Q4_K_M" = {
                name = "IBM Granite 4.0 H-Tiny (7B MoE)";
                limit = {
                  context = 131072;
                  output = 65536;
                };
              };
              "Qwen_Qwen3-4B-Thinking-2507-Q4_K_M" = {
                name = "Qwen3-4B-Thinking-2507";
                limit = {
                  context = 131072;
                  output = 32768;
                };
              };
            };
          };
        };
        mcp = {
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
          playwright = {
            type = "local";
            command = [
              "npx"
              "@playwright/mcp@latest"
            ];
            enabled = true;
          };
        };
      };
    };

    home.file."${config.opencode.commandsDir}/cc.md" = {
      text = ''
        ---
        description: Create conventional commits based on analyzed changes
        agent: build
        model: opencode/kimi-k2-thinking
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

        [optional body]

        [optional footer(s)]
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
  };
}
