{
  config,
  lib,
  ...
}: {
  options.autolith.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the Autolith harness config: the axon-gateway MCP registration";
  };

  config = lib.mkIf config.autolith.enable {
    # Autolith runs as the agent account via `agent-run autolith`
    # (modules/wotan/agent-user.nix). Only the axon-gateway is registered,
    # with the whole-server :allow that Claude Code and opencode grant it in
    # managed-mcp.json / opencode.json; :prompt would ask per call instead.
    # Child agents (channels, councils) get no gateway tools: :child-tools
    # stays unset, and autolith only passes a child a tool when that list
    # names its exact raw name.
    #
    # mcparen, which parses mcp.sexp, maps a header from an env variable but
    # expects the FULL value ("Bearer ..."): no templating, unlike Claude
    # Code's managed-mcp.json or opencode's {env:VAR}. agent-run-inner
    # derives AUTOLITH_MCP_AUTHORIZATION from the raw AXON_GATEWAY_TOKEN
    # credential, so the token never lands in a file. The step-ca root is in
    # the system store (security.pki.certificates in hosts/wotan/default.nix),
    # which the TLS stack picks up for axon.homelab.internal.
    #
    # Network posture: autolith's command sandbox is upstream-pinned to
    # :isolated (cl-exec-sandbox: no network, host read-only), stricter than
    # the other harnesses' agent-proxy path and with no setting to change the
    # mode; the harness process itself reaches the gateway directly through
    # wotan.agentUser.network.allow, like the other harnesses' MCP traffic.
    # A proxied command sandbox would need cl-exec-sandbox's :proxy-only
    # mode, which autolith does not expose.
    xdg.configFile."autolith/mcp.sexp".text = ''
      (:version 1
       :servers
       ((:name "axon-gateway"
         :transport
         (:type :http
          :url "https://axon.homelab.internal/mcp"
          :headers
          (("Authorization" :environment "AUTOLITH_MCP_AUTHORIZATION")))
         :approval :allow
         :required-p nil))
    '';
  };
}
