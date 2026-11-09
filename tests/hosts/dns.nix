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

    # Overlay view: a client in 172.16.20.0/24 gets overlay addresses for
    # hosts on the overlay and the normal records for everything else. Query
    # the address itself so the source is in the overlay range: unbound binds
    # the wildcard and replies from the routed source, so `@127.0.0.1 -b` would
    # answer from the wrong address and dig would discard it.
    machine.succeed("ip addr add 172.16.20.250/32 dev lo")
    machine.succeed(
        "dig @172.16.20.250 -p 53 dns.homelab.internal +short | grep -q '^172.16.20.4$'"
    )
    machine.succeed(
        "dig @172.16.20.250 -p 53 database.homelab.internal +short | grep -q '^192.168.2.134$'"
    )
    # LAN clients (source 127.0.0.1) still see the LAN address.
    machine.succeed(
        "dig @127.0.0.1 -p 53 dns.homelab.internal +short | grep -q '^192.168.2.145$'"
    )

    # NOT asserted on, intentionally: caddy's ACME cert issuance against
    # ca.homelab.internal (no route to it in the sandbox).
    # All soft-fail without affecting the assertions above.
  '';
}
