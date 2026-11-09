{
  pkgs,
  inputs,
  ...
}: {
  # nixpkgs' cargo setup hook sets LIBGIT2_NO_VENDOR=1, so git2's vendored-libgit2
  # feature fails; link the system libgit2 until the upstream zinc_oxide flake
  # adds these inputs itself.
  home.packages = [
    (inputs.zinc-oxide.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.pkg-config];
      buildInputs = (old.buildInputs or []) ++ [pkgs.libgit2];
    }))
  ];
}
