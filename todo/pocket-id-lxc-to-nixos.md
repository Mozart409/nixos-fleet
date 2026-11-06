# Pocket ID: move from the CT 102 LXC to NixOS on Postgres

> **Status: prepared on branch `worktree-pocket-id-nixos`, not deployed.** The
> upstream facts below were read from Pocket ID v2.19.1 source and docs. Nothing
> here has been run end to end, and upstream labels the export/import feature
> experimental. Treat every "Verify" line as a real check, not a formality.

From: CT 102 on `pve-gigabyte` (192.168.2.102), docker-compose, image
`ghcr.io/pocket-id/pocket-id:v2.19.0`, SQLite, issuer
`https://pocketid.dropbear-butterfly.ts.net`.

To: `services.pocket-id` 2.19.1 on `containers`, database `pocketid` on the
`database` host, issuer `https://pocketid.homelab.internal`. Both VMs have their
disks on `zfs_pool` (HDD).

## Decisions

- **`.homelab.internal` on `containers`** (chosen by the user). Consequences:
  every passkey is re-enrolled (the RP ID derives from `APP_URL`), every client
  must trust step-ca, the IdP shares a host with other services, and every login
  now needs both `containers` and `database` up.
- **Two secrets, one password.** The module reads secrets as an env file, so the
  connection string carries the password (same precedent as the pgmcp URL
  secrets), while the `database` host needs it as a bare file. Rotating means
  re-encrypting both `pocketid-db-password.age` and `pocketid-env.age`.

## Facts this relies on

- `pocket-id export --path <file|->`, `pocket-id import --path <file|-> [--yes]
  [--forcefully-acquire-lock]`, `pocket-id one-time-access-token <user-or-email>`
  (prints `<APP_URL>/lc/<token>`, valid 1 hour). In the container the binary is
  `./pocket-id` in `/app`.
- Import drops the Pocket ID tables and re-creates the schema by migrating to the
  archive's version, so an empty database is fine and no prior start is needed.
  It does not refuse a version mismatch, so keep versions equal. It also
  overwrites `data/uploads` under the working directory `/var/lib/pocket-id`.
- `ENCRYPTION_KEY` must be the LXC's value. Signing keys are stored encrypted
  with it. Upstream docs do not specify the failure mode when it is wrong.
- `iss`, the discovery `issuer`, the passkey RP ID and the allowed origin derive
  only from `APP_URL`. Old passkeys stop working; a one-time token is the way in.
- `sub` survives import. countdown has `UNIQUE (issuer, subject)` on `users`,
  hofvarpnir has it on `oidc_identities`. RomM, Grafana and hindsight match on
  email or their own ids. Forgejo's issuer is in its authentication source and
  Jellyfin's in its SSO plugin settings (both web UI); both hosts must trust
  step-ca (expected via the system bundle, verify).

CLI runs on `containers` use this form (full path, no stdin):

```sh
sudo systemd-run --pipe --wait --collect --uid=pocket-id --gid=pocket-id \
  -p WorkingDirectory=/var/lib/pocket-id -p EnvironmentFile=/run/agenix/pocketid-env \
  --setenv=APP_URL=https://pocketid.homelab.internal \
  /run/current-system/sw/bin/pocket-id <args>
```

Below, `PID-CLI <args>` means that command.

## 0. Prerequisites and warning

The branch cannot evaluate until the two `.age` files of step 2 exist.

The branch holds three commits in deploy order: the service, this runbook, the
consumer switch. Merge up to the runbook commit now and the last commit only at
step 8. Do not run a fleet-wide `just colmena-apply` before step 6: it would flip
DNS early.

- [ ] Take a PBS snapshot of CT 102.
- [ ] Copy the compose directory together with its data volume somewhere off the LXC.
- [ ] Check where the compose file and the data live, and the compose service name
  (`pocket-id` is assumed below; neither could be read from here).
- [ ] Plan a window. Consumers keep using the LXC until step 8 and then move one by
  one. Anything changed in the old instance after the export in step 5 is lost, so
  make no admin changes from there on.

## 1. Align versions on the LXC

- [ ] In the compose file change the image to `ghcr.io/pocket-id/pocket-id:v2.19.1`, then
  `docker compose pull && docker compose up -d`.
- [ ] Read `ENCRYPTION_KEY` from the compose env (do not paste it into notes).
- Verify: `docker compose ps` is healthy and a normal login still works.

## 2. Create the secrets

From the dev shell, bare names:

```sh
pwgen -s 32 1                    # alphanumeric, safe in the URL
agenix -e pocketid-db-password.age   # the raw password only
agenix -e pocketid-env.age
```

`pocketid-env.age` has exactly two lines, with the same password in both files:

```
ENCRYPTION_KEY=<LXC value>
DB_CONNECTION_STRING=postgres://pocketid:<pw>@database.homelab.internal:5432/pocketid?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt
```

Copy the key's value exactly, without any quotes the compose file wraps around it.

- [ ] Commit both `.age` files.
- Verify: `git status` is clean for `infra/secrets/`, and
  `nix eval --raw '.#nixosConfigurations.containers.config.system.build.toplevel.drvPath'` evaluates.

## 3. Deploy `database`

- [ ] `just colmena-apply-host database`
- Verify:
  - `sudo -u postgres psql -d pocketid -c '\dt'` runs and lists nothing (role and empty database exist).
  - `systemctl status postgresql-pocketid-password` shows it succeeded.

## 4. Deploy `containers` while DNS still points at the LXC

`containers` deploys must come from the commit before the consumer-switch commit,
and `dns` receives the alias change only at step 6. Because `hosts.nix` sits in the
same commit as the service, a `containers` deploy does not change DNS; only
deploying `dns` does. Consumers must stay on the old issuer for now, so the
consumer commit must not be applied yet.

- [ ] `just colmena-apply-host containers`
- [ ] Immediately `sudo systemctl stop pocket-id`. The unit starts against the empty
  database and could show first-run setup; DNS is flipped only after the import, so
  the name still reaches the LXC meanwhile.
- Verify: `systemctl is-active pocket-id` is `inactive`;
  `dig +short pocketid.homelab.internal` still answers 192.168.2.102 (check).
- Caddy cannot get the certificate yet because the name does not point here. Expect
  ACME errors for this vhost until step 6.

## 5. Export and import

The archive holds identity data: owner `pocket-id`, mode 0600, never via `/tmp`.
Export while nobody is logging in.

- [ ] On the LXC, in the compose directory:
  `umask 077; docker compose exec -T pocket-id ./pocket-id export --path - > export.zip`
- [ ] Copy it to your home directory on `containers`, then there:
  `sudo install -o pocket-id -g pocket-id -m 0600 ~/export.zip /var/lib/pocket-id/export.zip && rm ~/export.zip`
- [ ] `PID-CLI import --path /var/lib/pocket-id/export.zip --yes`
- [ ] `sudo systemctl start pocket-id`
- Verify:
  - `curl -s -o /dev/null -w '%{http_code}\n' 'http://127.0.0.1:1411/healthz'` prints `204`.
  - `sudo journalctl -u pocket-id -n 100` has no decrypt errors.
  - `sudo -u postgres psql -d pocketid -c '\dt'` (on `database`) shows tables.
- [ ] Delete `export.zip` on both hosts, but only after step 7.

## 6. Deploy `dns`

- [ ] `just colmena-apply-host dns`
- Verify:
  - `dig +short pocketid.homelab.internal` gives the `containers` address.
  - `curl -s 'https://pocketid.homelab.internal/.well-known/openid-configuration' | jq -r .issuer`
    is `https://pocketid.homelab.internal`.
  - Compare `/.well-known/jwks.json` with the old instance's: the same `kid` proves
    `ENCRYPTION_KEY` and the keys came across.
- If the cert is stuck (HTTP 000), restart caddy on `containers` (see `infra/AGENTS.md`)
  and wait about 2.5 minutes. This briefly drops every vhost on that host.

## 7. Recovery login and passkeys

- [ ] `PID-CLI one-time-access-token <user>`; open the printed link on a device that
  trusts step-ca. The token is a credential: do not paste it into notes.
- [ ] Register a new passkey, then log in again with it on every device.
- Verify from the phone and from off-LAN too. The name resolves to a LAN address,
  so off-LAN access is a check, not a known result.
- [ ] Now delete `export.zip` on both hosts (step 5).

## 8. Rewrite issuers, then switch consumers

First, from a host that trusts step-ca, curl the target the blackbox probe will use
(`infra/hosts/otel/blackbox.nix` requires this before a probe goes live). It must
print `204 0`:

```sh
curl -sS -o /dev/null -w '%{http_code} %{ssl_verify_result}\n' 'https://pocketid.homelab.internal/healthz'
```

Rewrite before any consumer sees the new issuer, so the unique constraint cannot
collide with a freshly auto-provisioned row. Nobody should log in to countdown or
hofvarpnir between the rewrite and their deploys. On `database`:

```sh
sudo -u postgres psql -d countdown -c "UPDATE users SET issuer = 'https://pocketid.homelab.internal' WHERE issuer = 'https://pocketid.dropbear-butterfly.ts.net';"
sudo -u postgres psql -d hofvarpnir -c "UPDATE oidc_identities SET issuer = 'https://pocketid.homelab.internal' WHERE issuer = 'https://pocketid.dropbear-butterfly.ts.net';"
```

- [ ] Merge the consumer commit, then deploy `otel`, `containers`, `jellyfin` (one
  `just colmena-apply-host <host>` each).
- [ ] Change Forgejo's authentication source and Jellyfin's SSO plugin endpoint in
  their UIs. The OIDC clients' own callback URLs do not change.
- Verify: `UPDATE ... N` counts match the number of known users; no rows with the old issuer remain.

## 9. Verify each consumer

- [ ] Login works on Grafana, RomM, countdown (events still present), hindsight-ui,
  hofvarpnir (same account as before), Forgejo, Jellyfin.
- RomM's OIDC HTTP client trusting step-ca via `SSL_CERT_FILE`/`REQUESTS_CA_BUNDLE`
  is unverified. If its login fails with a certificate error, look there first.
- [ ] Check the new blackbox targets for Pocket ID in Prometheus.

## 10. Rollback (valid while CT 102 is intact)

- [ ] Revert the consumer commit and redeploy `otel`, `containers`, `jellyfin`.
- [ ] Reverse both UPDATEs (swap the two URLs).
- [ ] Restore the Forgejo and Jellyfin UI settings.
- [ ] `sudo systemctl stop pocket-id` on `containers`.
- DNS can stay as it is: the old issuer is the tailnet name, and the LXC never served
  a certificate for `pocketid.homelab.internal`.
- Old passkeys still work against the old hostname. Anything changed in the new
  instance after import is lost.

## 11. Decommission after a soak (suggest a week)

- [ ] Check that `/var/lib/pocket-id` (uploads) is covered by the backups of
  `containers`. The nightly Postgres dump covers only the database.
- [ ] Check dashboard links and bookmarks for the old URL.
- [ ] Stop the compose stack, then stop CT 102 and keep it stopped through one more soak.
- [ ] By hand, not by an agent: remove CT 102 from the PBS job in `/etc/pve/jobs.cfg`,
  delete the `pocketid` tailnet node, take a final backup, then `pct destroy 102`.
- [ ] Update repo references: `knowledge-base/homelab/PVE.md:109,113`;
  `infra/todo/pbs-verify-failures.md` (ct/102 is the cheap restore-test guest there
  and needs another choice); `infra/todo/pve-gigabyte-off-tailscale.md:142`.
