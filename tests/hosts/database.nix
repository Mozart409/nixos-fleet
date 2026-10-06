{harness}:
harness.mkHostTest {
  name = "database";
  hostPath = ../../hosts/database/configuration.nix;
  extraModules = [harness.clearStaticNetworking];
  testScript = ''
    machine.wait_for_unit("multi-user.target")

    machine.wait_for_unit("postgresql.service")
    machine.wait_for_open_port(5432)

    # Basic liveness.
    machine.succeed("sudo -u postgres psql -c 'select 1;'")

    # ensureDatabases/ensureUsers run in postgresql-setup.service, which has
    # NO agenix dependency -- role/db existence must hold even though the
    # separate password-ALTER oneshots (mkRolePasswordUnit, requiring the
    # per-role agenix secrets we do NOT fixture here) are expected to fail.
    for db in ["appdb", "terraform", "forgejo", "romm", "hofvarpnir", "multica"]:
        machine.succeed(
            f"sudo -u postgres psql -tAc \"select 1 from pg_database where datname='{db}'\" | grep -q 1"
        )

    for role in ["mcp", "terraform", "forgejo", "romm", "hofvarpnir", "multica"]:
        machine.succeed(
            f"sudo -u postgres psql -tAc \"select 1 from pg_roles where rolname='{role}'\" | grep -q 1"
        )

    # pgvector for Multica: the extension oneshot needs no secret, so it must
    # succeed, and the backend's first migration depends on it.
    machine.wait_for_unit("postgresql-multica-extension.service")
    machine.succeed(
        "sudo -u postgres psql -d multica -tAc \"select 1 from pg_extension where extname='vector'\" | grep -q 1"
    )

    # NOT asserted on, intentionally: the mkRolePasswordUnit oneshots
    # (systemd.services.postgresql-*-password) fail without their real
    # agenix secrets -- expected and harmless, per AGENTS.md's documented
    # agenix incident. Same for
    # services.loki-logs shipping to the unreachable loki.homelab.local.
  '';
}
