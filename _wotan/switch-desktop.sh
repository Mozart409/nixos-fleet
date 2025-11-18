#!/usr/bin/env bash

set -e

DESKTOP_CONFIG="/etc/nixos/hosts/wotan/desktop-config.nix"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <kde|niri>"
    echo "Current desktop: $(grep 'desktop.environment' "$DESKTOP_CONFIG" | awk '{print $3}' | tr -d '"')"
    exit 1
fi

DESKTOP=$1

case $DESKTOP in
    kde|niri)
        ;;
    *)
        echo "Error: Desktop must be 'kde' or 'niri'"
        exit 1
        ;;
esac

echo "Switching to $DESKTOP desktop environment..."

# Update the desktop configuration
sed -i "s/desktop.environment = \".*\"/desktop.environment = \"$DESKTOP\"/" "$DESKTOP_CONFIG"

echo "Desktop configuration updated. Run './switch.sh' to apply changes."