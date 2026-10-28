# AGENTS.md - wotan (desktop)

Desktop-specific guide for `wotan`, the main workstation (Hyprland, NVIDIA, Podman). The fleet's conventions are in `infra/AGENTS.md`; this file adds what only applies to the desktop.

## 🏗️ Where wotan Lives

wotan is one host in the `yggdrasil` monorepo (`~/code/yggdrasil`, Forgejo canonical). The flake is at the **repo root**; run every command below from there. Paths in this file are relative to `infra/` unless they start with `infra/`.

**Architecture:**
- `flake.nix` (repo root) - one flake and one lock for wotan **and** the fleet
- `hosts/wotan/` - system config (`default.nix`), home-manager config (`home.nix`), `switch.sh`
- `modules/wotan/` - wotan-only NixOS modules; `default.nix` aggregates them plus `modules/desktop/`
- `modules/desktop/` - Hyprland, file managers, user experience
- `modules/home/` - home-manager user modules (`configs/`, `packages/`, `services/`)
- `lib/mkConfigs.nix` - `mkDesktop` helper and the wotan-only nixpkgs config (CUDA)
- `secrets/` + `secrets/agenix-rules.nix` - agenix secrets, **shared with the fleet**; wotan's rules are `[amadeus hostWotan]`

**wotan deploys only itself.** It is not a `colmenaHive` node, has no inbound SSH (the firewall has no open TCP ports), and must never import the fleet's `modules/common.nix` or `modules/server.nix`, which turn sshd on. It imports `modules/base.nix` (timezone, locale, keymap, flakes, trusted-users, the `amadeus` account) and nothing else from the fleet; an assertion in `hosts/wotan/default.nix` fails evaluation if sshd, TCP 22 or Tailscale SSH ever gets enabled. Nothing in the fleet tooling reaches it.

**Neovim:** The nixvim configuration lives in its own repo, consumed as the flake input `mozart409-nixvim` (`github:Mozart409/mozart409-nixvim`). Neovim changes happen there, then `nix flake update mozart409-nixvim` here.

**User:** `amadeus`

## 🤖 Bots May Change wotan's Config (decided 2026-10-05)

The coding agents (`developmentbot` on `development`, `hermes`, and later the
Agent Platform bots) have **full write access to wotan's configuration**, the
same trust they have for the homelab. A bot commit to `infra/hosts/wotan/`,
`infra/modules/{wotan,desktop,home}/` or `infra/lib/` is normal work, not
something to avoid.

What keeps that safe is **who deploys**, not who edits:

- **Nothing reaches wotan until the user runs `just switch-wotan` on wotan
  itself.** There is no colmena node, no inbound SSH and no deploy key for
  wotan anywhere. A bot never deploys wotan and never asks to; it commits,
  pushes to Forgejo and says what the user should switch and check.
- **The user reviews at switch time.** `just build-wotan` (or the switch itself)
  prints the `nh` diff against the running system. Say in the commit or the
  hand-off what that diff should contain, so an unexpected package or service
  stands out.
- **Evaluation guards still apply.** The pre-push gate evaluates wotan for any
  push touching its files, and `hosts/wotan/default.nix` asserts that sshd,
  TCP 22 and Tailscale SSH stay off. Never weaken those assertions to make a
  change evaluate; that change is wrong.
- **A switch publishes.** `switch.sh` pushes to Forgejo and then runs
  `just export-github`, which publishes the `exports.toml` prefixes (`infra/`
  and the public Rust projects) to GitHub, so a bot commit there becomes
  public on the user's next switch. Nothing private in `infra/`.
- **NVIDIA driver bumps need `just switch-wotan -r`** (boot mode, pitfall #8).
  If a bot change moves the driver (usually via `flake.lock`), say so in the
  hand-off.

## 🔒 Local Agents Run as `agent` (2026-10-27)

Claude Code and opencode on wotan run as the no-sudo `agent` account
(`modules/wotan/agent-user.nix`, home-manager in `hosts/wotan/agent-home.nix`),
not as `amadeus`. Every agent process runs in a mount namespace where `/home`
and `/run/user` are empty except `/home/amadeus/code` and `/home/agent`, bound
back in at their real paths. So the agents can't see the rest of amadeus's
home, amadeus's session sockets (gpg, ssh, Wayland, D-Bus) or `/run/agenix`.

- **Launch:** `claude`, `pi` and `opencode <subcommand>` are zsh functions that
  run `sudo agent-run claude|opencode|pi …`. `agent-run` is the only thing
  amadeus may sudo to without a password. It refuses to start outside `~/code`,
  passes the MCP gateway tokens (and pi's `OPENCODE_API_KEY`, from
  `secrets/opencode-zen-env.age`) in as systemd credentials, and loads the directory's
  `.envrc` (the agent's own `direnv allow`). Interactive `opencode` is a client
  of `opencode-serve`, which runs as `agent` in the same confinement.
- **State lives in `/home/agent`:** `~/.claude`, `~/.claude.json`,
  `~/.config/opencode`, `~/.local/share/opencode`. A Claude permission rule for
  a file in the repo needs the absolute form (`Read(//home/amadeus/code/…)`):
  `~` now means `/home/agent`.
- **Sharing `~/code`:** ACLs give both users rwx. The default ACLs make new
  files inherit that (tmpfiles keeps it on `~/code` itself). A file created
  with a narrow mode (e.g. 0644 by a tool that ignores umask) gets a narrow
  ACL mask; `just agent-acl` repairs the whole tree. `safe.directory` in
  `/etc/gitconfig` lets git work in repos the other user owns.
- **Commit signing:** each harness has its own ssh-agent holding the bot key
  `~amadeus/.ssh/id_ed25519_signing` (bot-signing@wotan):
  `opencode-signing-agent` and `claude-signing-agent`
  (`services.opencode-serve.signing.agents`). They run as `agent`, because
  ssh-agent refuses clients with another uid. systemd hands them the key as a
  credential, and that credential dir is hidden in every agent session, so
  the agents can sign but cannot read the key.
- **Gone for the agents:** clipboard and image paste, opening a browser,
  `sops exec-env`/gpg, podman, and pushing over SSH (they never pushed from
  wotan anyway).
- **Tests:** `nix build .#nixosTests.x86_64-linux.agent-user`
  (`infra/tests/modules/agent-user.nix`).
- **First switch:** after `just switch-wotan`, run `just agent-acl` once, then
  `just agent-migrate` (copies the Claude/opencode logins, history, memory and
  direnv allows into `/home/agent` and restarts opencode-serve).

## ⚡ Build/Test/Lint Commands

### Building and Switching Configurations

```bash
# Preferred: the user's normal workflow (infra/hosts/wotan/switch.sh)
just switch-wotan             # nh os switch, skipping unreachable substituters, then git push to ALL remotes
just switch-wotan -r          # nh os boot instead (NVIDIA driver bumps, pitfall #8); reboot manually
just switch-wotan-local       # switch only: no git push, GitHub export or attic push (-r works too)

# Other wotan recipes in the root justfile
just build-wotan              # = nh os build .#wotan (real build, not a dry run)
just build-home-wotan         # = nix build ...home-manager.users.amadeus.home.activationPackage --dry-run
just test-wotan               # = sudo nixos-rebuild test --flake .#wotan
just cleanup-wotan            # GC nix (keep 2), drop result links + cargo targets, clear npm/pnpm caches, prune podman (rootless + rootful)/journal/tmp
just cleanup-wotan -n         # dry run: list what would go, remove nothing

# Using nh directly; programs.nh.flake is preset to ~/code/yggdrasil
nh os switch .#nixosConfigurations.wotan
```

**Note:** `nh` is enabled via `programs.nh` in `modules/wotan/basics.nix` with the default flake set to `/home/amadeus/code/yggdrasil`. The root flake has many `nixosConfigurations`, so name `wotan` explicitly.

### Validation and Linting

```bash
# Format all Nix files with Alejandra (REQUIRED before commits)
alejandra .                  # Format all files
alejandra {staged_files}     # Format staged files only

# Validate: evaluate only wotan. Never a bare `nix flake check` -- it evaluates
# every fleet host and has been OOM-killed.
nix eval --raw .#nixosConfigurations.wotan.config.system.build.toplevel.drvPath

# Update dependencies (run as YOUR USER, never sudo — sudo breaks flake.lock ownership).
# One lock: an update moves wotan AND every fleet host.
just update                 # nix flake update, commits flake.lock only
just update-input nixpkgs   # Update a single input

# Development shell (direnv loads it automatically at the repo root)
nix develop

# MCP Servers (if available)
# Use context7 or grepmcp for enhanced code search and documentation queries
```

### Git Hooks

**Hooks** (root `lefthook.yml`, installed by the dev shell):
- pre-commit: `alejandra` and `keep-sorted` on staged files, `just --fmt`, `shellcheck` on staged `.sh` (fixers re-stage automatically)
- commit-msg: `cog verify`

**NEVER** commit unformatted Nix code. Always run `alejandra` first.

### Git Configuration

Set a short SSH connect timeout so git operations fail fast instead of hanging on an unreachable remote:

```bash
git config core.sshCommand "ssh -o ConnectTimeout=5"
```

## 📝 Code Style Guidelines

### Nix File Structure

```nix
{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  # Imports first
  imports = [
    ./module1.nix
    ./module2.nix
  ];

  # Then configuration options, grouped logically
  networking.hostName = "example";
  
  # Package lists
  environment.systemPackages = with pkgs; [
    package1
    package2
  ];
}
```

### Imports and Dependencies

- **Import order:** External inputs, local modules, then configuration
- **Use relative paths:** `../../modules/` not absolute paths
- **Explicit inputs:** Declare all used parameters in function signature
- **Common params:** `config, pkgs, inputs, lib, ...` (in this order)

### Formatting Rules (Alejandra)

Alejandra enforces layout (2-space indent, wrapping, one list item per line) — run `alejandra .` and don't hand-format. Beyond that: use `let-in` for repeated values, and `"${variable}"` for interpolation (`''${literal}''` in multi-line strings).

### Types and Validation

- **Type annotations:** Use `lib.mkOption` with `type` for custom modules
- **Defaults:** Provide sensible defaults with `lib.mkDefault`
- **Conditionals:** Use `lib.mkIf` for conditional configuration
- **Force overrides:** Use `lib.mkForce` sparingly (document why)

```nix
# Example custom option
options.desktop.enable = lib.mkOption {
  type = lib.types.bool;
  default = false;
  description = "Enable desktop environment";
};
```

### Naming Conventions

- **Files:** `kebab-case.nix` (e.g., `common-packages.nix`, `disko-config.nix`)
- **Attributes:** `camelCase` for Nix attributes (e.g., `hostName`, `autoLogin`)
- **Hosts:** lowercase, descriptive (e.g., `wotan`, `servarr`)
- **Modules:** Descriptive, grouped by function (e.g., `modules/desktop/`)
- **Variables:** `camelCase` for locals, match upstream naming for overrides

### Error Handling

- **Validation:** Use assertions for required conditions
- **Warnings:** Use `lib.warn` for deprecations or potential issues
- **Assertions:** Fail fast with clear messages

```nix
assertions = [
  {
    assertion = config.desktop.enable -> config.services.xserver.enable;
    message = "Desktop requires X server to be enabled";
  }
];
```

## 🔧 Configuration Patterns

### Adding New Packages

**System-level** (`modules/wotan/common-packages.nix`):
```nix
environment.systemPackages = with pkgs; [
  newpackage
];
```

**User-level** (host's `home.nix` or `modules/home/`):
```nix
home.packages = with pkgs; [
  newpackage
];
```

### Adding Another Desktop Host

Servers use the fleet's `mkHost` (see `infra/AGENTS.md` §5). A second desktop would follow wotan:

1. Create `hosts/{hostname}/` with `default.nix` (system config) and `home.nix` (user config)
2. Generate hardware config: `nixos-generate-config --show-hardware-config`
3. Add it to `nixosConfigurations` in the root `flake.nix` with `desktop.mkDesktop "hostname" system "username"` (defined in `lib/mkConfigs.nix`).
   `username` is threaded through `specialArgs`/`extraSpecialArgs`, so shared
   modules take it as a function arg (`{username, ...}`) instead of hardcoding `amadeus`.
4. Import the desktop modules via the aggregator: `../../modules/wotan` (imports every
   desktop module; each optional one is gated by its own `enable` flag — e.g.
   `hardware.moza.enable`, `programs.claudeCodeMcp.enable`, `desktop.enable`).
5. Keep it out of `colmenaHive`.

### Module Organization

- **Desktop config:** Goes in `modules/{wotan,desktop,home}/`
- **Host-specific:** Goes in `hosts/{hostname}/`
- **Optional features:** Use enable flags (e.g., `desktop.enable`)
- **Conditionals:** Use `lib.mkIf config.feature.enable { ... }`

## 🎯 Testing Changes

### Single Configuration Test

For quick iteration on a specific host:

```bash
# System config (won't persist after reboot)
sudo nixos-rebuild test --flake .#wotan
```

### Full Validation Pipeline

Before committing changes:

1. **Format:** `just fmt`
2. **Validate:** the scoped `nix eval` of wotan above (not `nix flake check`)
3. **Build test:** `just build-wotan`
4. **Build home test:** `just build-home-wotan`
5. **Test config:** `just test-wotan` (if changing system)
6. **Commit:** single-line conventional commit (`fix(wotan): …`)
7. **Switch:** `just switch-wotan` to persist — the user runs it; note it also pushes to Forgejo and exports the public prefixes to GitHub

## 🚨 Common Pitfalls

1. **Forgetting to format:** Always run `alejandra` before committing
2. **Absolute paths:** Use relative paths from current file location
3. **Unfree packages:** Already configured globally, no need to add per-package
4. **Home-manager vs NixOS:** System services in NixOS modules, user config in home-manager. Home-manager is integrated via `home-manager.nixosModules.home-manager` so a single `nixos-rebuild switch` activates both.
5. **Rebuilds require sudo, updates do NOT:** System rebuilds need `sudo`, but `nix flake update` must run as the regular user — running it with sudo makes `flake.lock` root-owned and breaks later user-level updates.
6. **Secrets:** Use agenix for sensitive data (see `age.secrets` in wotan config)
7. **Systemd sandboxing:** Services with `DynamicUser=true` and `ProtectHome=true` cannot access `/home/`. Use state directories (e.g., `/var/lib/<service>/`) instead.
8. **NVIDIA driver version bumps break `nh os switch`:** the NVIDIA container CDI generator runs against the new driver while the old kernel module is still loaded (NVML mismatch). After a flake update that bumps the driver, use `sudo nixos-rebuild boot --flake .#wotan` and reboot instead of switching live.
9. **Bluetooth audio dropouts / stalled connections (Intel AX210):** the AX210 controller (USB `8087:0032`) defaults to a 2s USB autosuspend that powers the radio down mid-stream, causing kernel `hci0: link tx timeout` -> `killing stalled connection`, `spa.bluez5: Acquire ... org.bluez.Error.Failed`, and "missing completion reports ... firmware bug?" in WirePlumber — A2DP sinks flicker in and out and no audio plays. Enough killed connections wedge the controller until it sees zero devices even after a USB rebind (needs a reboot to recover). Fixed declaratively by `boot.extraModprobeConfig = "options btusb enable_autosuspend=0"` in `modules/desktop/default.nix`; the modprobe option only applies on the next `btusb` load, so rebuild + reboot. Diagnose with `journalctl -k -b | grep hci0` and `journalctl --user -u wireplumber | grep bluez`.
10. **`hl.dsp.dpms` silently toggles on a wrong field name (Hyprland 0.56 Lua):** the Lua dpms dispatcher parses its table with `tableToggleAction(field = "action")`, and an unrecognized field — e.g. `{ state = "on" }`, which looks plausible — SILENTLY falls back to `TOGGLE` instead of setting an explicit state. That desyncs the compositor's dpms state from the panels: `hyprctl monitors` reports `dpmsStatus=true` while both monitors sit in power save with no video signal, and key presses (which still reach the session) stop waking them. Always use `hl.dsp.dpms({ action = "on" })` / `{ action = "off" }` (also accepts `enable`/`disable`) in hypridle.conf etc. Field names verified against `src/config/lua/bindings/LuaBindingsInternal.{hpp,cpp}` at the pinned commit — check there, not the wiki, when adding new Lua dispatchers.
11. **MCP secrets in opencode.json must be in the SERVER's environment, not the login shell:** with `services.opencode-serve` enabled, every interactive `opencode` is wrapped to `opencode --server $OPENCODE_SERVER_URL "$PWD"`, so `{env:VAR}` placeholders in MCP headers (e.g. axon-gateway's `Authorization: Bearer {env:AXON_GATEWAY_TOKEN}`) are expanded by the long-running systemd service — which has a minimal environment and never sees `home.sessionVariablesExtra`. Symptoms: `server unavailable / status=failed` in `~/.local/share/opencode/log` and HTTP 401 from the gateway while curl from a shell works fine. Fix: pass the agenix secret (must be in `KEY=value` format) via `services.opencode-serve.environmentFiles` and rebuild; the unit change restarts the service. Note the context7 secret is a raw token (no `KEY=` prefix) so it cannot be used as an EnvironmentFile until re-encrypted in `KEY=value` form — it currently only works because context7 allows unauthenticated (rate-limited) access.

12. **opencode reads `.env` via bash, not the read tool:** opencode's `permission.read` rules (default `*.env: ask` in 1.18) only gate the `read` tool; the bash tool matches `permission.bash` globs against the parsed command and never applies read rules to file arguments, so `cat .env`, `sed -n p .env`, `printenv`, `agenix -d …` are plain `allow`. Guardrails live in `modules/home/packages/opencode.nix` (`opencode.guardrails.enable`, on by default, independent of `opencode.enable`): `~/.config/opencode/plugins/secret-guard.js` hard-blocks secret paths / reveal commands in `tool.execute.before` and redacts token-shaped values in `tool.execute.after`, plus baseline deny rules in `~/.config/opencode/config.json` (merged first, so `opencode.json(c)` / project `.opencode/` still override). Test the plugin logic with node before rebuilding; verify live with `opencode run "print .env"` in a dir with a dummy `.env`.

13. **A stale avahi PID file fails `nixos-rebuild switch` (exit 4) with nothing obviously related in the output:** `avahi-daemon.service` has no `RuntimeDirectory=`, so `/run/avahi-daemon/pid` survives a daemon that dies without cleaning up, and avahi cannot clear it itself -- libdaemon's `daemon_pid_file_remove()` only unlinks a PID file containing its *own* pid (a guard against killing another instance). Every later start then logs `Process <pid> died ... trying to remove PID file`, `open(/run/avahi-daemon//pid): File exists`, `Failed to create PID file`, and exits 255 -- which surfaces only as `warning: the following units failed: avahi-daemon.service` plus `Activating configuration (exit status ExitStatus(Exited(4)))`. Fixed declaratively by the `ExecStartPre=-rm -f /run/avahi-daemon/pid` on `systemd.services.avahi-daemon` in `modules/desktop/default.nix` (`RuntimeDirectory=` would be tidier but systemd would wipe the directory on stop, taking `/run/avahi-daemon/socket` -- owned by the `avahi-daemon.socket` unit this one `Requires=` -- with it). Two traps while recovering by hand: repeated failures latch the unit into `start-limit-hit`, where `systemctl start` is **refused without executing anything** (no fork, no journal line -- if a start produces no new log entry, check for the latch before assuming the daemon died), so `systemctl reset-failed avahi-daemon.service avahi-daemon.socket` first; and `is-active` polled immediately after `start` can read `inactive` on this `Type=dbus` unit because start returns before the bus name settles. Diagnose with `journalctl -u avahi-daemon -o short-precise` and `ls -la /run/avahi-daemon/`. Note avahi is load-bearing here only for the CUPS printer's `.local` URI (`ipp://EPSONEB3A2A.local:631/ipp/print`), which mDNS alone can resolve.

14. **Removing a Hyprland plugin needs a relogin — never `hyprctl plugin unload` it live:** plugins are loaded only at login, so dropping one from `modules/home/packages/hyprland-configs.nix` (rendered to `~/.config/hypr/plugins.lua`) and switching leaves the old `.so` running. Unloading it live is worse: on 2026-09-26 `hyprctl plugin unload` removed hyprfocus from `hyprctl plugin list` and deleted its config values, but `libhyprfocus.so` stayed mapped with its focus-change listener still hooked. 35 minutes later a layer surface closing (Quickshell launcher) triggered `refocusLastWindow`, and the listener read its deleted `CStringValue`, which made `operator new` throw. Hyprland SIGABRTed, which took down xdg-desktop-portal-hyprland, hypridle, hyprsunset and awww-daemon too, and the machine needed a reboot. After removing a plugin, log out and back in. Diagnose Hyprland crashes with `coredumpctl list` / `coredumpctl info <pid>` and `~/.cache/hyprland/hyprlandCrashReport<pid>.txt`. A plugin frame in the main-thread stack names the culprit, even one missing from the report's plugin list.

## 🦙 llama.cpp Inference Server

`services.llama-cpp` in `hosts/wotan/default.nix` (the stock nixpkgs module; `package` is overridden with `cudaSupport = true`, since it is off globally) runs `llama-server` as **`llama-cpp.service`**. It serves the OpenAI-compatible API (`/v1/chat/completions`, `/v1/completions`, `/v1/models`, …) on **http://127.0.0.1:10808/v1**, loopback only, plus the built-in web UI at http://127.0.0.1:10808. Inference endpoints need the API key from `secrets/llama-cpp-api-key.age` (see **API key** below); SillyTavern is the chat front end (see **SillyTavern**).

- **Not started at boot** (`wantedBy = lib.mkForce []`): the model pins ~9 GiB of the 3060's 12 GiB. Start and stop it from the Quickshell panel (see **AI Service Toggles**) or by hand (`sudo` optional: polkit allows start/stop/restart):
  ```bash
  sudo systemctl start llama-cpp
  journalctl -u llama-cpp -f
  sudo systemctl stop llama-cpp
  ```
- **Model:** `Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf`, 64K context, one slot, q8_0 KV cache, thinking off by default (`reasoning = "off"`; a request can send `"chat_template_kwargs": {"enable_thinking": true}`). The VRAM math and the fallback (halve `ctx-size`, or the Q4_K_M file) are in the comment above the block.
- **Model dir:** `/var/lib/llama-cpp-models`, owned by `amadeus` via `systemd.tmpfiles.rules`, so downloads need no sudo. The service runs as a `DynamicUser` with `ProtectHome=true` and cannot read `~/models` (pitfall #7); world-readable files under `/var/lib` are fine.
- **Download** (from the repo root; the dev shell sets `AGENIX_RULES` and agenix uses your default identity):
  ```bash
  (cd infra/secrets && HF_TOKEN=$(agenix -d hf-token.age | sed -n 's/^HF_TOKEN=//p') hf download HauhauCS/Qwen3.5-9B-Uncensored-HauhauCS-Aggressive Qwen3.5-9B-Uncensored-HauhauCS-Aggressive-Q6_K.gguf --local-dir /var/lib/llama-cpp-models)
  ```
- **Switch models:** download another GGUF into `/var/lib/llama-cpp-models`, point `services.llama-cpp.settings.model` at it (and adjust `ctx-size`/sampling for that model), then `just switch-wotan`. The switch restarts the unit if it is running; otherwise `sudo systemctl start llama-cpp`.
- **Settings are CLI flags:** each `settings` key becomes `--key value` on `ExecStart`, so values cannot contain spaces or quotes (no inline JSON). Check flag names against `tools/server/README.md` at the llama.cpp tag matching `pkgs.llama-cpp.version`.

### API key

llama-server requires an API key from `secrets/llama-cpp-api-key.age` (rule `[amadeus hostWotan]`): the raw key on one line, no `KEY=` prefix. The agenix secret stays `root:root 0400`; systemd hands it to the `DynamicUser` as a credential (`LoadCredential`), and the module passes only the path, `--api-key-file /run/credentials/llama-cpp.service/api-key`. llama.cpp reads that file line by line, verbatim (no trimming, so no trailing spaces or CRLF), skipping empty lines and lines starting with `#`.

- **Create or rotate** (bare filename, works from any directory in the dev shell):
  ```bash
  pwgen -s 48 1 | agenix -e llama-cpp-api-key.age   # piped input skips the editor
  git add infra/secrets/llama-cpp-api-key.age        # the flake only sees tracked files
  just switch-wotan
  ```
  Every use of the key is gated on `builtins.pathExists` of the `.age` file, so wotan evaluates without it; then llama-server runs **without** a key and evaluation prints a `warning:` saying so. An untracked `.age` file counts as missing. `restartTriggers` on the `.age` file restart `llama-cpp` (if it is running) and `sillytavern` when the key changes; a stopped `llama-cpp` stays stopped.
- **Use it:** `Authorization: Bearer <key>` (llama.cpp also accepts `X-Api-Key: <key>`).
  ```bash
  KEY=$(sudo cat /run/agenix/llama-cpp-api-key)
  curl -s http://127.0.0.1:10808/v1/chat/completions \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -d '{"messages":[{"role":"user","content":"Hello"}]}'
  curl -si http://127.0.0.1:10808/props | head -1   # no key: HTTP 401
  ```
- **Still unauthenticated** (`tools/server/server-http.cpp` at b10408): `/health`, `/v1/health`, `/models`, `/v1/models` and the built-in web UI's static files. A client's "connection check" against `/v1/models` therefore succeeds with a wrong key; only completions return 401. The built-in web UI at http://127.0.0.1:10808 needs the key pasted into its settings.

### SillyTavern

`services.sillytavern` (stock nixpkgs module, SillyTavern 1.18.0 in global mode) runs **`sillytavern.service`** as the static `sillytavern` user, **started at boot**: it is a small node process and has no dependency on `llama-cpp`, so it never loads the model.

- **URL:** http://127.0.0.1:8045 (port 8045, not the default 8000, which dev servers like to take). `listen` is off, which binds 127.0.0.1 only; IPv6 is off; no firewall port. Config is SillyTavern's own `default/config.yaml` (whitelist mode for 127.0.0.1/::1, no basic auth, no user accounts); the module's default `configFile` points at a `config.yaml` the package does not ship. Override single keys with `SILLYTAVERN_<KEY>` environment variables on the unit (e.g. `SILLYTAVERN_BROWSERLAUNCH_ENABLED=false`, already set).
- **Data:** `/var/lib/SillyTavern/data/default-user` (chats, characters, `settings.json`, `secrets.json`); `/var/lib/SillyTavern/extensions` holds third-party extensions. All of it is mutable state outside Nix.
- **API key, seeded:** the unit loads the same agenix secret as a credential and its `preStart` upserts it with `jq` into `secrets.json` as the active `api_key_llamacpp` entry (id `agenix`), leaving every other secret alone. Llama.cpp keys typed into the UI are kept but deactivated on the next start, so the agenix key always wins.
- **Connect once in the UI** (the server URL lives in the browser-written `settings.json`, so it is not seeded): start `llama-cpp`, open http://127.0.0.1:8045, then **API Connections** (plug icon) → **API: Text Completion** → **API Type: llama.cpp** → **API URL** `http://127.0.0.1:10808` (no `/v1`) → leave the key field empty (it already shows a saved key) → **Connect**. Alternatively **Chat Completion** → **Custom (OpenAI-compatible)** at `http://127.0.0.1:10808/v1`, but that uses a separate secret (`api_key_custom`) that is not seeded, so paste the key there yourself.

## 🎨 ComfyUI

`services.comfyui` in `hosts/wotan/default.nix` (stock nixpkgs module) runs **`comfyui.service`** as the static `comfyui` user: web UI and API on **http://127.0.0.1:8188**, loopback only, no auth.

- **CUDA via wheels:** `cudaSupport` is off globally, so the package's Python set swaps `torch`/`torchvision` for `torch-bin`/`torchvision-bin` (prebuilt PyTorch wheels, CUDA 13). torch-dependent Python packages rebuild against them; no CUDA compile happens. `comfy-kitchen` is built without its CUDA kernels.
- **No Triton JIT** (`TORCH_DISABLE_NATIVE_JIT=1` in the unit's environment): torch 2.14 sends some ops through Triton kernels, which compile a C helper on first use and fail under systemd with `Failed to find C compiler`. The variable makes torch use its regular CUDA kernels. Don't enable comfy-kitchen's Triton backend or `torch.compile` nodes without also giving the unit a compiler.
- **Not started at boot** (`wantedBy = lib.mkForce []`): llama-cpp already pins ~9 GiB of the 12 GiB, and ComfyUI keeps loaded models in VRAM. Run one at a time on large models (the Quickshell panel warns when both are up):
  ```bash
  sudo systemctl stop llama-cpp; sudo systemctl start comfyui
  journalctl -u comfyui -f
  ```
- **Models:** `/var/lib/comfyui-models/<folder>` (`checkpoints`, `diffusion_models`, `text_encoders`, `vae`, `loras`, `clip_vision`, `controlnet`, `upscale_models`, `embeddings`), owned by `amadeus` via tmpfiles, so downloads need no sudo; wired in with a generated `--extra-model-paths-config`. Add a folder there and in the YAML for other model types. Files ComfyUI writes (outputs, inputs, custom nodes, `user/comfyui.db`) live in its state dir `/var/lib/comfyui` (0700 `comfyui`).
- **Custom nodes:** ComfyUI-Manager is not enabled; it pip-installs node dependencies, which cannot land in the Nix Python env. Add Python deps through `services.comfyui.extraPackages` instead.

## 🎛️ AI Service Toggles (Quickshell + polkit)

A Quickshell panel switches `llama-cpp`, `comfyui` and `sillytavern` on and off without sudo. It is built like the Home Assistant light panel: same card, rows and switches, bottom-left on the primary screen, visible on an empty workspace (`WlrLayer.Bottom`).

- **One list:** `aiServiceToggles` at the top of `hosts/wotan/default.nix` (unit, label, optional `note`, `gpu` flag). It feeds `desktop.quickshell.serviceToggles` (the panel) **and** the polkit rule, so adding a unit there adds both the switch and the permission. Only `.service` names are accepted.
- **Panel:** `modules/home/packages/quickshell/ServiceTogglesWidget.qml`, gated by `Features.serviceToggles` in `shell.qml`. It never calls systemctl itself: the `quickshell-units` script (`modules/home/packages/quickshell.nix`) reads every unit's state with one `systemctl show` call (every 10 s, every 1 s while a unit is starting or stopping) and runs `systemctl --no-ask-password --no-block start|stop` only for listed units. Green = running, amber pulsing = activating/deactivating, red = failed (a click retries), dimmed = unit not installed. Two `gpu` units up at once shows a VRAM warning; nothing is stopped automatically.
- **polkit rule** (`security.polkit.extraConfig` next to ComfyUI in `default.nix`, appended to the power rules in `modules/desktop/user-experience.nix`): `org.freedesktop.systemd1.manage-units` returns YES only for `subject.user == username`, a listed unit (`action.lookup("unit")`) and verb `start`/`stop`/`restart` (`action.lookup("verb")`). Anything else (reload, enable, other units) falls through to the default (admin auth). There is no `subject.active`/`subject.local` check because quickshell runs under `user@.service`, outside the logind session. The rule also covers the CLI: `systemctl start llama-cpp` works without sudo.
- **Debug:** `quickshell-units states` prints the panel's JSON. A failed click shows systemctl's last line under the rows. `Access denied` means the rule did not match: check `/etc/polkit-1/rules.d/10-nixos.rules` and `journalctl -u polkit`.

## 🔐 Project Secrets (sops + gpg-agent)

Application secrets for projects under `~/code` never live in plaintext. `set dotenv-load` in justfiles is replaced by an encrypted **`.sops.env`** (sops dotenv store: variable names visible, values `ENC[...]`, safe to commit) that is decrypted into **one child process only** via `sops exec-env` — nothing is written to disk or exported into the shell, so neither `cat` nor `printenv` nor an AI agent's subprocess can see the values. Configured by `modules/home/packages/sops.nix` (`sopsEnv.*` in `hosts/wotan/home.nix`).

- **Recipient:** the GPG key (`sopsEnv.pgpFingerprint`, encryption subkey required). Decryption goes through gpg-agent — private key passphrase-encrypted at rest, cache TTLs in `modules/home/configs/base.nix`, pinentry-rofi on a cold cache. Add `sopsEnv.ageRecipients` for servers/CI.
- **Rules:** one shared `~/code/.sops.yaml` (walks up from cwd; a project's own file wins). The file **must** end in `.env` — sops infers the dotenv format from the extension and `exec-env` has no `--input-type`, so `.env.sops` does *not* work.
- **Migrate a project:** `cd proj && env2sops` (normalizes, encrypts, verifies round-trip, shreds `.env`, gitignores it). sops stores dotenv lines *literally* — unlike `dotenv-load` it keeps quotes and inline comments in the value, treats `export KEY` as the key, and rejects multi-line values — so `env2sops-normalize.py` rewrites to strict `KEY=value` first and lists (by key name only) what it changed. Values containing `$VAR` are flagged: dotenv-load expanded them, sops won't. Then in the justfile:
  ```just
  secrets := "sops exec-env .sops.env"      # replaces: set dotenv-load := true

  dev:
      {{secrets}} 'npm run dev'
  up:                                       # for --env-file consumers: decrypted into a FIFO, never on disk
      sops exec-file .sops.env 'podman compose --env-file {} up -d'
  ```
- **Edit:** `sops .sops.env` (opens `$EDITOR`, re-encrypts on save). **Add a var:** same. **Rotate recipients:** `sops updatekeys .sops.env`.
- **Never:** `direnv`'s `dotenv`, `source .env`, or `export`ing secrets — anything in the ambient environment is visible to every child process and no guardrail catches `python -c 'print(os.environ)'`.

## 📚 Additional Resources

- wotan README: `infra/hosts/wotan/README.md`
- Fleet guide: `infra/AGENTS.md`; repo-wide guide: `AGENTS.md` at the root
- Justfile commands: root `justfile` (wotan recipes are the `*-wotan` ones)
- Flake configuration: root `flake.nix`; `mkDesktop` in `infra/lib/mkConfigs.nix`
- Development shell: `nix develop` at the root (loaded by direnv)

---

**Remember:** This is a production NixOS system. Always test changes before switching, and prefer `test` over `switch` for experimentation.
