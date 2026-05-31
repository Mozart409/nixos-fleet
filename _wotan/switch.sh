#!/bin/sh

set -euo

clear

chara say -t round -r switching ...
echo ''

echo ''
echo 'Pushing to all remotes'
git push origin

echo ''
nh os switch -b backup .#nixosConfigurations.wotan
nh home switch -b backup . -c amadeus@wotan

sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

exit 0
