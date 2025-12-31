#!/bin/sh

set -euo

clear

chara say -t round -r switching ...
echo ''
echo ''
sudo nixos-rebuild switch --flake .#wotan
nix run nixpkgs#home-manager -- switch --flake .#amadeus@wotan

exit 0
