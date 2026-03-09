#!/bin/sh

set -euo

clear

chara say -t round -r cleaning up ...
echo ''

echo ''
echo 'Deleting old system generations (keeping last 5)...'
sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +5

echo ''
echo 'Deleting old home-manager generations (keeping last 5)...'
nix-env -p /home/amadeus/.local/state/nix/profiles/home-manager --delete-generations +5

echo ''
echo 'Deleting old user profile generations (keeping last 5)...'
nix-env --delete-generations +5

echo ''
echo 'Running garbage collection...'
nix-collect-garbage

echo ''
echo 'Optimise store...'
nix store optimise
echo ''
echo 'Disk usage after cleanup:'
df -h /

exit 0
