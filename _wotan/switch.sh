#!/bin/sh

clear

echo ""
chara say -t round -r Switching to new system

echo ""
echo ""

nh home switch . || exit 1

nh os switch . || exit 1
# sudo nixos-rebuild switch

exit 0
