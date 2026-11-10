{pkgs, ...}: let
  # Same directory nixos-version-metrics.nix enables the collector for; that
  # module also owns the flag and the tmpfiles rule, so neither is repeated.
  textfileDir = "/var/lib/node_exporter/textfile";
in {
  # Tailscale is gone from the config, but a host deployed without a reboot
  # keeps what tailscaled installed at runtime: policy rules at priority
  # 5210-5270, routing table 52, the ts-* firewall chains and tailscale0.
  # node_exporter exports none of these, so count them for the
  # TailscaleLeftover alert. A reboot clears all four.
  systemd.services.tailscale-leftover-metrics = {
    description = "Write tailscale leftover metrics for node_exporter";
    path = with pkgs; [iproute2 iptables nftables gnugrep coreutils];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    # set -u, not -e: a probe that fails must count as 0, not abort the file.
    script = ''
      set -u

      count() { grep -c . || true; }

      rules=$( (ip -4 rule show; ip -6 rule show) 2>/dev/null \
        | grep -E 'lookup 52( |$)|^(5210|5230|5250|5270):' | count)
      routes=$(ip route show table 52 2>/dev/null | count)
      chains=$( (iptables -S 2>/dev/null; ip6tables -S 2>/dev/null) \
        | grep -E '^-N ts-' | count)
      nftchains=$(nft list chains 2>/dev/null | grep 'ts-' | count)
      iface=0
      [ -e /sys/class/net/tailscale0 ] && iface=1

      # Atomic write (temp file + mv) so node_exporter never reads a partial file.
      tmp=${textfileDir}/tailscale_leftover.prom.$$
      cat > "$tmp" <<PROM
      # HELP tailscale_leftover_ip_rules ip rules left by tailscaled (lookup 52 or priority 5210/5230/5250/5270)
      # TYPE tailscale_leftover_ip_rules gauge
      tailscale_leftover_ip_rules ''${rules:-0}
      # HELP tailscale_leftover_routes_table52 Routes left in tailscaled's routing table 52
      # TYPE tailscale_leftover_routes_table52 gauge
      tailscale_leftover_routes_table52 ''${routes:-0}
      # HELP tailscale_leftover_firewall_chains ts-* chains left in iptables, ip6tables and nftables
      # TYPE tailscale_leftover_firewall_chains gauge
      tailscale_leftover_firewall_chains $(( ''${chains:-0} + ''${nftchains:-0} ))
      # HELP tailscale_leftover_interface 1 if the tailscale0 interface still exists
      # TYPE tailscale_leftover_interface gauge
      tailscale_leftover_interface $iface
      PROM
      mv "$tmp" ${textfileDir}/tailscale_leftover.prom
    '';
  };

  systemd.timers.tailscale-leftover-metrics = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
    };
  };
}
