#!/bin/sh

set -euo

clear

chara say -t round -r switching ...
echo ''

echo ''
echo 'Pushing to all remotes'
git push origin

echo ''
sudo nixos-rebuild switch --flake .#wotan
nix run nixpkgs#home-manager -- switch --flake .#amadeus@wotan -b backup

sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

exit 0
