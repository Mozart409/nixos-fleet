{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.hofvarpnir.packages.${pkgs.system}.hofvarpnir-tui
  ];
}
