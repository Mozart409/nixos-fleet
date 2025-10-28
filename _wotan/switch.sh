#!/bin/bash

set -euo pipefail

clear

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 NixOS Configuration Switch for wotan${NC}"
echo -e "${YELLOW}=====================================${NC}"
echo ""

# Show current generation
echo -e "${BLUE}Current system generation:${NC}"
nixos-rebuild list-generations | grep "current" | head -1
echo ""

# Show current home-manager generation
echo -e "${BLUE}Current home-manager generation:${NC}"
home-manager generations | grep "current" | head -1
echo ""

echo -e "${YELLOW}🚀 Switching to new configuration...${NC}"
echo ""

# Update flake lock file if needed
echo -e "${BLUE}📦 Updating flake inputs...${NC}"
nix flake update --accept-flake-config

# Check configuration before building
echo -e "${BLUE}🔍 Checking configuration...${NC}"
if nix flake check --accept-flake-config; then
    echo -e "${GREEN}✅ Configuration check passed${NC}"
else
    echo -e "${RED}❌ Configuration check failed${NC}"
    exit 1
fi

echo ""

# Switch home-manager configuration
echo -e "${BLUE}🏠 Switching home-manager configuration...${NC}"
if nh home switch . --flake .#amadeus@wotan; then
    echo -e "${GREEN}✅ Home-manager switched successfully${NC}"
else
    echo -e "${RED}❌ Home-manager switch failed${NC}"
    exit 1
fi

echo ""

# Switch NixOS configuration
echo -e "${BLUE}🖥️  Switching NixOS configuration...${NC}"
if sudo nh os switch . --flake .#wotan; then
    echo -e "${GREEN}✅ NixOS switched successfully${NC}"
else
    echo -e "${RED}❌ NixOS switch failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Configuration switch completed successfully!${NC}"

# Show new generation
echo ""
echo -e "${BLUE}New system generation:${NC}"
nixos-rebuild list-generations | grep "current" | head -1

echo ""
echo -e "${BLUE}New home-manager generation:${NC}"
home-manager generations | grep "current" | head -1

echo ""
echo -e "${YELLOW}💡 Tip: Use 'nixos-rebuild rollback' or 'home-manager rollback' if needed${NC}"

# Optional: Show fun animation
if command -v charasay >/dev/null 2>&1; then
    echo ""
    charasay -t round -r "All done!"
fi

exit 0
