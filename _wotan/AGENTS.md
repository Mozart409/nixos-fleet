# AGENTS.md - NixOS Configuration Guide for AI Coding Agents

This guide provides essential information for agentic coding agents operating in this NixOS configuration repository.

## 🏗️ Repository Overview

This is a **multi-host NixOS configuration** using flakes, home-manager, and nixvim. The primary host is `wotan` (main workstation).

**Architecture:**
- `/etc/nixos/` - Root configuration directory (this is the working directory)
- `flake.nix` - Central flake configuration with all inputs/outputs
- `hosts/{hostname}/` - Per-host system and home-manager configurations
- `modules/nixos/` - Shared NixOS system modules
- `modules/home-manager/` - Shared home-manager user modules
- `kickstart.nixvim/` - Neovim configuration using nixvim

**Hosts:**
- `wotan` - Main desktop workstation (Hyprland, NVIDIA, Podman)

**User:** All configurations use the user `amadeus`

## ⚡ Build/Test/Lint Commands

### Building and Switching Configurations

```bash
# Using nh (recommended - prettier output, diffs, faster)
nh os switch .#nixosConfigurations.wotan     # Apply NixOS system changes
nh os test .#nixosConfigurations.wotan       # Test without persistence
nh home switch . -c amadeus@wotan            # Apply home-manager changes

# Traditional commands (fallback)
sudo nixos-rebuild switch --flake .#wotan    # Apply system changes
sudo nixos-rebuild test --flake .#wotan      # Test without persistence
home-manager switch --flake .#amadeus@wotan  # Apply home-manager changes

# Using just (interactive menu)
just                          # Show interactive menu
just switch wotan            # Switch NixOS config
just switch-home             # Switch home-manager (default: amadeus@wotan)
just switch-all wotan        # Switch both system and home-manager
just test wotan              # Test NixOS config
just test-all wotan          # Test both configs

# Build configurations (dry-run to check)
nix build .#nixosConfigurations.wotan.config.system.build.toplevel --dry-run
nix build .#homeConfigurations."amadeus@wotan".activationPackage --dry-run
```

**Note:** `nh` is enabled via `programs.nh` in `modules/nixos/basics.nix` with the default flake set to `/etc/nixos`.

### Validation and Linting

```bash
# Format all Nix files with Alejandra (REQUIRED before commits)
alejandra .                  # Format all files
alejandra {staged_files}     # Format staged files only

# Validate flake configuration
nix flake check             # Check all outputs
nix flake check .#nixosConfigurations.wotan
nix flake check .#homeConfigurations."amadeus@wotan"

# Update dependencies
nix flake update            # Update all inputs
nix flake update nixpkgs    # Update specific input
just update                 # Same as nix flake update --accept-flake-config

# Development shell
nix develop                 # Enter dev shell with git, alejandra, lefthook

# MCP Servers (if available)
# Use context7 or grepmcp for enhanced code search and documentation queries
```

### Git Hooks

**Pre-commit hook** (configured via lefthook.yml):
- Automatically runs `alejandra` on staged `.nix` files
- Stages fixed files automatically
- Install: `lefthook install` (available in dev shell)

**NEVER** commit unformatted Nix code. Always run `alejandra` first.

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

- **Indentation:** 2 spaces (enforced by Alejandra)
- **Line length:** Soft limit ~100 chars (Alejandra handles wrapping)
- **Lists:** One item per line for readability
- **Attribute sets:** Use multi-line format when >2 attributes
- **Let-in:** Use for complex derivations or repeated values
- **String interpolation:** `"${variable}"` for Nix, `''${literal}''` in multi-line

```nix
# GOOD
environment.systemPackages = with pkgs; [
  vim
  git
  curl
];

# AVOID (single line for long lists)
environment.systemPackages = with pkgs; [ vim git curl wget htop ];
```

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
4. Update `flake.nix` to include new host in `nixosConfigurations` and `homeConfigurations`
5. Use helper functions: `mkHost "hostname" system` and `mkHome "hostname" system`

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

# Home-manager (persists)
home-manager switch --flake .#amadeus@wotan
```

### Full Validation Pipeline

Before committing changes:

1. **Format:** `alejandra .`
2. **Validate:** `nix flake check`
3. **Build test:** `nix build .#nixosConfigurations.wotan.config.system.build.toplevel --dry-run`
4. **Test config:** `sudo nixos-rebuild test --flake .#wotan` (if changing system)
5. **Commit:** Changes with descriptive message
6. **Switch:** `just switch-all wotan` to persist

## 🚨 Common Pitfalls

1. **Forgetting to format:** Always run `alejandra` before committing
2. **Absolute paths:** Use relative paths from current file location
3. **Unfree packages:** Already configured globally, no need to add per-package
4. **Home-manager vs NixOS:** System services in NixOS modules, user config in home-manager
5. **Rebuilds require sudo:** System rebuilds need `sudo`, home-manager doesn't
6. **Secrets:** Use agenix for sensitive data (see `age.secrets` in wotan config)
7. **Systemd sandboxing:** Services with `DynamicUser=true` and `ProtectHome=true` cannot access `/home/`. Use state directories (e.g., `/var/lib/<service>/`) instead.

## 🤖 LLaMA.cpp Server

The llama-cpp service runs with strict systemd sandboxing (`ProtectHome=true`), so models must be stored in the service's state directory.

**Models location:** `/var/lib/llama-cpp/models/`

**Currently installed models:**
- `LFM2-8B-A1B-Q6_K.gguf` - Fast general chat (~188 tok/s, 4.3GB VRAM)
- `Qwen3-30B-A3B-Instruct-2507-Q4_K_M.gguf` - Tool calling/MCP support (~95 tok/s, MoE)

**Adding models:**
```bash
# Using llmfit (recommended)
llmfit download unsloth/LFM2-8B-A1B-GGUF --quant Q6_K
sudo mv ~/.cache/llmfit/models/*.gguf /var/lib/llama-cpp/models/

# Manual download
sudo mv model.gguf /var/lib/llama-cpp/models/
```

**API endpoints:**
- List models: `http://127.0.0.1:10808/v1/models`
- Chat completions: `http://127.0.0.1:10808/v1/chat/completions`

**Service management:**
```bash
systemctl status llama-cpp          # Check status
journalctl -u llama-cpp -f          # Follow logs
sudo systemctl restart llama-cpp    # Restart service
```

**Configuration:** `modules/nixos/llama-cpp.nix` (shared) and `hosts/wotan/default.nix` (host-specific)

### MoE Models and VRAM

The RTX 3060 has 12GB VRAM. Large Mixture-of-Experts (MoE) models like Qwen3-30B-A3B require the `--cpu-moe` flag to offload inactive experts to system RAM.

**How MoE offloading works:**
- Active experts (~3-4GB) stay in VRAM for fast inference
- Inactive experts (~26GB for Qwen3-30B) offload to system RAM
- Requires sufficient system RAM (wotan has 64GB)

**Without `--cpu-moe`:** llama-cpp tries to load the entire model into VRAM and fails with `cudaMalloc failed: out of memory`.

**KV cache and context size:** Even with `--cpu-moe`, the KV cache is stored in VRAM and scales with context length. Large contexts (128K+) can exhaust VRAM even when the model weights fit. Use per-model presets (`/etc/llama-cpp-presets.ini`) to set appropriate context sizes:
- Dense models (LFM2-8B): 64K context is fine
- MoE models (Qwen3-30B-A3B): Limit to 16K-32K context

**Note:** Open WebUI with many MCP tools can easily exceed 50K+ tokens just for tool schemas. If you get "request exceeds context size" errors, reduce enabled tools or use LFM2 for tool-heavy tasks.

**Model selection for tool calling (Open WebUI / MCP):**
- **Qwen3 models** have native OpenAI-style tool/function calling support
- **LFM2** is faster but lacks dedicated tool calling training
- Use `llmfit fit --json` to find models that fit your hardware

### Hardware fitting with llmfit

```bash
llmfit system                    # Show hardware specs
llmfit fit --json --limit 20     # Find fitting models
llmfit recommend --json          # Top recommendations
llmfit info "model/name"         # Detailed model info
llmfit hf-search "query"         # Search HuggingFace for GGUFs
```

## 📚 Additional Resources

- Main README: `/etc/nixos/README.md`
- Justfile commands: `/etc/nixos/justfile`
- Flake configuration: `/etc/nixos/flake.nix`
- Development shell: `nix develop` (includes git, alejandra, lefthook, opencode)

---

**Remember:** This is a production NixOS system. Always test changes before switching, and prefer `test` over `switch` for experimentation.
