#!/bin/sh

set -euo

clear

sudo nixos-rebuild switch --flake .#wotan
home-manager switch --flake .#amadeus@wotan

exit 0
