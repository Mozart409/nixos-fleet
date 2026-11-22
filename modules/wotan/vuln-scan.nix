{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.wotan.vulnScan;
in {
  # Weekly vulnerability scan of every fleet host (plus wotan) with sbomnix,
  # pushed to Prometheus over OTLP. Results show up as the metrics
  # `nixos_vulnerabilities{host,severity}` and
  # `nixos_vuln_scan_timestamp_seconds{host}`; the alerts
  # `NixosCriticalVulnerabilities` and `VulnScanStale` are in
  # `infra/hosts/otel/alerting.nix`. The interactive counterparts are the
  # `just vulns`, `vulns-live`, `vulns-diff` and `outdated` recipes.
  options.wotan.vulnScan.enable = lib.mkEnableOption "the weekly sbomnix vulnerability scan of the fleet";

  config = lib.mkIf cfg.enable {
    # The same fleet push token fluent-bit uses (write-only side of the otel vhosts).
    age.secrets.otel-push-token.file = ../../secrets/otel-push-token.age;

    # Scans `main` as committed, not the dirty working tree. It builds the
    # toplevels, which are usually already in wotan's store from colmena and
    # switch builds. Hosts are scanned one at a time: a parallel or full-flake
    # eval has been OOM-killed. The push runs even after a failed scan, so
    # partial results still land; the unit then fails with the scan's code.
    systemd.services.vuln-scan = {
      description = "Scan the fleet's NixOS configurations for vulnerabilities";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      path = with pkgs; [
        config.nix.package
        git
        just
        jq
        gawk
        curl
        coreutils
        bash
        hostname
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "amadeus";
        WorkingDirectory = "/home/amadeus/code/yggdrasil";
        LoadCredential = [
          "otel-push-token:${config.age.secrets.otel-push-token.path}"
        ];
        Nice = 19;
        IOSchedulingClass = "idle";
      };
      script = ''
        rc=0
        just vulns-fleet main || rc=$?
        infra/scripts/vulns-push.sh
        exit "$rc"
      '';
    };

    # wotan is a desktop and often off, so a missed run fires at the next boot.
    systemd.timers.vuln-scan = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
