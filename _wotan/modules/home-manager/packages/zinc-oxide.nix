{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.zinc-oxide.packages.${pkgs.system}.default
  ];
}
