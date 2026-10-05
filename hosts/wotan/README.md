# wotan

My desktop workstation: Hyprland on NVIDIA (CUDA), Quickshell bar, Podman,
local vLLM. Part of the `yggdrasil` monorepo; the flake is at the repo root
(`~/code/yggdrasil`), not in `/etc/nixos`.

wotan only ever deploys **itself**. It is not a `colmenaHive` node, has no
inbound SSH, and nothing in the fleet tooling reaches it.

## Layout

Paths are relative to the repo root.

```
infra/
├── hosts/wotan/
│   ├── default.nix              # system config; imports infra/modules/wotan
│   ├── home.nix                 # home-manager config for amadeus
│   ├── desktop-config.nix       # desktop.environment = "hyprland", file managers
│   ├── disko-config.nix, hardware-configuration.nix
│   ├── nebula.nix, nebula/      # nebula overlay certs
│   ├── spacebot/                # Spacebot agent identity files
│   ├── switch.sh                # the normal way to deploy (see below)
│   └── AGENTS.md                # desktop details for coding agents
├── modules/
│   ├── wotan/                   # wotan-only NixOS modules (default.nix aggregates them,
│   │                            #   plus ../desktop): basics, packages, vLLM, spacebot, …
│   ├── desktop/                 # Hyprland, file managers, user experience
│   └── home/                    # home-manager: configs/, packages/, services/
├── lib/mkConfigs.nix            # mkDesktop + the wotan-only nixpkgs config (CUDA, vLLM, glaze pin)
├── secrets/                     # agenix secrets, shared with the fleet (secrets.nix)
└── docs/wotan/                  # config.d2 diagram, easyeffects tuning, keymaps
```

The root `flake.nix` builds it as `nixosConfigurations.wotan = desktop.mkDesktop
"wotan" system "amadeus"`. CUDA, the vLLM insecure allow and the glaze overlay
live only in `mkDesktop`; the fleet's `mkHost` never sees them.

## Usage

From the repo root:

```bash
just switch-wotan        # infra/hosts/wotan/switch.sh: probe substituters, nh os switch, push to every remote
just switch-wotan -r     # nh os boot instead (NVIDIA driver bumps); reboot yourself
just build-wotan         # nh os build .#wotan, no activation
just build-home-wotan    # dry-run build of the home-manager activation package
just test-wotan          # nixos-rebuild test: active until reboot
just update              # nix flake update (moves wotan AND the fleet: one lock)
```

`programs.nh.flake` points at `~/code/yggdrasil`, so a bare `nh os switch`
works from anywhere.

One lock for everything: a flake update moves wotan and every server together.
Build wotan (`just build-wotan`) before rolling an update out to the fleet.

```sh
hyprctl eval 'hl.config({ input = { kb_layout = "de" } })'
```
