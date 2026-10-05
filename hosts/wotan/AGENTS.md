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
- `lib/mkConfigs.nix` - `mkDesktop` helper and the wotan-only nixpkgs config (CUDA, vLLM insecure allow, glaze pin)
- `secrets/` + `secrets/secrets.nix` - agenix secrets, **shared with the fleet**; wotan's rules are `[amadeus hostWotan]`

**wotan deploys only itself.** It is not a `colmenaHive` node, has no inbound SSH (the firewall has no open TCP ports), and must never import the fleet's `modules/common.nix`, which turns sshd on. Nothing in the fleet tooling reaches it.

**Neovim:** The nixvim configuration lives in its own repo, consumed as the flake input `mozart409-nixvim` (`github:Mozart409/mozart409-nixvim`). Neovim changes happen there, then `nix flake update mozart409-nixvim` here.

**User:** `amadeus`

## ⚡ Build/Test/Lint Commands

### Building and Switching Configurations

```bash
# Preferred: the user's normal workflow (infra/hosts/wotan/switch.sh)
just switch-wotan             # nh os switch, skipping unreachable substituters, then git push to ALL remotes
just switch-wotan -r          # nh os boot instead (NVIDIA driver bumps, pitfall #8); reboot manually

# Other wotan recipes in the root justfile
just build-wotan              # = nh os build .#wotan (real build, not a dry run)
just build-home-wotan         # = nix build ...home-manager.users.amadeus.home.activationPackage --dry-run
just test-wotan               # = sudo nixos-rebuild test --flake .#wotan

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
   `hardware.razer.enable`, `hardware.moza.enable`, `services.vllm.enable`,
   `programs.claudeCodeMcp.enable`, `desktop.enable`).
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
7. **Switch:** `just switch-wotan` to persist — the user runs it; note it also pushes to every git remote, including the public GitHub mirror

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
11. **MCP secrets in opencode.json must be in the SERVER's environment, not the login shell:** with `services.opencode-serve` enabled, every interactive `opencode` is wrapped to `opencode attach $OPENCODE_SERVER_URL`, so `{env:VAR}` placeholders in MCP headers (e.g. axon-gateway's `Authorization: Bearer {env:AXON_GATEWAY_TOKEN}`) are expanded by the long-running systemd service — which has a minimal environment and never sees `home.sessionVariablesExtra`. Symptoms: `server unavailable / status=failed` in `~/.local/share/opencode/log` and HTTP 401 from the gateway while curl from a shell works fine. Fix: pass the agenix secret (must be in `KEY=value` format) via `services.opencode-serve.environmentFiles` and rebuild; the unit change restarts the service. Note the context7 secret is a raw token (no `KEY=` prefix) so it cannot be used as an EnvironmentFile until re-encrypted in `KEY=value` form — it currently only works because context7 allows unauthenticated (rate-limited) access.

12. **opencode reads `.env` via bash, not the read tool:** opencode's `permission.read` rules (default `*.env: ask` in 1.18) only gate the `read` tool; the bash tool matches `permission.bash` globs against the parsed command and never applies read rules to file arguments, so `cat .env`, `sed -n p .env`, `printenv`, `agenix -d …` are plain `allow`. Guardrails live in `modules/home/packages/opencode.nix` (`opencode.guardrails.enable`, on by default, independent of `opencode.enable`): `~/.config/opencode/plugins/secret-guard.js` hard-blocks secret paths / reveal commands in `tool.execute.before` and redacts token-shaped values in `tool.execute.after`, plus baseline deny rules in `~/.config/opencode/config.json` (merged first, so `opencode.json(c)` / project `.opencode/` still override). Test the plugin logic with node before rebuilding; verify live with `opencode run "print .env"` in a dir with a dummy `.env`.

13. **A stale avahi PID file fails `nixos-rebuild switch` (exit 4) with nothing obviously related in the output:** `avahi-daemon.service` has no `RuntimeDirectory=`, so `/run/avahi-daemon/pid` survives a daemon that dies without cleaning up, and avahi cannot clear it itself -- libdaemon's `daemon_pid_file_remove()` only unlinks a PID file containing its *own* pid (a guard against killing another instance). Every later start then logs `Process <pid> died ... trying to remove PID file`, `open(/run/avahi-daemon//pid): File exists`, `Failed to create PID file`, and exits 255 -- which surfaces only as `warning: the following units failed: avahi-daemon.service` plus `Activating configuration (exit status ExitStatus(Exited(4)))`. Fixed declaratively by the `ExecStartPre=-rm -f /run/avahi-daemon/pid` on `systemd.services.avahi-daemon` in `modules/desktop/default.nix` (`RuntimeDirectory=` would be tidier but systemd would wipe the directory on stop, taking `/run/avahi-daemon/socket` -- owned by the `avahi-daemon.socket` unit this one `Requires=` -- with it). Two traps while recovering by hand: repeated failures latch the unit into `start-limit-hit`, where `systemctl start` is **refused without executing anything** (no fork, no journal line -- if a start produces no new log entry, check for the latch before assuming the daemon died), so `systemctl reset-failed avahi-daemon.service avahi-daemon.socket` first; and `is-active` polled immediately after `start` can read `inactive` on this `Type=dbus` unit because start returns before the bus name settles. Diagnose with `journalctl -u avahi-daemon -o short-precise` and `ls -la /run/avahi-daemon/`. Note avahi is load-bearing here only for the CUPS printer's `.local` URI (`ipp://EPSONEB3A2A.local:631/ipp/print`), which mDNS alone can resolve.

14. **Removing a Hyprland plugin needs a relogin — never `hyprctl plugin unload` it live:** plugins are loaded only at login, so dropping one from `modules/home/packages/hyprland-configs.nix` (rendered to `~/.config/hypr/plugins.lua`) and switching leaves the old `.so` running. Unloading it live is worse: on 2026-09-26 `hyprctl plugin unload` removed hyprfocus from `hyprctl plugin list` and deleted its config values, but `libhyprfocus.so` stayed mapped with its focus-change listener still hooked. 35 minutes later a layer surface closing (Quickshell launcher) triggered `refocusLastWindow`, and the listener read its deleted `CStringValue`, which made `operator new` throw. Hyprland SIGABRTed, which took down xdg-desktop-portal-hyprland, hypridle, hyprsunset and awww-daemon too, and the machine needed a reboot. After removing a plugin, log out and back in. Diagnose Hyprland crashes with `coredumpctl list` / `coredumpctl info <pid>` and `~/.cache/hyprland/hyprlandCrashReport<pid>.txt`. A plugin frame in the main-thread stack names the culprit, even one missing from the report's plugin list.

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

## 🤖 vLLM Inference Server

The vLLM service provides an OpenAI-compatible inference endpoint with CUDA acceleration. It runs as a **Podman OCI container** (`vllm/vllm-openai` image, see `services.vllm.image` for the pinned version) managed by `virtualisation.oci-containers`, so the systemd unit is **`podman-vllm.service`**. `autoStart = false` — it does not start at boot; launch it manually. Models are pulled from HuggingFace on first launch, not stored as local files.

**Model cache location:** `/var/lib/vllm/huggingface/` on the host, mounted into the container (HF transformers format, NOT GGUF)

**Currently configured model** (see `hosts/wotan/default.nix`):
- `Qwen/Qwen3.5-35B-A3B-GPTQ-Int4` — official Qwen MoE (36B total, ~3B active), hybrid Gated-DeltaNet attention, tool use (`qwen3_coder` parser), thinking off by default, 64K context configured (262K model max). Text weights are 20.3 GiB (measured from safetensors headers; llmfit's 18 GB is low), so `cpuOffloadGb = 15` offloads part of them to system RAM. Vision encoder skipped with `--language-model-only`.

**Spacebot** (`modules/wotan/spacebot.nix`: Podman container `ghcr.io/spacedriveapp/spacebot`, unit **`podman-spacebot.service`**, `/var/lib/spacebot` mounted at `/data`, host network; upstream's Nix flake is unmaintained/broken, don't switch back to it) is the vLLM client: `services.spacebot.localVllm = true` routes every Spacebot process to `vllm/<model>`, sets `context_window = maxModelLen`, and makes `podman-spacebot.service` pull in `podman-vllm.service`. `services.spacebot.settings` is deep-merged into `/var/lib/spacebot/config.toml` on every start (`preStart`) — Nix wins for its keys, web-UI edits (messaging, bindings) survive, but keys deleted from Nix stay in the file. `autoStart = false` on wotan: `sudo systemctl start podman-spacebot` (UI at `http://127.0.0.1:19898`).

**Switching models:**
Edit `services.vllm.model` in `hosts/wotan/default.nix` and rebuild. Alternative candidates are listed in the comment block above the `services.vllm` declaration — re-verify with `llmfit --memory 12G fit` first. Prefer **trusted repos** (`Qwen/`, `RedHatAI/`) over community quants. Dense models that fit fully in VRAM should drop `cpuOffloadGb`.

**API endpoints (OpenAI-compatible):**
- List models: `http://127.0.0.1:10808/v1/models`
- Chat completions: `http://127.0.0.1:10808/v1/chat/completions`
- Completions: `http://127.0.0.1:10808/v1/completions`

**Service management:**
```bash
sudo systemctl start podman-vllm    # Start (not auto-started at boot)
systemctl status podman-vllm        # Check status
journalctl -u podman-vllm -f        # Follow logs (watch model load on first start)
sudo systemctl restart podman-vllm  # Restart service
```

**HuggingFace token (for gated models):**
The HF token is stored as an agenix secret at `infra/secrets/hf-token.age` and passed to the container as an environment file. Format inside the file:
```
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```
Edit with: `nix run github:ryantm/agenix -- -e infra/secrets/hf-token.age`

**Pre-download a model without loading it onto the GPU** (authenticated with the same token; the token is sourced inside the root shell, so it stays out of shell history and process args). The container mounts the cache at `/root/.cache/huggingface`, so files in `hub/` are picked up without a re-download:
```bash
sudo sh -c 'set -a; . /run/agenix/hf-token; exec nix run nixpkgs#python3Packages.huggingface-hub -- download Qwen/Qwen3.5-35B-A3B-GPTQ-Int4 --cache-dir /var/lib/vllm/huggingface/hub'
```

**Configuration:** `modules/wotan/vllm.nix` (module + options, including `cpuOffloadGb`) and `hosts/wotan/default.nix` (host-specific model + flags)

### Hardware fitting with llmfit

`llmfit` recommends GGUF/llama.cpp models by default — filter to vLLM-compatible HF format with `runtime=vLLM`:

```bash
llmfit system                                            # Show hardware specs
llmfit --memory 12G fit                                  # Find fitting models (table)
llmfit --memory 12G --max-context 262144 --json fit      # JSON output for scripting
llmfit info "Qwen/Qwen3.5-35B-A3B-GPTQ-Int4"             # Detailed model info
llmfit search "qwen"                                     # Search by name
```

Filter JSON output to vLLM-compatible candidates:
```bash
llmfit --memory 12G --json fit \
  | jq '.models[] | select(.runtime=="vLLM" and (.fit_level=="Perfect" or .fit_level=="Good"))'
```

## 📚 Additional Resources

- wotan README: `infra/hosts/wotan/README.md`
- Fleet guide: `infra/AGENTS.md`; repo-wide guide: `AGENTS.md` at the root
- Justfile commands: root `justfile` (wotan recipes are the `*-wotan` ones)
- Flake configuration: root `flake.nix`; `mkDesktop` in `infra/lib/mkConfigs.nix`
- Development shell: `nix develop` at the root (loaded by direnv)

---

**Remember:** This is a production NixOS system. Always test changes before switching, and prefer `test` over `switch` for experimentation.
