# Config for autolith (github:lambda-symbolics/autolith, the `autolith` flake
# input, package `inputs.autolith.packages.<system>.default`), the fourth
# harness running as `agent` (modules/wotan/agent-user.nix). Mirrors the MCP
# gateway entries of pi.nix / opencode.nix: autolith reads them from
# ~/.config/autolith/mcp.sexp, and a header takes its value from an environment
# variable, so the token still comes from the environment (agent-run exports
# the gateway tokens into every session) and nothing secret lands in the store.
# See docs/mcp.org in the autolith source for the format.
{
  config,
  lib,
  ...
}: {
  options.autolith = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable autolith configuration (MCP gateways)";
    };
  };

  config = lib.mkIf config.autolith.enable {
    # autolith stores its durable preferences in the same directory
    # (preferences.sexp, rewritten from inside sessions), so only this file and
    # nothing else is managed here: a store symlink cannot be rewritten by the
    # agent. The credentials `autolith auth <provider>` saves stay in its
    # private store under ~/.local/state/autolith.
    #
    # An HTTP header value must be the complete value the server expects, so
    # the "Bearer " prefix is not in this file: agent-run derives
    # AUTOLITH_MCP_AXON / AUTOLITH_MCP_VENTARA from the gateway tokens
    # (modules/wotan/agent-user.nix, inner).
    #
    # :required-p nil keeps a gateway outage from failing startup; the server
    # stays listed as failed and `mcp refresh` retries it.
    home.file.".config/autolith/mcp.sexp".text = ''
      (:version 1
       :servers
       ((:name "axon-gateway"
         :transport
         (:type :http
          :url "https://axon.homelab.internal/mcp"
          :headers (("Authorization" :environment "AUTOLITH_MCP_AXON")))
         :required-p nil
         :approval :prompt)
        (:name "ventara-gateway"
         :transport
         (:type :http
          :url "https://axon.int.oyabu.cc/mcp"
          :headers (("Authorization" :environment "AUTOLITH_MCP_VENTARA")))
         :required-p nil
         :approval :prompt)))
    '';
  };
}
