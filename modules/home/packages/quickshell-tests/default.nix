# The power menu's commands (quickshell/PowerActions.js) checked against the
# Hyprland and systemd from the root lock -- the ones wotan runs. Opt-in, not
# under `checks`:
#   nix build .#legacyPackages.x86_64-linux.quickshell.checks.power-menu
#   just quickshell-test
{
  lib,
  runCommand,
  nodejs,
  hyprland,
  systemd,
}: let
  src = lib.fileset.toSource {
    root = ./..;
    fileset = lib.fileset.unions [
      ../quickshell/PowerActions.js
      ../quickshell/Theme.qml
      ./power-menu.test.mjs
    ];
  };
in
  runCommand "quickshell-power-menu-test" {
    nativeBuildInputs = [nodejs hyprland systemd];
  } ''
    export POWER_ACTIONS=${src}/quickshell/PowerActions.js
    export THEME_QML=${src}/quickshell/Theme.qml
    export HYPR_STUBS=${hyprland}/share/hypr/stubs/hl.meta.lua
    node --test ${src}/quickshell-tests/power-menu.test.mjs
    touch $out
  ''
