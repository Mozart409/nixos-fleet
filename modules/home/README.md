# Home Manager Package Categories

This directory contains modular Home Manager package configurations that can be imported selectively by hosts.

## Structure

- `configs/` - Core configuration modules (base, shell, programs)
- `packages/` - Package categories:
  - `development.nix` - Development tools and languages
  - `kubernetes.nix` - K8s and cloud tools
  - `database.nix` - Database tools
  - `system.nix` - System utilities
  - `desktop.nix` - Desktop applications
  - `fun.nix` - Customization and fun tools

## Usage

In your host's `home.nix`, import the base configuration and add desired package categories:

```nix
{
  imports = [
    ../../modules/home-manager/common-packages.nix
    ../../modules/home-manager/packages/development.nix
    ../../modules/home-manager/packages/kubernetes.nix
    ../../modules/home-manager/packages/desktop.nix
  ];
}
```

Or selectively import individual configs:

```nix
{
  imports = [
    ../../modules/home-manager/configs/base.nix
    ../../modules/home-manager/configs/shell.nix
    ../../modules/home-manager/packages/development.nix
  ];
}
```

