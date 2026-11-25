# avm, the host-side git transport and review gate for the agent VMs, with its
# tools pinned on PATH and the ssh client fixed to `avmSsh`. avm.sh finds
# classify.sh next to itself, so both live in libexec and bin/avm is a wrapper.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  diffutils,
  findutils,
  gawk,
  git,
  gnused,
  less,
  avmSsh,
}:
stdenvNoCC.mkDerivation {
  pname = "avm";
  version = "0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [./avm.sh ./classify.sh];
  };

  strictDeps = true;
  nativeBuildInputs = [makeWrapper];
  # With strictDeps, patchShebangs finds bash for the host platform here.
  buildInputs = [bash];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 avm.sh classify.sh -t $out/libexec/avm
    # --set, not --set-default: the caller's environment must not be able to
    # replace the ssh client.
    makeWrapper $out/libexec/avm/avm.sh $out/bin/avm \
      --set AVM_SSH ${lib.getExe avmSsh} \
      --prefix PATH : ${lib.makeBinPath [bash coreutils diffutils findutils gawk git gnused less]}
    runHook postInstall
  '';

  meta.mainProgram = "avm";
}
