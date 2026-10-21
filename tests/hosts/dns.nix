{harness}:
harness.mkHostTest {
  name = "dns";
  hostPath = ../../hosts/dns/configuration.nix;
  extraModules = [harness.clearStaticNetworking];
  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.wait_for_unit("unbound.service")
    machine.wait_for_open_port(53)

    # Forward A records in homelab.internal, the primary zone.
    machine.succeed(
        "dig @127.0.0.1 -p 53 database.homelab.internal +short | grep -q '^192.168.2.134$'"
    )
    machine.succeed(
        "dig @127.0.0.1 -p 53 dns.homelab.internal +short | grep -q '^192.168.2.145$'"
    )
    machine.succeed(
        "dig @127.0.0.1 -p 53 axon.homelab.internal +short | grep -q '^192.168.2.152$'"
    )
    # The legacy homelab.local zone is still served as a compatibility alias.
    machine.succeed(
        "dig @127.0.0.1 -p 53 database.homelab.local +short | grep -q '^192.168.2.134$'"
    )
    machine.succeed(
        "dig @127.0.0.1 -p 53 dns.homelab.local +short | grep -q '^192.168.2.145$'"
    )

    # Reverse (PTR) records: legacy hosts keep their homelab.local PTR, hosts
    # born .internal-only get a homelab.internal one.
    machine.succeed(
        "dig @127.0.0.1 -p 53 -x 192.168.2.134 +short | grep -q 'database.homelab.local'"
    )
    machine.succeed(
        "dig @127.0.0.1 -p 53 -x 192.168.2.190 +short | grep -q 'agents.homelab.internal'"
    )

    # NOT asserted on, intentionally: tailscaled-autoconnect (needs a real
    # tailscale-auth-key secret and a real control-plane connection)
    # and caddy's ACME cert issuance against ca.homelab.local (no route to it in
    # the sandbox).
    # All soft-fail without affecting the assertions above.
  '';
}
