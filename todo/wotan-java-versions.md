# wotan: why are Java 17, 21 and 25 installed?

**Status 2026-11-09: research only, nothing changed.** Observed four JDK
closures in the store and no `java` on `PATH`. First pass below already points
at one package; the open questions are what to do about it.

## What the store shows

`ls -d /nix/store/*-openjdk*` on wotan (running system
`nixos-system-wotan-26.11.20261103.1d06008`):

| Closure                                  | Reached from            |
| ---------------------------------------- | ----------------------- |
| `openjdk-17.0.20.1+1`                    | `prismlauncher-11.1.1`  |
| `openjdk-21.0.12.1+1`                    | `prismlauncher-11.1.1`  |
| `openjdk-25.0.5.0.3+1`                   | `prismlauncher-11.1.1`  |
| `openjdk-8u504-b01` + `…-jre`            | `prismlauncher-11.1.1`  |
| `openjdk-headless-21.0.12.1+1`           | `services.minecraft-servers` (automation server) |

- None of them is on `PATH` (`java -version` → command not found), and nothing
  in `environment.systemPackages` asks for a JDK directly.
- Every one of the four non-headless closures has the same single referrer,
  `prismlauncher`, which is in wotan's `environment.systemPackages`
  (`infra/hosts/wotan/default.nix:207`). `prismlauncher`'s own runtime closure
  lists all four, so this is upstream packaging (the launcher bundles one JRE
  per Minecraft-era Java requirement), not something we added.
- The headless 21 is separate: `infra/modules/wotan/minecraft.nix` overrides
  `jre_headless = pkgs.jdk21_headless` on the NeoForge 1.21.1 server, with a
  comment saying vanilla 1.21.1 targets Java 21. That one is intentional and
  independent of the launcher.

First guess before verifying: `prismlauncher` carries them for
backwards-compatible launching of old Minecraft versions (1.16 and earlier need
Java 8, 1.17–1.20 Java 17, 1.20.5+ Java 21, newer snapshots Java 25).

## Open questions

- Which of the four are actually needed at runtime versus unconditional
  `buildInputs`/`runtimeDeps` in the nixpkgs expression? Check
  `nixpkgs/pkgs/by-name/pr/prismlauncher` (or `games/minecraft/prismlauncher`)
  and whether it exposes an option for "only the newest JRE" or resolves JDKs
  at launch instead.
- Does the launcher use these bundled JREs at all, or download/manage its own
  under `~/.local/share/PrismLauncher/java`? If it manages its own, the store
  closures are dead weight.
- What is the actual disk cost (`nix path-info -Sh` per closure, plus the
  shared JRE dependencies) and does it survive GC? They are rooted by
  `current-system`, so yes until prismlauncher leaves the config.
- Is the Java 8 pair also worth counting (it is not on `PATH` either)? The
  original report said 17/21/25, but 8 comes along the same path.
- Is any other host or profile pulling JDKs (e.g. an old generation, a
  devshell, `jdks` in a home profile)? Only wotan's system profile is rooted
  for these four.

## Possible directions (not decided, do not implement yet)

- Accept it: `prismlauncher` is deliberate, the closures are what the package
  ships, and the cost is bounded by Nix's dedup.
- Drop `prismlauncher` from system packages if the Minecraft server module is
  the only thing actually used (it does not need the desktop launcher).
- Override/patch prismlauncher to a single JRE (e.g. 21) and set the launcher's
  per-instance Java path in its config — needs testing against old versions.
- Pin the downstream choice in `infra/hosts/wotan/default.nix` with a comment so
  the next `ls /nix/store | grep openjdk` audit is a non-event.

## Verification (once a direction is picked)

- `nix-store -qR $(nix path-info --derivation …)/…` or
  `nix why-depends /run/current-system $(nix eval --raw .#…prismlauncher)` to
  confirm the remaining JDK closure.
- `just build-wotan` and read the `nh` diff before `just switch-wotan`; the
  user deploys and checks.
