#!/bin/sh

set -euo pipefail

sudo nixos-rebuild switch --flake .#wotan
home-manager switch --flake .#amadeus@wotan


exit 0
