#!/usr/bin/env bash

set -euo pipefail

clear

chara say -t round -r switching ...
echo ''

echo 'Switching NixOS configuration...'
nh os switch .#nixosConfigurations.wotan

echo ''
echo 'Pushing to all remotes'
for remote in $(git remote); do
  echo "  -> pushing to $remote"
  if git push "$remote"; then
    echo "     ✓ $remote"
  else
    echo "     ✗ failed to push to $remote (continuing)" >&2
  fi
done
