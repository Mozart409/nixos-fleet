{
  config,
  lib,
  pkgs,
  ...
}: {
  options.programs.claudeCodeMcp.enable =
    lib.mkEnableOption "system-managed Claude Code config: MCP servers and the sandbox pin (/etc/claude-code)";

  # Managed MCP servers for Claude Code (system-wide).
  #
  # Unlike opencode (whose MCP list lives in the user's config), Claude Code does
  # NOT read MCP server definitions from ~/.claude/settings.json. On Linux it
  # reads system-managed MCP servers from /etc/claude-code/managed-mcp.json.
  # Managed entries are enforced and cannot be removed from within a session.
  #
  # The Authorization bearer token is expanded from the AXON_GATEWAY_TOKEN
  # environment variable at connection time (Claude Code expands ${VAR} in MCP
  # config). That variable is exported into the user's shell from an agenix
  # secret — see hosts/wotan/home.nix (sessionVariablesExtra) and
  # hosts/wotan/default.nix (age.secrets.axon-token-wotan) — so launch `claude`
  # from a login shell for the token to resolve.
  config = lib.mkIf config.programs.claudeCodeMcp.enable {
    # mode: a real file instead of a link into /etc/static, which Claude warns
    # about because it leads outside /etc/claude-code.
    environment.etc."claude-code/managed-mcp.json" = {
      mode = "0444";
      text = builtins.toJSON {
        mcpServers = {
          axon-gateway = {
            type = "http";
            url = "https://axon.homelab.internal/mcp";
            headers.Authorization = "Bearer \${AXON_GATEWAY_TOKEN}";
          };
          # nixos-ventara-ai's own axon-gateway; token from
          # age.secrets.ventara-gateway-env (VENTARA_GATEWAY_TOKEN).
          ventara-gateway = {
            type = "http";
            url = "https://axon.int.oyabu.cc/mcp";
            headers.Authorization = "Bearer \${VENTARA_GATEWAY_TOKEN}";
          };
          # Local browser automation. nixpkgs' wrapper pins Chromium from
          # playwright-driver.browsers and runs isolated (no persistent profile).
          playwright = {
            type = "stdio";
            command = lib.getExe pkgs.playwright-mcp;
            args = ["--headless"];
          };
        };
      };
    };

    # Managed settings beat every other scope. Without the pin, a project's
    # .claude/settings.local.json, which the agent can write, could set
    # sandbox.enabled = false over modules/home/packages/claude.nix. Sandboxed
    # Bash still goes through the permission rules instead of being auto-allowed.
    environment.etc."claude-code/managed-settings.json" = {
      mode = "0444";
      text = builtins.toJSON {
        sandbox = {
          enabled = true;
          autoAllowBashIfSandboxed = false;
        };
      };
    };
  };
}
