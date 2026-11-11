# wotan: why Java 8/17/21/25 are installed

**Status 2026-11-09: research done, nothing changed.** All four JDK closures come
from one package: `prismlauncher` in wotan's `environment.systemPackages`. They
are the launcher's Java **autodetection list**, not a system-wide JDK and not
something we chose. Cost: 2.2 GiB of the launcher's 3.0 GiB closure. A fifth,
separate JDK is the Minecraft server's, which is intentional.

## The mechanism

1. `infra/hosts/wotan/default.nix:207` puts `prismlauncher` in
   `environment.systemPackages`.
2. nixpkgs' wrapper (`pkgs/by-name/pr/prismlauncher/package.nix`) has

   ```nix
   jdks ? [ jdk25 jdk21 jdk17 jdk8 ],
   ```

   and passes them to the launcher as
   `--prefix PRISMLAUNCHER_JAVA_PATHS : ${lib.makeSearchPath "bin/java" jdks}`
   Upstream ships the same wrapper (`nix/wrapper.nix:116`), with a default list of
   `jdk21 jdk17 jdk8`; nixpkgs adds `jdk25`.
3. PrismLauncher reads `${LAUNCHER_ENVNAME}_JAVA_PATHS` in
   `launcher/java/JavaUtils.cpp:159` (`addJavasFromEnv`) and folds it into the
   Java scan, so these four JREs show up in *Java Settings* as available
   runtimes. One per Minecraft era: 8 for ≤1.16, 17 for 1.17–1.20.4, 21 for
   1.20.5+, 25 for the newest.

`prismlauncher-unwrapped` itself (jdk17 is only a `nativeBuildInput` for the
launcher's Java helper jars) has no JDK in its **runtime** closure; the four come
from the wrapper's env var. Nothing else in the flake or home config asks for a
JDK, and `java` is not on `PATH`.

The headless one is unrelated and deliberate: `infra/modules/wotan/minecraft.nix`
overrides `jre_headless = pkgs.jdk21_headless` for the NeoForge 1.21.1 server
(`wotan.minecraft.enable = true`, `hosts/wotan/default.nix:120`).

## Evidence (this is verified, not inferred)

- `nix-store -q --referrers` on each of `openjdk-8u504-b01`, `-17.0.20.1+1`,
  `-21.0.12.1+1`, `-25.0.5.0.3+1` returns exactly one referrer:
  `prismlauncher-11.1.1`. Its closure contains all four plus the `jdk8` `-jre`
  output.
- The generated wrapper binary embeds the full `--prefix PRISMLAUNCHER_JAVA_PATHS`
  list; `strings` shows it, and `prismlauncher`'s `-debug`-free closure has no
  other source for these paths.
- `nix-store -qR` of `prismlauncher-unwrapped-11.1.1` contains no openjdk.
- Overriding works and is cheap to test without a system build:
  `(pkgs.prismlauncher.override { jdks = []; }).drvPath` evaluates to a wrapper
  whose args contain no openjdk at all.

Sizes (`nix path-info -S`/`--json`, unique closure paths, 112 total):

| Kept | Frees |
| --- | --- |
| all four (today) | — |
| drop `jdk25` | 657 MiB |
| `jdk8` + `jdk21` | ~1.4 GiB |
| `jdk21` only | ~1.6 GiB |
| none (`jdks = []`) | 2.2 GiB |

Per-JDK unique contribution: 8 → 197 MiB, 17 → 473 MiB, 21 → 572 MiB,
25 → 657 MiB. Launcher closure is 3.24 GB nar; without the JDKs it is ~0.9 GB.
The server's `openjdk-headless-21.0.12.1+1` (569 MiB) is a different closure
and stays.

## Why there are *eight* JDK closures in the store right now

Two nixpkgs revisions are in play, and both bundle a full set:

| nixpkgs | JDK outputs | Held by |
| --- | --- | --- |
| `1d06008` (2026-11-03) | `8u504-b01`, `17.0.20.1+1`, `21.0.12.1+1`, `25.0.5.0.3+1`, `headless-21.0.12.1+1` | running system `26.11.20261103.1d06008` (built 2026-11-06) |
| `f4a03c0` (2026-11-07) | `8u504-b01`, `17.0.20.1+1`, `21.0.13.0.2+1`, `25.0.5.0.3+1`, `headless-21.0.13.0.2+1` | the `nh os build .#wotan` running since 01:55 today (temp roots only) |

- The running system's output paths match `1d06008`'s evaluation exactly, so
  that is the rev it was built from.
- `flake.lock` was rewritten at 01:55 (`root.nixpkgs` → node `nixpkgs_7` =
  `f4a03c0`); the build started 14 s later and pulled that rev's JDK set
  (downloaded 02:09–02:18). Those paths are held only by that build's
  `/nix/var/nix/temproots` entry (they show as `{censored}` in
  `nix-store --gc --print-roots`), so `just cleanup-wotan` collects them once
  the build is done or discarded.
- The same version can appear twice with different hashes (`25.0.5.0.3+1` as
  `59hn3l…` and `a50pz8…`): different nixpkgs, so different stdenv/deps. Not a
  second install source.

Side effect for the pending switch: the new rev moves the launcher's and the
server's Java 21 from `21.0.12.1+1` to `21.0.13.0.2+1` (same Java 21, patch
bump). NeoForge 1.21.1 is unaffected, but it will show in the `nh` diff and in
the server's rebuild.

## What the launcher does with the list

It is an autodetection list, so the *effective* Java for an instance is whatever
that instance's `javaPath` (or the global `JavaPath`) says, otherwise what
PrismLauncher picks from the scanned list for the game version. The launcher also
ships a built-in Java downloader (Adoptium/Mojang): `AutomaticJavaDownload`
defaults to `JavaPath`-is-empty, and downloaded runtimes land in
`~/.local/share/PrismLauncher/java` (the Java settings UI calls that folder "Java
versions"). So the four store JREs are an offline fallback, not a hard
requirement.

Not verifiable from here: the agent's mount namespace hides `/home/amadeus`, so
`~/.local/share/PrismLauncher/prismlauncher.cfg` and each instance's
`instance.cfg` (`javaPath`) can't be read. Checking whether the store JREs are
actually in use needs amadeus's own shell.

## Directions (not decided, do not implement yet)

1. **Keep it.** Upstream default, zero maintenance, bounded to 2.2 GiB by
   Nix's dedup.
2. **`jdks = []`** — pure downloader. Frees 2.2 GiB, but breaks playing offline
   and any instance with an explicit `javaPath` into the store; also trusts the
   downloader's per-version choice.
3. **Trim to what is played.** e.g. `prismlauncher.override { jdks = [ pkgs.jdk8 pkgs.jdk21 ]; }`
   (frees ~1.4 GiB) or `[ pkgs.jdk21 ]` (~1.6 GiB), letting the downloader cover
   the rest. This is one line in `hosts/wotan/default.nix` and needs the Java
   settings left on "download".
4. **Drop `prismlauncher` entirely** if the desktop launcher is unused (the
   server module does not need it). Frees the whole 3.0 GiB; only worth it if
   nobody plays through the launcher.

Whatever is chosen, a short comment next to the package should say that the JDK
set comes from the wrapper default, so the next `ls /nix/store | grep openjdk`
audit does not re-open this.

## Verification (once a direction is picked)

- `nix eval --raw .#nixosConfigurations.wotan.config.system.build.toplevel.drvPath`
  with the override; never a bare `nix flake check` (OOM).
- `just build-wotan` and read the `nh` diff: the prismlauncher closure should
  shrink by the amount above and nothing else should move. The user runs
  `just switch-wotan`; agents never deploy.
- After the switch, `just cleanup-wotan` (GC, keeps 2 generations), then
  `ls /nix/store | grep -c openjdk` should be 1 (the server's headless).
- If the launcher was trimmed, start the oldest and newest instance that get
  played and confirm they still launch (Java version chosen correctly).
