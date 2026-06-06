# NixOS Multi-Host Configuration

This is a multi-host NixOS configuration with shared modules and host-specific settings currenlty used in my nixos desktop.

## 📁 Directory Structure

```
/etc/nixos/
├── flake.nix                 # Main flake configuration
├── README.md                 # This file
├── AGENTS.md                 # AI coding agent guide
├── justfile                  # Just command runner recipes
├── lefthook.yml              # Git hooks configuration
├── modules/                  # Shared modules
│   ├── nixos/                # NixOS system modules
│   │   ├── basics.nix
│   │   ├── common-packages.nix
│   │   ├── flatpak.nix
│   │   └── desktop/          # Desktop environment modules
│   └── home-manager/         # Home-manager user modules
│       ├── common-packages.nix
│       ├── configs/          # Program configurations
│       └── packages/         # Package category modules
├── hosts/                    # Host-specific configurations
│   └── wotan/                # Main workstation
│       ├── default.nix       # Host-specific system config
│       ├── home.nix          # Host-specific user config
│       ├── hardware-configuration.nix
│       ├── disko-config.nix  # Disk partitioning
│       └── desktop-config.nix
├── secrets/                  # Agenix encrypted secrets
└── kickstart.nixvim/         # Neovim configuration
```

## 🚀 Usage

### System Configuration

```bash
# Rebuild NixOS configuration for wotan
sudo nixos-rebuild switch --flake .#wotan

# Test configuration without applying
sudo nixos-rebuild test --flake .#wotan

# Build configuration (dry run)
nix build .#nixosConfigurations.wotan.config.system.build.toplevel --dry-run
```

### Home-Manager Configuration

```bash
# Apply home-manager configuration for amadeus@wotan
home-manager switch --flake .#amadeus@wotan

# Build configuration (dry run)
nix build .#homeConfigurations.amadeus@wotan.activationPackage --dry-run
```

### Development

```bash
# Enter development shell
nix develop

# Check configuration
nix flake check

# Update dependencies
nix flake update
```

## ➕ Adding a New Host

1. Create host directory:

   ```bash
   mkdir -p hosts/newhost
   ```

2. Create host configuration:

   ```nix
   # hosts/newhost/default.nix
   { config, pkgs, inputs, lib, ... }:
   {
     imports = [
       ./hardware-configuration.nix
       ../../modules/nixos/common-packages.nix
     ];

     networking.hostName = "newhost";
     # Add host-specific configuration here
   }
   ```

3. Create home-manager configuration:

   ```nix
   # hosts/newhost/home.nix
   { config, pkgs, inputs, lib, ... }:
   {
     imports = [
       ../../modules/home-manager/common-packages.nix
       # Add host-specific home-manager modules here
     ];
   }
   ```

4. Update `flake.nix`:

   ```nix
   nixosConfigurations = {
     wotan = mkHost "wotan" system;
     newhost = mkHost "newhost" system;  # Add this line
   };

   homeConfigurations = {
     "amadeus@wotan" = mkHome "wotan" system;
     "amadeus@newhost" = mkHome "newhost" system;  # Add this line
   };
   ```

## 📦 Shared Modules

### NixOS Common Packages (`modules/nixos/common-packages.nix`)

- Essential system packages (vim, curl, git, etc.)
- Common programs (zsh, etc.)
- Common services (flatpak, pcscd, etc.)
- Nix settings and garbage collection
- User configuration
- Networking, locale, and time settings

### Home-Manager Common Packages (`modules/home-manager/common-packages.nix`)

- Development tools (fabric-ai, opencode, etc.)
- Kubernetes and cloud tools
- Database tools
- System utilities
- Desktop applications
- Shell configuration (zsh, aliases)
- Program configurations (git, lazygit, etc.)

## 🖥️ Host-Specific Configuration

Each host can override or extend the shared configuration:

### System-level overrides (in `hosts/{hostname}/default.nix`)

- Hardware configuration
- Host-specific packages
- Host-specific services
- Desktop environment settings

### User-level overrides (in `hosts/{hostname}/home.nix`)

- Host-specific user packages
- Host-specific program settings
- Custom configurations per host

## 🔧 Configuration Details

### Current Host: wotan

- **Desktop**: Hyprland (Wayland compositor)
- **Graphics**: NVIDIA (stable drivers, CUDA enabled)
- **Sound**: PipeWire with PulseAudio compatibility
- **Special Features**: Steam, Podman, Tailscale
- **Bar**: Quickshell
- **Terminal**: Kitty, Alacritty
- **Local LLM**: vLLM (OpenAI-compatible, CUDA, served on `127.0.0.1:10808`)

### Shared Features

- **Shell**: Zsh with Oh My Zsh
- **Editor**: Neovim with Kickstart NixVim configuration
- **Terminals**: Kitty, Alacritty, Ghostty
- **Version Control**: Git with signing
- **Package Management**: Flatpak + Nix
- **Privacy**: Tor browser and services

## 📝 Notes

- All configurations use the same user "amadeus" for consistency
- Unfree packages are enabled on all hosts
- Automatic garbage collection is configured weekly
- Development shell provides helpful commands and tools
- Git hooks ensure configuration quality
