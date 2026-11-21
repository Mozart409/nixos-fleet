{
  config,
  lib,
  pkgs,
  ...
}: let
  # One TLS cert (step-ca, via lego) covers both instances; clients connect to
  # the host's valkey.homelab.internal alias and verify against step-ca.
  certName = "valkey.homelab.internal";
  # lego answers the HTTP-01 challenge here; Caddy proxies :80 to it below.
  # 1360 is unused elsewhere under hosts/containers.
  acmeChallengePort = 1360;

  # Two caches instead of one shared instance: a flush, a full memory or a
  # password leak on one cannot touch the other, and each gets a memory cap
  # that fits its workload.
  instances = {
    multica = {
      port = 6380;
      maxmemory = "128mb";
      # REDIS_URL also moves multica's realtime relay onto Redis, and those
      # keys carry no TTL, so only TTL'd keys (the PAT cache) may be evicted.
      policy = "volatile-lru";
    };
    forgejo = {
      port = 6381;
      maxmemory = "64mb";
      # Forgejo stores only cache and sessions here, both with TTLs.
      policy = "allkeys-lru";
    };
  };
in {
  # Valkey (the Linux Foundation fork of Redis, 9.1 in nixpkgs) behind the
  # stock redis module, which just runs whatever `package` says. Added
  # 2026-11-21 as a cache for multica and Forgejo. Dragonfly 2.1 was
  # rejected: nixpkgs only carries 1.39, its BSL licence is a poor fit, and
  # its multi-threaded throughput is irrelevant at this size.
  services.redis.package = pkgs.valkey;

  services.redis.servers =
    lib.mapAttrs (name: inst: {
      enable = true;
      # No plaintext TCP and no unix socket: TLS + password is the only way in.
      port = 0;
      unixSocket = null;
      # All interfaces: Forgejo connects from its own VM, multica from its
      # podman container via this host's LAN address.
      bind = null;
      # Nothing is persisted: a restart empties the cache, which is the point.
      save = [];
      appendOnly = false;
      requirePassFile = config.age.secrets."valkey-${name}-password".path;
      settings = {
        tls-port = inst.port;
        tls-cert-file = "/var/lib/acme/${certName}/fullchain.pem";
        tls-key-file = "/var/lib/acme/${certName}/key.pem";
        # Server-side TLS only; clients authenticate with the password.
        tls-auth-clients = "no";
        maxmemory = inst.maxmemory;
        maxmemory-policy = inst.policy;
      };
    })
    instances;

  # Root-owned is fine: the redis module substitutes the password into the
  # runtime config in an ExecStartPre with the "+" (full privilege) prefix.
  age.secrets = lib.mapAttrs' (name: _:
    lib.nameValuePair "valkey-${name}-password" {
      file = ../../../secrets/valkey-${name}-password.age;
      mode = "0400";
    })
  instances;

  # step-ca leaf shared by both instances. Neither service has a built-in
  # ACME client, so lego (security.acme) issues it and the redis users read it
  # through the valkey-tls group.
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "acme@homelab.local";
      server = "https://ca.homelab.internal:8443/acme/acme/directory";
    };
    certs.${certName} = {
      listenHTTP = "127.0.0.1:${toString acmeChallengePort}";
      group = "valkey-tls";
      # The redis units have no ExecReload, so systemd's try-reload-or-restart
      # restarts them, and they pick up a renewed cert.
      reloadServices = map (name: "redis-${name}.service") (lib.attrNames instances);
    };
  };

  users.groups.valkey-tls = {};
  users.users = lib.mapAttrs' (name: _:
    lib.nameValuePair "redis-${name}" {extraGroups = ["valkey-tls"];})
  instances;

  # Start after the cert attempt. Unlike postgres on the database host there is
  # no placeholder-cert fallback: without a cert the instance fails to start,
  # which is acceptable for a cache.
  systemd.services = lib.mapAttrs' (name: _:
    lib.nameValuePair "redis-${name}" {
      after = ["acme-finished-${certName}.target"];
      wants = ["acme-${certName}.service"];
    })
  instances;

  # HTTP-01 for the cert above: lego answers on acmeChallengePort and step-ca
  # dials this name on :80, which is this site. Anything else on :80 keeps a
  # redirect to HTTPS.
  services.caddy.virtualHosts."http://${certName}".extraConfig = ''
    handle /.well-known/acme-challenge/* {
      reverse_proxy 127.0.0.1:${toString acmeChallengePort}
    }
    handle {
      redir https://{host}{uri} permanent
    }
  '';

  # TLS + password on both. Forgejo reaches 6381 from its VM, multica's
  # container reaches 6380 via the host's LAN address.
  networking.firewall.allowedTCPPorts = lib.mapAttrsToList (_: inst: inst.port) instances;
}
