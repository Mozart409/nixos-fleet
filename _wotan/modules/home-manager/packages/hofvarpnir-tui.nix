{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.hofvarpnir.packages.${pkgs.system}.hofvarpnir-tui
  ];
  home.shellAliases.hf-tui = "hofvarpnir-tui";
}
