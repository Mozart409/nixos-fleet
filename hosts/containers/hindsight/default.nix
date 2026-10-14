{
  config,
  lib,
  pkgs,
  ...
}: let
  # Hindsight: the shared agent memory (one bank, `homelab`). Agents never
  # talk to it directly; axon-gateway on the mcp host is its only MCP client
  # (backend `hindsight`, hosts/mcp_vm/axon-gateway). Plan and verification:
  # knowledge-base/projects/agent-platform/Hindsight Install.md.
  #
  # One container runs both the API (which also serves MCP under
  # /mcp/<bank>/) and the Control Plane web UI. Postgres + pgvector is the
  # `hindsight` database on the database host; the LLM is OpenCode Zen.
  apiPort = 8888;
  uiPort = 9999;
  # oauth2-proxy in front of the Control Plane, which has no login of its own.
  uiAuthPort = 4180;

  apiHost = "hindsight.homelab.internal";
  uiHost = "hindsight-ui.homelab.internal";

  # Non-secret environment. Hashed into the unit below so an edit here
  # restarts the container on deploy.
  environment = {
    # OpenCode Zen through Hindsight's OpenAI-compatible client. It adds the
    # x-opencode-session header itself for opencode.ai hosts.
    HINDSIGHT_API_LLM_PROVIDER = "openai";
    HINDSIGHT_API_LLM_BASE_URL = "https://opencode.ai/inference/v1";
    HINDSIGHT_API_LLM_MODEL = "deepseek-v4.1-flash";
    # Embeddings and reranker run in the container; memory text never leaves
    # the host except in the LLM calls.
    HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
    HINDSIGHT_API_RERANKER_PROVIDER = "local";
    # Without the tenant extension the API and MCP accept anyone. The key it
    # checks (HINDSIGHT_API_TENANT_API_KEY) comes from the generated env file.
    HINDSIGHT_API_TENANT_EXTENSION = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension";
    HINDSIGHT_API_MCP_ENABLED = "true";
    HINDSIGHT_API_WORKER_ID = "containers";
    # Control Plane -> API inside the container.
    HINDSIGHT_CP_DATAPLANE_API_URL = "http://localhost:${toString apiPort}";
  };

  # Builds the env file that holds the secrets the container needs in forms
  # the agenix files do not have: the database URL around the raw role
  # password (shared with the database host), and the tenant key twice, once
  # for the API and once for the Control Plane, which is an API client.
  generateEnv = pkgs.writeShellScript "generate-hindsight-env" ''
    set -eu
    mkdir -p /run/hindsight
    umask 077
    pw=$(cat ${config.age.secrets.hindsight-db-password.path})
    key=$(cat ${config.age.secrets.hindsight-api-key.path})
    {
      printf 'HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:%s@database.homelab.internal:5432/hindsight?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt\n' "$pw"
      printf 'HINDSIGHT_API_TENANT_API_KEY=%s\n' "$key"
      printf 'HINDSIGHT_CP_DATAPLANE_API_KEY=%s\n' "$key"
    } > /run/hindsight/hindsight.env
  '';
in {
  # Raw role password, shared with the database host.
  age.secrets.hindsight-db-password = {
    file = ../../../secrets/hindsight-db-password.age;
    mode = "0400";
  };

  # Raw tenant key, shared with the mcp host (axon forwards it as Bearer).
  age.secrets.hindsight-api-key = {
    file = ../../../secrets/hindsight-api-key.age;
    mode = "0400";
  };

  # The secrets only this host needs, read by both the container and
  # oauth2-proxy (each ignores the other's variables):
  # HINDSIGHT_API_LLM_API_KEY, an OpenCode Zen key of its own so Hindsight's
  # spend shows up separately from the agent zones'; and
  # OAUTH2_PROXY_CLIENT_ID, OAUTH2_PROXY_CLIENT_SECRET and
  # OAUTH2_PROXY_COOKIE_SECRET for the Control Plane's Pocket ID client.
  age.secrets.hindsight-env = {
    file = ../../../secrets/hindsight-env.age;
    mode = "0400";
  };

  virtualisation.oci-containers.containers.hindsight = {
    # Pin a release, never `latest` (tags have no `v`).
    image = "ghcr.io/vectorize-io/hindsight:1.0.0";
    autoStart = true;
    # Loopback only; Caddy (and oauth2-proxy for the UI) is the way in.
    ports = [
      "127.0.0.1:${toString apiPort}:${toString apiPort}"
      "127.0.0.1:${toString uiPort}:${toString uiPort}"
    ];
    # No data volume: with an external database the only state is in
    # Postgres. Host CA bundle (step-ca root) for sslrootcert in the URL.
    volumes = [
      "/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro"
    ];
    environment =
      environment
      // {
        # Restart nonce, as for axon-gateway: podman's unit only changes when
        # the container definition does.
        CONFIG_HASH = builtins.hashString "sha256" (builtins.toJSON environment);
      };
    environmentFiles = [
      "/run/hindsight/hindsight.env"
      config.age.secrets.hindsight-env.path
    ];
    extraOptions = [
      # Upstream's recommended run flags; the local embedding model uses it.
      "--shm-size=1g"
      "--stop-timeout=30"
    ];
  };

  systemd.services.podman-hindsight = {
    serviceConfig.ExecStartPre = ["${generateEnv}"];
    # ExecStartPre only runs on (re)start, and a re-encrypted secret keeps its
    # /run/agenix path, so list the .age store paths to restart on rotation.
    restartTriggers = [
      config.age.secrets.hindsight-db-password.file
      config.age.secrets.hindsight-api-key.file
      config.age.secrets.hindsight-env.file
    ];
  };

  # The Control Plane has no login of its own (HINDSIGHT_CP_ACCESS_KEY stays
  # unset), so Pocket ID is the login. The Pocket ID client is restricted to
  # my user there; any account it lets through gets in here.
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://pocketid.dropbear-butterfly.ts.net";
    keyFile = config.age.secrets.hindsight-env.path;
    redirectURL = "https://${uiHost}/oauth2/callback";
    httpAddress = "http://127.0.0.1:${toString uiAuthPort}";
    upstream = ["http://127.0.0.1:${toString uiPort}"];
    email.domains = ["*"];
    approvalPrompt = "auto";
    reverseProxy = true;
    trustedProxyIP = ["127.0.0.1/32"];
    extraConfig = {
      code-challenge-method = "S256";
      skip-provider-button = true;
    };
  };

  # The module's own trigger is the stable /run/agenix path; add the .age
  # store path so a rotated secret restarts it too.
  systemd.services.oauth2-proxy.restartTriggers = [config.age.secrets.hindsight-env.file];

  services.caddy.virtualHosts = {
    # API + MCP. The tenant key is the auth; axon-gateway is the only client.
    # 127.0.0.1, never `localhost`: Caddy resolves upstreams through the
    # system resolver, and `localhost` lookups have timed out against unbound.
    ${apiHost} = {
      extraConfig = ''
        tls {
          ca https://ca.homelab.local:8443/acme/acme/directory
        }

        reverse_proxy 127.0.0.1:${toString apiPort}
      '';
    };

    ${uiHost} = {
      extraConfig = ''
        tls {
          ca https://ca.homelab.local:8443/acme/acme/directory
        }

        reverse_proxy 127.0.0.1:${toString uiAuthPort}
      '';
    };
  };
}
