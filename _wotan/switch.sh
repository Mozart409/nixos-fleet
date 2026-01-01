#!/bin/sh

set -euo

clear

chara say -t round -r switching ...
echo ''
echo ''
# Old if nh not available
# sudo nixos-rebuild switch --flake .#wotan
# nix run nixpkgs#home-manager -- switch --flake .#amadeus@wotan

nh os switch .#wotan
nh home switch .#amadeus@wotan

sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

exit 0
