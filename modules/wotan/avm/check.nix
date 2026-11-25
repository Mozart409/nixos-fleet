# The VM-free tests of avm (classify and the git gate) as a hermetic run with
# pinned git and bash. Opt-in, not under `checks`:
#   nix build .#legacyPackages.x86_64-linux.avm.checks.git-gate
#   just avm-check
# The plain run is `just avm-test`.
{
  lib,
  runCommand,
  gitMinimal,
  shellcheck,
}: let
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./avm.sh ./classify.sh ./tests];
  };
in
  runCommand "avm-check" {
    nativeBuildInputs = [gitMinimal shellcheck];
  } ''
    cp -r ${src} ./avm
    chmod -R u+w ./avm
    cd ./avm
    shellcheck -x avm.sh classify.sh tests/*.sh
    patchShebangs .
    export HOME=$TMPDIR/home && mkdir -p "$HOME"
    ./tests/classify.sh
    ./tests/git.sh
    touch $out
  ''
