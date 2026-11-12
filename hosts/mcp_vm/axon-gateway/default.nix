{
  config,
  lib,
  pkgs,
  ...
}: let
  # axon-gateway: high-performance MCP gateway that aggregates multiple MCP
  # servers behind a single endpoint. https://github.com/Mozart409/axon-gateway
  #
  # Lives on the mcp host since 2026-09-14 (it ran on `containers` before).
  # The move is a security fix, not a tidy-up: the MCP servers it aggregates
  # bind loopback on this host, and putting the gateway on the same box is
  # what lets them stay there. Before, each backend had a public Caddy vhost
  # with no authentication so the gateway could reach it from another VM --
  # which meant anyone on the LAN could reach it too and skip the gateway's
  # bearer token altogether.
  #
  # Deployed as an OCI container (rootful podman, modules/podman.nix) because
  # the published image bundles the Rust binary with its static UI assets.
  # It runs with HOST networking: that is the only way a container can dial
  # 127.0.0.1:<port> services on the host, and it is why `bind` below is a
  # loopback address rather than 0.0.0.0 -- with host networking there is no
  # port mapping to hide behind, whatever the container binds is what the
  # host listens on. Only Caddy (vhosts below) is meant to talk to it.
  #
  # DATABASE MODE. The gateway runs in database mode (new axon release): it is
  # started with no config file, and its runtime configuration -- backends,
  # toolsets, settings, users and service accounts -- lives in the `axon`
  # database on the database host and is managed in the dashboard (/ui/admin).
  # Only what is needed to boot comes from the environment: the database URL
  # (database.env, built at start from axon-db-password.age), the bind
  # address, the base URL, the KEK that seals stored secrets, and the Pocket ID
  # bootstrap provider. Callers no longer share one bearer token: people log in
  # through Pocket ID, agents use service-account tokens (PATs).
  #
  # The old rendered TOML survives only as a ONE-TIME IMPORT FILE
  # (/etc/axon-gateway/import.toml, below). After the first import the
  # database is the source of truth: edit backends in the dashboard, not here,
  # and treat later edits to the import file as a re-import you run by hand
  # (`sudo axon-import-config`, which creates what is missing and updates what
  # differs, and removes nothing).
  gatewayPort = 8100;

  # The first axon release that has database mode. It is NOT published yet
  # (the last tag, v0.4.2, is standalone only): until the tag exists, the pull
  # fails and the unit stays down, so set it to the real tag before deploying.
  axonImage = "ghcr.io/mozart409/axon-gateway:v0.5.1";

  # Public client id of the Pocket ID OIDC client for the gateway (redirect URI
  # https://axon.homelab.internal/auth/callback). Not a secret; its secret is
  # axon-oidc-client-secret.age.
  oidcClientId = "a48e3829-d7d8-457e-94c4-c5947acff247";
  # Same issuer as forgejo / grafana / romm / hindsight (hosts/containers/pocket-id).
  oidcIssuer = "https://pocketid.homelab.internal";

  # The one-time import file: the config the gateway ran on in standalone mode,
  # read once by `axon-gateway admin import-config` (see `axon-import-config`
  # below). Secrets are NOT inlined here — they are referenced as ${VAR}
  # placeholders, which the import resolves from the container's environment
  # (a missing referenced var is a hard error). The only one left is
  # HINDSIGHT_API_KEY, which generateEnv writes from hindsight-api-key.age.
  #
  # Not imported, by design: [gateway] bind and base_url are environment-only
  # now (AXON_BIND, AXON_BASE_URL on the container), and auth_token is gone --
  # database mode refuses the shared token for MCP clients, so every agent
  # needs a service account (the [[tokens]] section below).
  #
  # Backend ports are the `bind` values in ../configuration.nix's
  # services.homelab-mcp.servers -- keep the two in step.
  # Every backend in configText: the desktop's service account gets them all.
  agentBackends = [
    "alertmanager"
    "forgejo"
    "hamcp"
    "hindsight"
    "loki"
    "pbs"
    "pgappdb"
    "pgforgejo"
    "pghofvarpnir"
    "pgromm"
    "pgterraform"
    "prom"
    "tempo"
  ];

  configText = ''
    [gateway]
    bind = "127.0.0.1:${toString gatewayPort}"
    base_url = "https://axon.homelab.internal"
    rate_limit_per_minute = 1000
    # The MCP endpoints check the Host header (from Phase 4a); base_url's host
    # is always allowed, the .local vhost alias below has to be listed. Older
    # builds ignore the key.
    allowed_hosts = ["axon.homelab.local"]

    # --- Service accounts for the agent clients --------------------------------
    # One [[tokens]] entry per consumer of the old shared AXON_GATEWAY_TOKEN
    # (axon-gateway-env.age). The import turns each into a service account of
    # that name and mints it a fresh PAT, printed ONCE on stdout; `token` below
    # is a required field of the file format but is ignored (and not secret).
    # allowed_backends/allowed_tools are not imported either: what a service
    # account may call comes from its groups (RBAC), declared right below.
    #
    #   alertmanager-bridge  hosts/otel/alertmanager-axon-bridge.py, via
    #                        hosts/otel/alerting.nix
    #   wotan                Claude Code / opencode MCP config and shell
    #                        (modules/wotan/claude-code.nix,
    #                        modules/home/packages/opencode.nix, opencode-serve,
    #                        the agent-user wrapper)
    #
    # The harness modules (modules/coding-harness.nix, claude-settings-verify.nix)
    # read the same token, but only retired hosts import them today; give them
    # an entry here if a harness host comes back.
    [[tokens]]
    name = "alertmanager-bridge"
    token = "unused-minted-on-import"

    [[tokens]]
    name = "wotan"
    token = "unused-minted-on-import"

    # RBAC for the two service accounts. The bridge only sends Home Assistant
    # notifications (hamcp_call_service); the desktop keeps every backend it
    # reached with the shared token.
    [[rbac.groups]]
    name = "alerting"
    description = "Alertmanager bridge"
    service_accounts = ["alertmanager-bridge"]

    [[rbac.grants]]
    group = "alerting"
    backend = "hamcp"

    [[rbac.groups]]
    name = "agents"
    description = "Coding agents on the desktop"
    service_accounts = ["wotan"]
    ${lib.concatMapStrings (backend: ''

        [[rbac.grants]]
        group = "agents"
        backend = "${backend}"
      '')
      agentBackends}

    # --- Backends (the MCP servers being aggregated) -------------------------
    # All on this host's loopback; plain HTTP is fine, nothing leaves the box.

    [[backends]]
    name = "hamcp"
    url = "http://127.0.0.1:8084/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "pbs"
    url = "http://127.0.0.1:8080/mcp"
    transport = "http"
    enabled = true

    # Postgres: one backend per database. pgmcp holds a single connection pool
    # from one URL and no tool takes a database argument, so each database needs
    # its own server instance (see ../configuration.nix). The backend name
    # prefixes the tool names — pgappdb_run_query, pgforgejo_run_query, …
    # (pguptime, for the uptime-forge TimescaleDB, was retired 2026-09-12.)
    [[backends]]
    name = "pgappdb"
    url = "http://127.0.0.1:8085/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "pgterraform"
    url = "http://127.0.0.1:8087/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "pgforgejo"
    url = "http://127.0.0.1:8088/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "pgromm"
    url = "http://127.0.0.1:8089/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "pghofvarpnir"
    url = "http://127.0.0.1:8090/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "prom"
    url = "http://127.0.0.1:8082/mcp"
    transport = "http"
    enabled = true

    [[backends]]
    name = "loki"
    url = "http://127.0.0.1:8083/mcp"
    transport = "http"
    enabled = true

    # Tools land as tempo_search / tempo_trace / ... The RED-metrics view of
    # these same spans is already in prometheus (tempo's metrics-generator
    # remote-writes span-metrics and service-graph series), so prom_query
    # answers rates and latencies; this is for individual traces and TraceQL.
    [[backends]]
    name = "tempo"
    url = "http://127.0.0.1:8092/mcp"
    transport = "http"
    enabled = true

    # forgejo-mcp from nixpkgs (a plain unit in ../configuration.nix, not a
    # homelab-mcp-servers instance); it carries its own Forgejo token.
    #
    # The token only has read/write for repository and issue data, but the
    # forgejo-mcp surface is much wider. Restrict it to the repo, issue, pull,
    # tracking, attachment, release and wiki tools (plus search_repos and the
    # version probe), so org/team admin, Actions secrets and workflows,
    # webhooks, packages and notifications never appear. Merge stays out even
    # though it is a pull tool: that is the user's call. Branch protection is
    # its own tool group and is left out entirely; the rules on yggdrasil are
    # the backstop, not something agents operate.
    #
    # This is an exact-name allowlist (axon's backend filter has no globs), so
    # a forgejo-mcp upgrade that adds tools needs this list updated too.
    [[backends]]
    name = "forgejo"
    url = "http://127.0.0.1:8093/mcp"
    transport = "http"
    allowed_tools = [
      # repo
      "add_repo_topic",
      "change_files",
      "create_branch",
      "create_file",
      "create_repo",
      "delete_branch",
      "delete_file",
      "delete_repo_topic",
      "edit_repo",
      "fork_repo",
      "get_commit_statuses",
      "get_file_content",
      "get_repo",
      "get_repo_tree",
      "list_branches",
      "list_my_repos",
      "list_repo_commits",
      "list_repo_contents",
      "list_repo_topics",
      "set_repo_topics",
      "update_file",
      # issue
      "add_issue_dependency",
      "add_issue_labels",
      "create_issue",
      "create_issue_comment",
      "create_org_label",
      "create_repo_label",
      "delete_issue_comment",
      "delete_org_label",
      "delete_repo_label",
      "edit_issue_comment",
      "edit_org_label",
      "edit_repo_label",
      "get_issue_by_index",
      "get_issue_comment",
      "get_org_label",
      "get_repo_label",
      "issue_state_change",
      "list_issue_comments",
      "list_issue_dependencies",
      "list_issue_dependents",
      "list_org_labels",
      "list_repo_issues",
      "list_repo_labels",
      "list_repo_milestones",
      "remove_issue_dependency",
      "remove_issue_labels",
      "search_issues",
      "update_issue",
      # pull (merge_pull_request deliberately omitted)
      "create_pull_request",
      "create_pull_review",
      "create_review_requests",
      "delete_pull_review",
      "delete_review_requests",
      "dismiss_pull_review",
      "get_pull_request_by_index",
      "get_pull_request_diff",
      "get_pull_review",
      "list_pull_request_files",
      "list_pull_review_comments",
      "list_pull_reviews",
      "list_repo_pull_requests",
      "submit_pull_review",
      "update_pull_request",
      # tracking
      "add_issue_time",
      "cancel_issue_stopwatch",
      "delete_issue_time_entry",
      "list_issue_tracked_times",
      "list_my_stopwatches",
      "list_my_tracked_times",
      "list_repo_tracked_times",
      "reset_issue_time",
      "start_issue_stopwatch",
      "stop_issue_stopwatch",
      # attachment
      "create_comment_attachment",
      "create_issue_attachment",
      "delete_comment_attachment",
      "delete_issue_attachment",
      "download_comment_attachment",
      "download_issue_attachment",
      "edit_comment_attachment",
      "edit_issue_attachment",
      "get_comment_attachment",
      "get_issue_attachment",
      "list_comment_attachments",
      "list_issue_attachments",
      # release
      "create_release",
      "create_release_attachment",
      "delete_release",
      "delete_release_attachment",
      "delete_release_by_tag",
      "download_release_attachment",
      "edit_release",
      "edit_release_attachment",
      "get_latest_release",
      "get_release_attachment",
      "get_release_by_id",
      "get_release_by_tag",
      "list_release_attachments",
      "list_releases",
      # wiki
      "create_wiki_page",
      "delete_wiki_page",
      "get_wiki_page",
      "get_wiki_revisions",
      "list_wiki_pages",
      "update_wiki_page",
      # search/version
      "search_repos",
      "get_forgejo_mcp_server_version",
    ]
    enabled = true

    [[backends]]
    name = "alertmanager"
    url = "http://127.0.0.1:8086/mcp"
    transport = "http"
    enabled = true

    # Hindsight on the containers host: the shared agent memory, bank
    # `homelab`. The only backend that is not on this host, so the only one
    # over TLS (step-ca, trusted through the mounted CA bundle). The tenant
    # key is forwarded as Bearer. Read and write only: clear_memories,
    # delete_bank, delete_document and the mental-model/directive writers stay
    # out of every agent's reach; bank admin goes through the Control Plane.
    # Every token gets it (no [[tokens]] restriction), decided 2026-10-14.
    [[backends]]
    name = "hindsight"
    url = "https://hindsight.homelab.internal/mcp/homelab/"
    transport = "http"
    auth_token = "''${HINDSIGHT_API_KEY}"
    allowed_tools = ["retain", "recall", "reflect", "list_memories", "get_memory"]
    # retain and reflect wait on an LLM call.
    timeout_secs = 120
    enabled = true
  '';

  # Two env files, built from raw agenix secrets at every start:
  # - hindsight.env: the Hindsight key is the raw tenant key shared with the
  #   containers host; the import resolves ${HINDSIGHT_API_KEY} from it.
  # - database.env: AXON_DATABASE_URL around the raw `axon` role password
  #   (shared with the database host). Same URL shape as hindsight's on the
  #   containers host: `verify-full` against the step-ca root, passed as
  #   sslrootcert because sqlx verifies against bundled Mozilla roots and would
  #   otherwise reject the step-ca leaf (see the PGSSLROOTCERT note in
  #   ../configuration.nix). The database host only accepts hostssl.
  generateEnv = pkgs.writeShellScript "generate-axon-env" ''
    set -eu
    mkdir -p /run/axon-gateway
    umask 077
    printf 'HINDSIGHT_API_KEY=%s\n' "$(cat ${config.age.secrets.hindsight-api-key.path})" \
      > /run/axon-gateway/hindsight.env
    pw=$(cat ${config.age.secrets.axon-db-password.path})
    printf 'AXON_DATABASE_URL=postgres://axon:%s@database.homelab.internal:5432/axon?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt\n' "$pw" \
      > /run/axon-gateway/database.env
  '';

  # Runs the one-time import inside the running container, where the database
  # URL, the KEK and HINDSIGHT_API_KEY are already in the environment:
  #   sudo axon-import-config --dry-run   # report only, writes nothing
  #   sudo axon-import-config             # for real
  # A real run prints the new service-account tokens (name<TAB>axon_pat_...) ONCE
  # on stdout; the summary and warnings go to stderr. Capture them straight
  # away -- they cannot be read back -- and store each as an agenix secret for
  # its consumer (`KEY=value` env files for the ones that load an
  # EnvironmentFile, like axon-gateway-env.age did). Tokens expire after 365 days.
  axonImportConfig = pkgs.writeShellScriptBin "axon-import-config" ''
    exec ${pkgs.podman}/bin/podman exec axon-gateway /usr/local/bin/axon-gateway admin import-config /app/import.toml "$@"
  '';

  gatewayVhost = ''
    handle {
      # 127.0.0.1, never "localhost": Caddy resolves proxy upstreams through
      # the system resolver, and a `localhost` lookup here has timed out
      # against unbound ("dial tcp: lookup localhost: i/o timeout" -> 502 or a
      # hung request). A literal IP is dialed directly, with no DNS at all.
      reverse_proxy http://127.0.0.1:${toString gatewayPort}
    }
  '';
in {
  environment.etc."axon-gateway/import.toml".text = configText;

  environment.systemPackages = [axonImportConfig];

  virtualisation.oci-containers.containers = {
    axon-gateway = {
      image = axonImage;
      autoStart = true;
      volumes = [
        # The one-time import file, only read by `axon-import-config`.
        "/etc/axon-gateway/import.toml:/app/import.toml:ro"
        # The KEK and the Pocket ID client secret, as files (the container runs
        # as uid 65532; the agenix files below are owned by it).
        "${config.age.secrets.axon-kek.path}:/run/secrets/axon-kek:ro"
        "${config.age.secrets.axon-oidc-client-secret.path}:/run/secrets/axon-oidc-client-secret:ro"
        # step-ca root for anything the gateway dials over TLS: the hindsight
        # backend, and base_url/health checks.
        "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
      ];
      # No config path: that is what selects database mode (a path is an error
      # there). The image ENTRYPOINT is the binary.
      cmd = [];
      environment = {
        RUST_LOG = "info";
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        # No CONFIG_HASH restart nonce any more: the runtime config is in the
        # database and every change applies live. Only the secret files below
        # need a restart on rotation (restartTriggers on the unit).
        AXON_BIND = "127.0.0.1:${toString gatewayPort}";
        AXON_BASE_URL = "https://axon.homelab.internal";
        AXON_KEK_FILE = "/run/secrets/axon-kek";
        # AXON_ALLOW_STDIO stays unset: stdio backends would run commands inside
        # the container, and every backend here is HTTP.
        AXON_OIDC_ISSUER = oidcIssuer;
        AXON_OIDC_CLIENT_ID = oidcClientId;
        AXON_OIDC_CLIENT_SECRET_FILE = "/run/secrets/axon-oidc-client-secret";
        # Members of this Pocket ID group are gateway admins.
        AXON_OIDC_ADMIN_GROUPS = "axon-admins";
        AXON_OIDC_DISPLAY_NAME = "Pocket ID";
      };
      # axon-gateway-env.age is no longer loaded: it held AXON_GATEWAY_TOKEN
      # (gone in database mode) and the import file references nothing else
      # from it. It stays declared below because the other consumers and
      # ../configuration.nix's restartTriggers still name it.
      environmentFiles = [
        "/run/axon-gateway/hindsight.env"
        "/run/axon-gateway/database.env"
      ];
      extraOptions = [
        "--network=host"
        # Resolve through the host's unbound cache (modules/dns-client-cache.nix).
        # Without it podman copies the host's resolv.conf at container start,
        # and a later host DNS change left hindsight unresolvable until a restart.
        "--dns=127.0.0.1"
        "--health-cmd=wget -q --spider http://127.0.0.1:${toString gatewayPort}/health || exit 1"
        "--health-interval=30s"
        "--health-timeout=5s"
        "--health-retries=3"
        "--health-start-period=10s"
        "--health-on-failure=kill"
        "--stop-timeout=30"
      ];
    };
  };

  # The MCP servers must be listening before the gateway probes them, or it
  # marks them dead until its next reconnect. (hindsight is on another host,
  # so it can't be ordered here; the health check picks it up when it's back.)
  systemd.services.podman-axon-gateway = {
    serviceConfig.ExecStartPre = ["${generateEnv}"];
    # A rotated secret keeps its /run/agenix path; restart on the .age store path.
    restartTriggers = [
      config.age.secrets.hindsight-api-key.file
      config.age.secrets.axon-db-password.file
      config.age.secrets.axon-kek.file
      config.age.secrets.axon-oidc-client-secret.file
    ];
    after = ["forgejo-mcp.service"] ++ map (n: "${n}.service") (builtins.attrNames config.services.homelab-mcp.servers);
    wants = ["forgejo-mcp.service"] ++ map (n: "${n}.service") (builtins.attrNames config.services.homelab-mcp.servers);
  };

  # Raw `axon` role password, shared with the database host.
  age.secrets.axon-db-password = {
    file = ../../../secrets/axon-db-password.age;
    mode = "0400";
  };

  # The KEK file the gateway seals stored backend/provider secrets with: lines
  # of `id:secret`, the first line is the active key (add a new first line to
  # rotate, keep the old lines to read old data). LOSING IT MAKES THE SEALED
  # DATA UNREADABLE, so keep a copy of it with the database backups' keys. The
  # container runs as 65532, so the file is owned by that uid, not root.
  age.secrets.axon-kek = {
    file = ../../../secrets/axon-kek.age;
    owner = "65532";
    group = "65532";
    mode = "0400";
  };

  # Raw Pocket ID client secret for the gateway's OIDC client.
  age.secrets.axon-oidc-client-secret = {
    file = ../../../secrets/axon-oidc-client-secret.age;
    owner = "65532";
    group = "65532";
    mode = "0400";
  };

  # Raw Hindsight tenant key, shared with the containers host.
  age.secrets.hindsight-api-key = {
    file = ../../../secrets/hindsight-api-key.age;
    mode = "0400";
  };

  services.caddy.virtualHosts = {
    # axon.homelab.internal moved here from the containers host on 2026-09-14;
    # every client (hermes, otel's alertmanager bridge, development, the
    # dashboard health check, prometheus) reaches it by that name, so for
    # them the move was a DNS change (hosts/dns/configuration.nix).
    "axon.homelab.internal axon.homelab.local" = {
      extraConfig = ''
        tls {
          ca https://ca.homelab.internal:8443/acme/acme/directory
        }
        ${gatewayVhost}
      '';
    };
  };
}
