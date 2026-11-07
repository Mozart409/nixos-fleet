{
  config,
  lib,
  pkgs,
  ...
}: let
  hosts = import ../../lib/hosts.nix;
  mcpIp = hosts.hosts.mcp.ip;

  psql = "${config.services.postgresql.package}/bin/psql";
  secret = config.age.secrets.pgmcp-forgejo-role-password;
  # The module stays inert until this secret is committed, so the host still
  # evaluates and deploys before it exists.
  secretFile = ../../secrets/pgmcp-forgejo-role-password.age;

  # TLS plumbing copied from hosts/database/configuration.nix, which has the
  # incident history behind each piece. pgSslDir is filled by the acme postRun
  # (real step-ca leaf) or, until that first succeeds, by a self-signed
  # placeholder, so `ssl = true` never keeps postgres from starting.
  pgSslDir = "/var/lib/postgresql/ssl";
  pgCertName = "forgejo.homelab.internal";
  # lego's standalone HTTP-01 responder. Caddy owns :80, so it proxies the
  # challenge path here (the vhost in configuration.nix hardcodes this port).
  acmeChallengePort = 1360;

  # Tables the role never reads: credentials, then personal data and content
  # that has no useful metadata columns.
  deniedTables = "token|secret|credential|oauth2|two_factor|webauthn|login_source|external_login|^session$|^task$|hook_task|webhook|mirror|action_variable|user_setting|^email_|abuse_report|^issue_content_history$|^action_task_output$|^dbfs_|^federated_user_activity$|^user_open_id$|gpg_key";
  # Column names denied in every table. `is_private` and `keep_email_private`
  # must stay readable, so bare `private` is not matched.
  deniedColumns = "passw|salt|rands|token|secret|private_key|credential|authorization|cookie|remote_address|original_url|original_author";
  # Per-table columns holding CI payloads, personal data or repo content. Names
  # that are too generic for deniedColumns (`name`, `content`, `title`) go here.
  # IDs, states, timestamps, sizes, logins, repo and branch names stay readable.
  privateColumns = {
    action = ["content"];
    action_run = ["title" "event_payload" "pre_execution_error" "pre_execution_error_details"];
    action_run_job = ["workflow_payload"];
    action_schedule = ["title" "event_payload" "content"];
    attachment = ["name" "external_url"];
    branch = ["commit_message"];
    comment = ["old_title" "new_title" "tree_path" "content" "patch"];
    commit_status = ["target_url" "description"];
    commit_status_summary = ["target_url"];
    issue = ["name" "content"];
    lfs_lock = ["path"];
    milestone = ["name" "content"];
    package_property = ["value"];
    package_version = ["metadata_json"];
    project = ["title" "description"];
    project_board = ["title"];
    pull_auto_merge = ["message"];
    pull_request = ["conflicted_files" "changed_protected_files"];
    release = ["title" "note"];
    repo_unit = ["config"];
    repository = ["description" "website"];
    review = ["content"];
    review_state = ["updated_files"];
    team_invite = ["email"];
    upload = ["name"];
    user = ["full_name" "email" "login_name" "location" "website" "pronouns" "description" "avatar" "avatar_email"];
  };
  # Matched against `table:column`.
  privateColumnsRegex = "^(${lib.concatStringsSep "|" (lib.mapAttrsToList (table: columns: "${table}:(${lib.concatStringsSep "|" columns})") privateColumns)})$";

  # Explicit per-table grants, not ALTER DEFAULT PRIVILEGES: a table added by a
  # Forgejo upgrade stays unreadable until this unit re-runs (fails closed). The
  # file's store path is in the unit's script, so changing either deny list
  # re-runs the unit on deploy.
  #
  # Tables matching deniedTables are skipped whole; in the others the columns
  # matching deniedColumns or privateColumnsRegex are left out.
  # The REVOKE also clears column grants, so tightening a list converges.
  # `%I` quotes every identifier: `user` is a reserved word.
  grantsSql = pkgs.writeText "pgmcp-forgejo-grants.sql" ''
    BEGIN;
    GRANT USAGE ON SCHEMA public TO mcp;
    REVOKE ALL ON ALL TABLES IN SCHEMA public FROM mcp;
    DO $$
    DECLARE
      tbl text;
      readable text;
      excluded bigint;
    BEGIN
      FOR tbl IN
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_type = 'BASE TABLE'
          AND table_name !~* '${deniedTables}'
      LOOP
        SELECT
          string_agg(format('%I', column_name), ', ' ORDER BY ordinal_position)
            FILTER (WHERE column_name !~* '${deniedColumns}' AND (tbl || ':' || column_name::text) !~* '${privateColumnsRegex}'),
          count(*)
            FILTER (WHERE column_name ~* '${deniedColumns}' OR (tbl || ':' || column_name::text) ~* '${privateColumnsRegex}')
        INTO readable, excluded
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = tbl;

        IF readable IS NULL THEN
          CONTINUE;
        ELSIF excluded = 0 THEN
          EXECUTE format('GRANT SELECT ON public.%I TO mcp', tbl);
        ELSE
          EXECUTE format('GRANT SELECT (%s) ON public.%I TO mcp', readable, tbl);
        END IF;
      END LOOP;
    END
    $$;
    COMMIT;
  '';
in
  lib.mkIf (builtins.pathExists secretFile) {
    # Read-only access to Forgejo's live database for the `pgforgejo` MCP tools on
    # the mcp host. Forgejo itself keeps using the local unix socket (peer auth);
    # this only adds a TLS listener for the `mcp` role from the mcp host.
    age.secrets.pgmcp-forgejo-role-password = {
      file = secretFile;
      owner = "postgres";
      group = "postgres";
    };

    services.postgresql = {
      enableTCPIP = true;
      settings = {
        ssl = true;
        ssl_cert_file = "${pgSslDir}/fullchain.pem";
        ssl_key_file = "${pgSslDir}/key.pem";
        ssl_min_protocol_version = "TLSv1.2";
      };
      ensureUsers = [{name = "mcp";}];
      # Plain string (not mkOverride): the module's local peer rules for Forgejo
      # stay. One rule, TLS only, from the mcp host only.
      authentication = ''
        hostssl forgejo mcp ${mcpIp}/32 scram-sha-256
      '';
    };

    # Not allowedTCPPorts: 5432 is open to the mcp host only. Same shape as the
    # node-exporter rule in hosts/agents/zones.nix.
    networking.firewall.extraCommands = ''
      iptables -w -A nixos-fw -p tcp -s ${mcpIp} -m tcp --dport 5432 -m comment --comment pgmcp-forgejo -j nixos-fw-accept
    '';

    # step-ca leaf for postgres; see hosts/database/configuration.nix.
    security.acme = {
      acceptTerms = true;
      defaults = {
        email = "acme@homelab.local";
        server = "https://ca.homelab.internal:8443/acme/acme/directory";
      };
      certs.${pgCertName} = {
        listenHTTP = "127.0.0.1:${toString acmeChallengePort}";
        group = "postgres";
        # Runs as root after every (re)issuance. Copy rather than point postgres
        # at /var/lib/acme: postgres refuses a key it does not own unless it is
        # root-owned 0640, and lego's files are acme-owned.
        postRun = ''
          install -d -m 0750 -o postgres -g postgres ${pgSslDir}
          install -m 0640 -o postgres -g postgres fullchain.pem ${pgSslDir}/fullchain.pem
          install -m 0600 -o postgres -g postgres key.pem ${pgSslDir}/key.pem
        '';
        reloadServices = ["postgresql.service"];
      };
    };

    systemd.services.postgresql = {
      # Don't block on issuance: the target is reached on failure too, and the
      # preStart below guarantees a usable cert either way.
      after = ["acme-finished-${pgCertName}.target"];
      wants = ["acme-${pgCertName}.service"];
      # Populate pgSslDir before every start: the lego-issued cert if there is
      # one (copied, since postgres refuses a key it does not own), else what is
      # already there, else a self-signed placeholder so `ssl = true` can never
      # wedge startup. Clients on verify-full refuse the placeholder, which is the
      # correct failure. This covers the start path that the acme unit's own
      # reloadServices misses on a deploy (see hosts/database/configuration.nix).
      preStart = lib.mkBefore ''
        install -d -m 0750 ${pgSslDir}
        acmeDir=/var/lib/acme/${pgCertName}
        if [ -r "$acmeDir/key.pem" ] && [ -r "$acmeDir/fullchain.pem" ]; then
          install -m 0640 "$acmeDir/fullchain.pem" ${pgSslDir}/fullchain.pem
          install -m 0600 "$acmeDir/key.pem" ${pgSslDir}/key.pem
        elif [ ! -s ${pgSslDir}/key.pem ]; then
          ${pkgs.openssl}/bin/openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -nodes -days 30 -subj "/CN=${pgCertName}" \
            -keyout ${pgSslDir}/key.pem -out ${pgSslDir}/fullchain.pem 2>/dev/null
          chmod 0600 ${pgSslDir}/key.pem
          chmod 0640 ${pgSslDir}/fullchain.pem
        fi
      '';
    };

    # Password, per-role limits and grants for `mcp`; mirrors mkRolePasswordUnit
    # in hosts/database/configuration.nix.
    systemd.services.postgresql-mcp-password = {
      description = "Set the restricted mcp role's password, limits and grants";
      # Order on postgresql-SETUP.service, never postgresql.service: the role is
      # created by ensureUsers in the setup unit (see the database host).
      # forgejo.service is ordering only, so Forgejo's migrated tables exist when
      # the grants run; it must not be a requirement.
      after = ["postgresql-setup.service" "agenix.service" "forgejo.service"];
      requires = ["postgresql-setup.service"];
      wantedBy = ["multi-user.target"];
      # Re-run on rotation: the secret's .file store path changes on every
      # re-encryption, the unit text otherwise would not.
      restartTriggers = [secret.file];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };
      # The password never appears in a logged statement (log_statement = ddl
      # would ship it to Loki); same guard as the database host. It travels as a
      # psql variable (`:'pw'`), fed on stdin because -c does not interpolate.
      #
      # pg_read_all_data is never granted here: it cannot be subtracted from, so
      # it would defeat the per-table and per-column grants. pg_read_all_stats
      # only exposes pg_stat_* views, not table contents.
      script = ''
        ${psql} -v ON_ERROR_STOP=1 -v pw="$(cat ${secret.path})" -f - <<'SQL'
        SET log_statement = 'none';
        SET log_min_error_statement = 'panic';
        SET log_min_duration_statement = -1;
        ALTER USER mcp WITH PASSWORD :'pw';
        SQL
        ${psql} -v ON_ERROR_STOP=1 -f - <<'SQL'
        ALTER ROLE mcp SET default_transaction_read_only = on;
        ALTER ROLE mcp SET statement_timeout = '30s';
        ALTER ROLE mcp SET lock_timeout = '5s';
        ALTER ROLE mcp SET idle_in_transaction_session_timeout = '30s';
        ALTER ROLE mcp SET idle_session_timeout = '10min';
        GRANT pg_read_all_stats TO mcp;
        SQL
        ${psql} -d forgejo -v ON_ERROR_STOP=1 -f ${grantsSql}
      '';
    };
  }
