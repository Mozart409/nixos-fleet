{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.zinc-oxide.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
