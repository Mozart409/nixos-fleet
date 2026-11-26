# Domain data shared by agent-user.nix's agent-proxy and the agent VMs'
# avm-egress (agent-egress.nix). Plain data, not a module. Patterns mean the
# same in both: an exact name, or `*.suffix` for any depth below it (never the
# apex). `internal` entries are names that resolve into private ranges: their
# cidrs are the only private addresses the name may answer with. This tree is
# public, so only public names belong here.
let
  hosts = (import ../../lib/hosts.nix).hosts;
in {
  groups = {
    # Claude Code's telemetry intake (http-intake.logs.us5.datadoghq.com)
    # stays off on purpose.
    model = {
      allow = ["api.anthropic.com" "opencode.ai" "models.opencode.ai"];
      internal = [];
    };
    mcp = {
      allow = ["mcp.context7.com" "mcp.grep.app"];
      internal = [
        {
          name = "axon.homelab.internal";
          cidrs = ["${hosts.mcp.ip}/32" "${hosts.mcp.overlay}/32"];
        }
      ];
    };
    rust = {
      allow = ["crates.io" "index.crates.io" "static.crates.io" "static.rust-lang.org" "docs.rs"];
      internal = [];
    };
    git = {
      allow = ["github.com" "*.github.com" "*.githubusercontent.com"];
      internal = [];
    };
    nix = {
      allow = ["cache.nixos.org" "channels.nixos.org" "nixos.org" "search.nixos.org"];
      internal = [];
    };
    npm = {
      allow = ["registry.npmjs.org"];
      internal = [];
    };
    python = {
      allow = ["pypi.org" "files.pythonhosted.org"];
      internal = [];
    };
    go = {
      allow = ["proxy.golang.org" "sum.golang.org"];
      internal = [];
    };
    hex = {
      allow = ["hex.pm" "repo.hex.pm" "builds.hex.pm"];
      internal = [];
    };
  };
}
