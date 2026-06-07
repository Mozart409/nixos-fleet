#!/bin/sh

set -euo

clear

chara say -t round -r switching ...
echo ''

echo ''
echo 'Pushing to all remotes'
git push origin

echo ''
nh os switch .#nixosConfigurations.wotan
nh home switch . -c amadeus@wotan -b backup

echo ''
echo 'Cleaning up old generations and store...'
nh clean all

echo ''
echo 'Optimising store...'
nix store optimise

exit 0
