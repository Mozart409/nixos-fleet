# Config for pi (docs at https://pi-ai.github.io/pi, package pi-coding-agent),
# the third harness running as `agent` (modules/wotan/agent-user.nix). Mirrors
# the MCP gateway entries from opencode.nix / coding-harness.nix: pi reads
# user-level servers from ~/.pi/agent/mcp.json and expands ${VAR} references
# at launch, so the token still comes from the environment (agent-run's
# LoadCredential exports AXON_GATEWAY_TOKEN into every pi session) — nothing
# secret is baked into the store. See docs/mcp.md in the pi source for the
# format.
{
  config,
  lib,
  ...
}: {
  options.pi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable pi configuration (MCP gateways)";
    };
  };

  config = lib.mkIf config.pi.enable {
    # pi writes exposure/enable changes back to mcp.json from inside sessions
    # (/mcp), so update gateway entries here rather than via `pi mcp add` —
    # a store symlink cannot be rewritten by pi. The file must stay plain JSON
    # (pi parses it directly, no jq merge anywhere downstream), so any prose
    # lives here instead of in the text.
    #
    # ventara-gateway is the Ventara deployment's own axon-gateway instance
    # (nixos-ventara-ai repo): a separate gateway aggregating THAT repo's
    # backends, not on the homelab LAN. Its token flows through the
    # VENTARA_GATEWAY_TOKEN credential instead (modules/coding-harness.nix
    # documents why the two env var names must not collide). Matches
    # opencode.nix: component parity across the three harnesses.
    home.file.".pi/agent/mcp.json".text = ''
      {
        "mcpServers": {
          "axon-gateway": {
            "url": "https://axon.homelab.internal/mcp",
            "headers": {
              "Authorization": "Bearer $${AXON_GATEWAY_TOKEN}"
            },
            "description": "Self-hosted gateway aggregating the homelab fleet's MCP servers into one endpoint; tools are prefixed with their backend name"
          },
          "ventara-gateway": {
            "url": "https://axon.int.oyabu.cc/mcp",
            "headers": {
              "Authorization": "Bearer $${VENTARA_GATEWAY_TOKEN}"
            },
            "description": "The Ventara deployment's separate axon-gateway instance, aggregating that deployment's own MCP backends (Prometheus, Loki, the internal dashboard)"
          }
        }
      }
    '';
  };
}
