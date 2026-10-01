{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.spacebot;
  vllm = config.services.vllm;
  dataDir = "/var/lib/spacebot";
  configFile = "${dataDir}/config.toml";

  settingsJson = pkgs.writeText "spacebot-settings.json" (builtins.toJSON cfg.settings);

  # Deep-merge the Nix-managed settings over the existing config.toml.
  # Spacebot's web UI writes to the same file (messaging adapters, bindings,
  # agents), so overwriting it wholesale would drop UI changes on every
  # restart. Tables merge recursively with Nix winning; arrays are replaced.
  # Keys removed from Nix are NOT removed from the file.
  mergeConfig =
    pkgs.writers.writePython3 "spacebot-merge-config" {
      libraries = [pkgs.python3Packages.tomli-w];
    } ''
      import json
      import os
      import sys
      import tomllib

      import tomli_w

      target, managed_path = sys.argv[1], sys.argv[2]


      def merge(base, override):
          for key, value in override.items():
              if isinstance(value, dict) and isinstance(base.get(key), dict):
                  merge(base[key], value)
              else:
                  base[key] = value
          return base


      try:
          with open(target, "rb") as f:
              current = tomllib.load(f)
      except FileNotFoundError:
          current = {}

      with open(managed_path) as f:
          managed = json.load(f)

      tmp = target + ".tmp"
      fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
      with open(fd, "wb") as f:
          tomli_w.dump(merge(current, managed), f)
      os.replace(tmp, target)
    '';

  vllmModel = "vllm/${vllm.model}";
in {
  # Spacebot runs from the upstream OCI image (built by their release CI).
  # Their Nix flake/module is unmaintained (broken since the Tailwind v4
  # migration in 2026-04), so it is not used. Self-update is not wired up:
  # bump `image` to upgrade.
  options.services.spacebot = {
    enable = lib.mkEnableOption "Spacebot AI agent (Podman container)";

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/spacedriveapp/spacebot:v0.5.0";
      description = "OCI image for Spacebot.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 19898;
      description = "Web UI / API port.";
    };

    bind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Web UI / API bind address (host network).";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/agenix/spacebot-env";
      description = ''
        Environment file (KEY=value) for secrets referenced from config.toml
        as "env:KEY", e.g. DISCORD_BOT_TOKEN.
      '';
    };

    settings = lib.mkOption {
      type = (pkgs.formats.json {}).type;
      default = {};
      description = ''
        Spacebot config.toml settings, deep-merged over the existing file on
        every service start (Nix wins for the keys it sets, everything the web
        UI added is kept). See https://docs.spacebot.sh/config.
      '';
    };

    identityFiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.path);
      default = {};
      example = lib.literalExpression ''{ eve."SOUL.md" = ./eve/SOUL.md; }'';
      description = ''
        Per-agent identity files (SOUL.md, IDENTITY.md, ROLE.md), copied into
        agents/<id>/ only when missing, so edits made in the web UI survive.
        Delete the file on disk to re-seed it from Nix. Agents without files
        get Spacebot's generic main-agent templates.
      '';
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Spacebot at boot. When false, start the podman-spacebot unit manually.";
    };

    localVllm = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Route every Spacebot process to the local vLLM server
        (services.vllm) and configure no other LLM provider. Starting
        Spacebot also starts podman-vllm.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.spacebot.settings = {
        api = {
          enabled = true;
          inherit (cfg) port bind;
        };
        defaults = {
          cron_timezone = lib.mkDefault config.time.timeZone;
          user_timezone = lib.mkDefault config.time.timeZone;
        };
      };

      systemd.tmpfiles.rules = ["d ${dataDir} 0700 root root -"];

      virtualisation.oci-containers.containers.spacebot = {
        inherit (cfg) image autoStart;
        volumes = ["${dataDir}:/data"];
        environment = {
          # The image sets SPACEBOT_DEPLOYMENT=docker, which forces the API to
          # bind 0.0.0.0 and ignore api.bind. Any other value honors it.
          SPACEBOT_DEPLOYMENT = "native";
          TZ = config.time.timeZone;
        };
        environmentFiles = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
        # Host network: reaches vLLM on 127.0.0.1 and keeps the UI on loopback.
        # The image ships bubblewrap, but without CAP_SYS_ADMIN it usually
        # cannot create namespaces inside the container; Spacebot then logs a
        # warning and runs worker commands unsandboxed (container = boundary).
        extraOptions = ["--network=host"];
      };

      # Merge before the container starts. The image's entrypoint only writes
      # its own (cloud-provider) config.toml when none exists, so it is skipped.
      systemd.services.podman-spacebot.preStart = lib.mkBefore ''
        ${mergeConfig} ${configFile} ${settingsJson}
        ${lib.concatStrings (lib.flatten (lib.mapAttrsToList (agent: files:
          lib.mapAttrsToList (name: src: let
            dest = "${dataDir}/agents/${agent}/${name}";
          in ''
            [ -e ${dest} ] || install -D -m 0644 ${src} ${dest}
          '')
          files)
        cfg.identityFiles))}
      '';
    }

    (lib.mkIf cfg.localVllm {
      assertions = [
        {
          assertion = vllm.enable;
          message = "services.spacebot.localVllm requires services.vllm.enable";
        }
        {
          assertion = vllm.maxModelLen != null;
          message = "services.spacebot.localVllm requires services.vllm.maxModelLen (used as Spacebot's context_window)";
        }
      ];

      services.spacebot.settings = {
        llm.provider.vllm = {
          api_type = "openai_completions";
          # No /v1 suffix: Spacebot appends /v1/chat/completions itself.
          base_url = "http://127.0.0.1:${toString vllm.port}";
          # vLLM runs without --api-key; the field is required but unchecked.
          api_key = "unused";
          name = "Local vLLM (${vllm.model})";
        };

        defaults = {
          routing = {
            channel = vllmModel;
            branch = vllmModel;
            worker = vllmModel;
            compactor = vllmModel;
            cortex = vllmModel;
          };
          context_window = vllm.maxModelLen;
          # A single 12 GB GPU serves everything; keep parallel LLM work low
          # so requests don't queue behind each other for minutes.
          max_concurrent_branches = lib.mkDefault 2;
          max_concurrent_workers = lib.mkDefault 2;
        };
      };

      systemd.services.podman-spacebot = {
        wants = ["podman-vllm.service"];
        after = ["podman-vllm.service"];
      };
    })
  ]);
}
