# TODO: join wotan to the amartum and mozart409 Nebula overlays, declaratively

Status: planned 2026-09-21. Not started.

## Context

The lighthouse fleet in `~/code/nixos-ventara-ai` (`lighthouse-{a,b,c}.oyabu.cc`)
went live on 2026-09-21 and serves two tenants: `amartum` on UDP 4242 and
`mozart409` on UDP 4343. No client has ever connected to it. wotan becomes
the first client on **both** overlays: an end-to-end test of the fleet
today, and the admin workstation that verifies vm01 once vm01 joins
amartum later.

Nebula, not WireGuard: Noise over UDP with its own certificate PKI. What
matters for this host:

- **One process per tenant.** A nebula process holds exactly one cert
  signed by one CA. Two overlays = two `services.nebula.networks.<name>`
  entries = two units (`nebula@amartum`, `nebula@mozart409`), two tun
  devices, two certs, two keys. Same shape as the lighthouses.
- Identity is a certificate signed by the tenant's CA key (both keys are
  offline in the password manager, passphrase-protected). It fixes the
  host's name, overlay IP and **groups** at signing time; changing any of
  them means re-signing.
- Permissions are per-host `firewall:` rules evaluated by the *receiving*
  host, matching on `group`/`groups`, `host` (cert name), `cidr`,
  `ca_name`, port and proto. No central policy. The lighthouses see no
  overlay traffic (no tun) and enforce nothing.
- Registry of tenant facts: `~/code/nixos-ventara-ai/services/nebula/tenants.nix`.
  Client-side contract: its `docs/nebula.md`, "What tenants need in their
  client config" and "Signing a tenant's client".

## Decisions (2026-09-21)

| Item | amartum | mozart409 | Why |
|---|---|---|---|
| UDP port (lighthouse side) | 4242 | 4343 | `tenants.nix` |
| Subnet | 172.16.10.0/24 | 172.16.20.0/24 | `tenants.nix`; the two overlays are separate address spaces, overlap would have been legal |
| Lighthouses | .1 .2 .3 | .1 .2 .3 | `tenants.nix` |
| Cert name | `wotan` | `wotan` | hostname; appears as `host: wotan` in peers' logs and rules |
| Overlay IP | `172.16.10.50/24` | `172.16.20.50/24` | .1-.3 lighthouses, .4-.49 reserved for infra (vm01 etc.), clients from .50 |
| Groups | `admin,workstations` | `admin,workstations` | admin on both. Servers (vm01 on amartum) allow `group: admin` for SSH/services. `workstations` lets a rule address all laptops/desktops without matching servers that are admin-operated. |
| Firewall on wotan | outbound any; inbound ICMP | same | a workstation offers nothing on the overlay; widen per port + group when needed |
| tun device | `nebula-amartum` (14) | `nebula-mz409` (13) | IFNAMSIZ is 15; the upstream default `nebula.mozart409` is 16 and fails eval |
| Key storage | agenix `secrets/nebula-amartum-wotan.age` | agenix `secrets/nebula-mozart409-wotan.age` | like every host secret here (`secrets.nix`, `allKeys`). NOT sops: sops on wotan is only for per-project `.sops.env` in home-manager. |
| Cert storage | `hosts/wotan/nebula/amartum-wotan.crt` + `amartum-ca.crt` | `hosts/wotan/nebula/mozart409-wotan.crt` + `mozart409-ca.crt` | certs are public; the ventara repo commits the lighthouses' the same way |
| Cert lifetime | 2y (`-duration 17520h`) | 2y | matches lighthouse host certs; CAs expire 2031-09-20 |
| Module | upstream `services.nebula.networks` | same | no wrapper needed on a client; the ventara option namespace exists for serving N tenants |

## Steps

### 1. Sign both certificates (from `~/code/nixos-ventara-ai`, CA keys restored temporarily)

```bash
cd services/nebula/certs
# amartum-ca.key and mozart409-ca.key: copy back from the password manager
# for these two commands; each prompts for its passphrase.
nebula-cert sign -ca-crt amartum-ca.crt -ca-key amartum-ca.key \
  -name wotan -networks 172.16.10.50/24 -groups admin,workstations \
  -duration 17520h -out-crt amartum-wotan.crt -out-key amartum-wotan.key
nebula-cert sign -ca-crt mozart409-ca.crt -ca-key mozart409-ca.key \
  -name wotan -networks 172.16.20.50/24 -groups admin,workstations \
  -duration 17520h -out-crt mozart409-wotan.crt -out-key mozart409-wotan.key
nebula-cert print -path amartum-wotan.crt     # name wotan, 172.16.10.50/24, groups admin,workstations
nebula-cert print -path mozart409-wotan.crt   # name wotan, 172.16.20.50/24, groups admin,workstations
rm amartum-ca.key mozart409-ca.key            # back offline
```

Client certs + keys do NOT belong in the ventara repo (docs/nebula.md 4b).
Move them out immediately:

```bash
mkdir -p /etc/nixos/hosts/wotan/nebula
mv amartum-wotan.crt mozart409-wotan.crt /etc/nixos/hosts/wotan/nebula/
cp amartum-ca.crt mozart409-ca.crt /etc/nixos/hosts/wotan/nebula/
mv amartum-wotan.key /tmp/amartum-wotan.key       # consumed by step 2, then shredded
mv mozart409-wotan.key /tmp/mozart409-wotan.key
cd -
git status --short   # must be clean: nothing of wotan's stays in this repo
```

### 2. Keys into agenix (in `/etc/nixos`)

`secrets.nix`:
```nix
"secrets/nebula-amartum-wotan.age".publicKeys = allKeys;
"secrets/nebula-mozart409-wotan.age".publicKeys = allKeys;
```

```bash
agenix -e secrets/nebula-amartum-wotan.age   < /tmp/amartum-wotan.key
agenix -e secrets/nebula-mozart409-wotan.age < /tmp/mozart409-wotan.key
shred -u /tmp/amartum-wotan.key /tmp/mozart409-wotan.key
git add secrets/nebula-*-wotan.age hosts/wotan/nebula   # Nix cannot see untracked files
```

### 3. NixOS config — `hosts/wotan/nebula.nix`, imported from `hosts/wotan/default.nix`

Option names verified against the nixpkgs nebula module on 2026-09-21
(`staticHostMap`, `lighthouses`, `isLighthouse`, `listen.*`, `tun.device`,
`firewall.*`, `settings`; the unit runs as user `nebula-<name>`;
`listen.port` already defaults to 0 for non-lighthouses).

```nix
{config, lib, ...}: let
  # One tenant = one CA = one process. Everything per tenant is in this
  # table; the module body below is identical for both.
  tenants = {
    amartum = {
      port = 4242;
      overlay = "172.16.10";
      device = "nebula-amartum"; # <= 15 chars (IFNAMSIZ)
    };
    mozart409 = {
      port = 4343;
      overlay = "172.16.20";
      device = "nebula-mz409"; # upstream default "nebula.mozart409" is 16 chars and fails eval
    };
  };

  mkSecret = t: {
    file = ../../secrets/nebula-${t}-wotan.age;
    # The upstream module runs nebula@<t> as user nebula-<t>.
    owner = "nebula-${t}";
    group = "nebula-${t}";
    mode = "0400";
  };

  mkNetwork = t: v: {
    enable = true;
    isLighthouse = false;
    ca = ./nebula/${t}-ca.crt;
    cert = ./nebula/${t}-wotan.crt;
    key = config.age.secrets."nebula-${t}-wotan".path;

    # All three lighthouses in BOTH lists: that is the whole HA config.
    # Keyed by overlay IP; the name is re-resolved every static_map.cadence.
    staticHostMap = {
      "${v.overlay}.1" = ["lighthouse-a.oyabu.cc:${toString v.port}"];
      "${v.overlay}.2" = ["lighthouse-b.oyabu.cc:${toString v.port}"];
      "${v.overlay}.3" = ["lighthouse-c.oyabu.cc:${toString v.port}"];
    };
    lighthouses = ["${v.overlay}.1" "${v.overlay}.2" "${v.overlay}.3"];

    # Client behind home NAT: dual-stack bind, ephemeral port (module
    # default for non-lighthouses), punch through.
    listen.host = "::";
    tun.device = v.device;

    firewall.outbound = [{port = "any"; proto = "any"; host = "any";}];
    firewall.inbound = [{port = "any"; proto = "icmp"; host = "any";}];

    settings = {
      # DEFAULTS TO "ip4" upstream. "ip" tries both families: wotan has no
      # IPv6 route today so it uses the A records; a v6 host the AAAA.
      static_map = {network = "ip"; cadence = "30s";};
      punchy = {punch = true; respond = true;};
    };
  };
in {
  age.secrets = lib.mapAttrs' (t: _: lib.nameValuePair "nebula-${t}-wotan" (mkSecret t)) tenants;
  services.nebula.networks = lib.mapAttrs mkNetwork tenants;
}
```

Notes:
- Do not add the tun devices to `networking.firewall.trustedInterfaces`.
  Nebula's own firewall is the overlay ACL; the host firewall on top is
  fine and wanted.
- Nothing to open in `networking.firewall`: outbound UDP, conntracked replies.
- If a nixpkgs bump fails eval with "Network device names can't be longer
  than 15 chars" *despite* the short names above, that is the inverted
  upstream assertion the ventara repo shims (its AGENTS.md, "Nebula: ...
  upstream bug"). It only bites `tun.disable = true`, which this client
  does not set, so it should not apply here.

### 4. Apply and verify

```bash
just switch   # or whatever this repo's rebuild recipe is -- see justfile
systemctl status 'nebula@*'
ip -br addr show nebula-amartum nebula-mz409            # 172.16.10.50/24 and 172.16.20.50/24
for t in amartum mozart409; do journalctl -u nebula@$t -o cat | grep -i handshake; done
# expect, per tenant, "Handshake message received" for .1 .2 .3, certName=lighthouse-a/b/c
```

Lighthouse side (proves the fleet, not just the client):

```bash
for n in a b c; do ssh amadeus@ventara-lighthouse-$n \
  "hostname; sudo journalctl -u nebula@amartum -u nebula@mozart409 --since -5m -o cat | grep -i handshake"; done
# expect on each: vpnNetworks=[172.16.10.50/24] and [172.16.20.50/24], certName=wotan
```

Each lighthouse is independent; a client reports to every one, so all
three should show both handshakes.

### 5. Afterwards

- Nothing to ping yet: the lighthouses have no tun, so `ping 172.16.10.1`
  will not answer. The first *peer* is when overlay traffic becomes
  testable -- for amartum that is vm01. Its cert should be signed with a
  group like `servers` and its nebula firewall should allow
  `{port: 22, proto: tcp, group: admin}` so wotan (admin) can SSH to it
  over the overlay; that is the connection test this todo exists for.
- Both certs expire 2028-09-20. The ventara Prometheus tracks only the
  lighthouses' certs; put a reminder somewhere that survives.
- Revocation is by expiry or by a `pki.blocklist` fingerprint on every
  other host; there is no CRL. Keys live in agenix only.
