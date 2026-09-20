# AGENTS.md - NixOS Configuration Guide for AI Coding Agents

This guide provides essential information for agentic coding agents operating in this NixOS configuration repository.

## 🏗️ Repository Overview

This is a **multi-host NixOS configuration** using flakes and home-manager. The primary host is `wotan` (main workstation).

**Architecture:**
- `/etc/nixos/` - Root configuration directory (this is the working directory)
- `flake.nix` - Central flake configuration with all inputs/outputs
- `hosts/{hostname}/` - Per-host system and home-manager configurations
- `modules/nixos/` - Shared NixOS system modules
- `modules/home-manager/` - Shared home-manager user modules
- `lib/mkConfigs.nix` - `mkHost` helper and shared nixpkgs config
- `secrets/` + `secrets.nix` - agenix-encrypted secrets

**Neovim:** The nixvim configuration lives in its own repo, consumed as the flake input `mozart409-nixvim` (`github:Mozart409/mozart409-nixvim`). Neovim changes happen there, then `nix flake update mozart409-nixvim` here.

**Hosts:**
- `wotan` - Main desktop workstation (Hyprland, NVIDIA, Podman)

**User:** All configurations use the user `amadeus`

## ⚡ Build/Test/Lint Commands

### Building and Switching Configurations

```bash
# Using nh (recommended - prettier output, diffs, faster)
# programs.nh.flake is preset to /etc/nixos, so no flake argument is needed.
nh os switch                  # Apply NixOS system + home-manager changes
nh os test                    # Test without persistence

# Traditional commands (fallback)
sudo nixos-rebuild switch --flake .#wotan    # Apply system changes
sudo nixos-rebuild test --flake .#wotan      # Test without persistence

# Using just (interactive menu)
just                          # Show interactive menu
just switch wotan             # Switch NixOS config (home-manager is integrated)
just test wotan               # Test NixOS config
# (switch-all/test-all are aliases for switch/test — no separate home-manager step)

# Build configurations (dry-run to check)
just build wotan              # = nix build .#nixosConfigurations.wotan.config.system.build.toplevel --dry-run
just build-home               # = nix build ...home-manager.users.amadeus.home.activationPackage --dry-run
```

**Note:** `nh` is enabled via `programs.nh` in `modules/nixos/basics.nix` with the default flake set to `/etc/nixos`.

### Validation and Linting

```bash
# Format all Nix files with Alejandra (REQUIRED before commits)
alejandra .                  # Format all files
alejandra {staged_files}     # Format staged files only

# Validate flake configuration
nix flake check             # Check all outputs

# Update dependencies (run as YOUR USER, never sudo — sudo breaks flake.lock ownership)
nix flake update            # Update all inputs
nix flake update nixpkgs    # Update specific input
just update                 # Same as nix flake update --accept-flake-config
just update-input nixpkgs   # Update a single input

# Development shell
nix develop                 # Enter dev shell (git, alejandra, lefthook, opencode, cocogitto, claude-code, agenix)

# MCP Servers (if available)
# Use context7 or grepmcp for enhanced code search and documentation queries
```

### Git Hooks

**Pre-commit hook** (configured via lefthook.yml):
- Automatically runs `alejandra` on staged `.nix` files
- Stages fixed files automatically
- Install: `lefthook install` (available in dev shell)

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
- **Modules:** Descriptive, grouped by function (e.g., `modules/nixos/desktop/`)
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

**System-level** (`modules/nixos/common-packages.nix`):
```nix
environment.systemPackages = with pkgs; [
  newpackage
];
```

**User-level** (host's `home.nix` or `modules/home-manager/`):
```nix
home.packages = with pkgs; [
  newpackage
];
```

### Adding New Hosts

1. Create `hosts/{hostname}/` directory
2. Add `default.nix` (system config) and `home.nix` (user config)
3. Generate hardware config: `nixos-generate-config --show-hardware-config`
4. Update `flake.nix` to include new host in `nixosConfigurations`
5. Use helper function: `mkHost "hostname" system "username"` (defined in `lib/mkConfigs.nix`).
   `username` is threaded through `specialArgs`/`extraSpecialArgs`, so shared
   modules take it as a function arg (`{username, ...}`) instead of hardcoding `amadeus`.
6. Import shared modules via the aggregator: `../../modules/nixos` (imports every
   shared module; each optional one is gated by its own `enable` flag — e.g.
   `hardware.razer.enable`, `hardware.moza.enable`, `services.vllm.enable`,
   `programs.claudeCodeMcp.enable`, `desktop.enable`).

### Module Organization

- **Shared config:** Goes in `modules/{nixos,home-manager}/`
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

1. **Format:** `alejandra .`
2. **Validate:** `nix flake check`
3. **Build test:** `just build wotan`
4. **Build home test:** `just build-home`
5. **Test config:** `sudo nixos-rebuild test --flake .#wotan` (if changing system)
6. **Commit:** Changes with descriptive message
7. **Switch:** `just switch wotan` (or `nh os switch`) to persist

## 🚨 Common Pitfalls

1. **Forgetting to format:** Always run `alejandra` before committing
2. **Absolute paths:** Use relative paths from current file location
3. **Unfree packages:** Already configured globally, no need to add per-package
4. **Home-manager vs NixOS:** System services in NixOS modules, user config in home-manager. Home-manager is integrated via `home-manager.nixosModules.home-manager` so a single `nixos-rebuild switch` activates both.
5. **Rebuilds require sudo, updates do NOT:** System rebuilds need `sudo`, but `nix flake update` must run as the regular user — running it with sudo makes `flake.lock` root-owned and breaks later user-level updates.
6. **Secrets:** Use agenix for sensitive data (see `age.secrets` in wotan config)
7. **Systemd sandboxing:** Services with `DynamicUser=true` and `ProtectHome=true` cannot access `/home/`. Use state directories (e.g., `/var/lib/<service>/`) instead.
8. **NVIDIA driver version bumps break `nh os switch`:** the NVIDIA container CDI generator runs against the new driver while the old kernel module is still loaded (NVML mismatch). After a flake update that bumps the driver, use `sudo nixos-rebuild boot --flake .#wotan` and reboot instead of switching live.
9. **Bluetooth audio dropouts / stalled connections (Intel AX210):** the AX210 controller (USB `8087:0032`) defaults to a 2s USB autosuspend that powers the radio down mid-stream, causing kernel `hci0: link tx timeout` -> `killing stalled connection`, `spa.bluez5: Acquire ... org.bluez.Error.Failed`, and "missing completion reports ... firmware bug?" in WirePlumber — A2DP sinks flicker in and out and no audio plays. Enough killed connections wedge the controller until it sees zero devices even after a USB rebind (needs a reboot to recover). Fixed declaratively by `boot.extraModprobeConfig = "options btusb enable_autosuspend=0"` in `modules/nixos/desktop/default.nix`; the modprobe option only applies on the next `btusb` load, so rebuild + reboot. Diagnose with `journalctl -k -b | grep hci0` and `journalctl --user -u wireplumber | grep bluez`.
10. **`hl.dsp.dpms` silently toggles on a wrong field name (Hyprland 0.56 Lua):** the Lua dpms dispatcher parses its table with `tableToggleAction(field = "action")`, and an unrecognized field — e.g. `{ state = "on" }`, which looks plausible — SILENTLY falls back to `TOGGLE` instead of setting an explicit state. That desyncs the compositor's dpms state from the panels: `hyprctl monitors` reports `dpmsStatus=true` while both monitors sit in power save with no video signal, and key presses (which still reach the session) stop waking them. Always use `hl.dsp.dpms({ action = "on" })` / `{ action = "off" }` (also accepts `enable`/`disable`) in hypridle.conf etc. Field names verified against `src/config/lua/bindings/LuaBindingsInternal.{hpp,cpp}` at the pinned commit — check there, not the wiki, when adding new Lua dispatchers.
11. **MCP secrets in opencode.json must be in the SERVER's environment, not the login shell:** with `services.opencode-serve` enabled, every interactive `opencode` is wrapped to `opencode attach $OPENCODE_SERVER_URL`, so `{env:VAR}` placeholders in MCP headers (e.g. axon-gateway's `Authorization: Bearer {env:AXON_GATEWAY_TOKEN}`) are expanded by the long-running systemd service — which has a minimal environment and never sees `home.sessionVariablesExtra`. Symptoms: `server unavailable / status=failed` in `~/.local/share/opencode/log` and HTTP 401 from the gateway while curl from a shell works fine. Fix: pass the agenix secret (must be in `KEY=value` format) via `services.opencode-serve.environmentFiles` and rebuild; the unit change restarts the service. Note the context7 secret is a raw token (no `KEY=` prefix) so it cannot be used as an EnvironmentFile until re-encrypted in `KEY=value` form — it currently only works because context7 allows unauthenticated (rate-limited) access.

12. **opencode reads `.env` via bash, not the read tool:** opencode's `permission.read` rules (default `*.env: ask` in 1.18) only gate the `read` tool; the bash tool matches `permission.bash` globs against the parsed command and never applies read rules to file arguments, so `cat .env`, `sed -n p .env`, `printenv`, `agenix -d …` are plain `allow`. Guardrails live in `modules/home-manager/packages/opencode.nix` (`opencode.guardrails.enable`, on by default, independent of `opencode.enable`): `~/.config/opencode/plugins/secret-guard.js` hard-blocks secret paths / reveal commands in `tool.execute.before` and redacts token-shaped values in `tool.execute.after`, plus baseline deny rules in `~/.config/opencode/config.json` (merged first, so `opencode.json(c)` / project `.opencode/` still override). Test the plugin logic with node before rebuilding; verify live with `opencode run "print .env"` in a dir with a dummy `.env`.

## 🤖 vLLM Inference Server

The vLLM service provides an OpenAI-compatible inference endpoint with CUDA acceleration. It runs as a **Podman OCI container** (`vllm/vllm-openai` image, see `services.vllm.image` for the pinned version) managed by `virtualisation.oci-containers`, so the systemd unit is **`podman-vllm.service`**. `autoStart = false` — it does not start at boot; launch it manually. Models are pulled from HuggingFace on first launch, not stored as local files.

**Model cache location:** `/var/lib/vllm/huggingface/` on the host, mounted into the container (HF transformers format, NOT GGUF)

**Currently configured model** (see `hosts/wotan/default.nix`):
- `Qwen/Qwen3-30B-A3B-GPTQ-Int4` — official Qwen MoE (30B total, ~3B active per token), 4-bit GPTQ, 32K context configured (40K model max). Weights (15.6 GB) exceed the RTX 3060's 12 GB VRAM, so `cpuOffloadGb = 10` offloads part of the weights to system RAM (llmfit: "Good" fit, ~19 tok/s est.).

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
The HF token is stored as an agenix secret at `secrets/hf-token.age` and passed to the container as an environment file. Format inside the file:
```
HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```
Edit with: `nix run github:ryantm/agenix -- -e secrets/hf-token.age`

**Configuration:** `modules/nixos/vllm.nix` (module + options, including `cpuOffloadGb`) and `hosts/wotan/default.nix` (host-specific model + flags)

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

- Main README: `/etc/nixos/README.md`
- Justfile commands: `/etc/nixos/justfile`
- Flake configuration: `/etc/nixos/flake.nix`
- Development shell: `nix develop` (includes git, alejandra, lefthook, opencode, cocogitto, claude-code, agenix)

---

**Remember:** This is a production NixOS system. Always test changes before switching, and prefer `test` over `switch` for experimentation.
