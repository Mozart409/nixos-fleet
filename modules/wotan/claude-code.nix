{
  config,
  lib,
  ...
}: {
  options.programs.claudeCodeMcp.enable =
    lib.mkEnableOption "system-managed MCP servers for Claude Code (/etc/claude-code/managed-mcp.json)";

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
  # hosts/wotan/default.nix (age.secrets.axon-gateway-env) — so launch `claude`
  # from a login shell for the token to resolve.
  config = lib.mkIf config.programs.claudeCodeMcp.enable {
    environment.etc."claude-code/managed-mcp.json".text = builtins.toJSON {
      mcpServers = {
        axon-gateway = {
          type = "http";
          url = "https://axon.homelab.local/mcp";
          headers.Authorization = "Bearer \${AXON_GATEWAY_TOKEN}";
        };
      };
    };
  };
}
