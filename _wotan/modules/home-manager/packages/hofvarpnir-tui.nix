{
  pkgs,
  inputs,
  ...
}: {
  home.packages = [
    inputs.hofvarpnir.packages.${pkgs.system}.hofvarpnir-tui
  ];
  home.shellAliases.hf-tui = "hofvarpnir-tui";

  # The config holds no secret: the API key is the agenix secret
  # age.secrets.hofvarpnir-tui (hosts/wotan/default.nix), referenced by path.
  xdg.configFile."hofvarpnir/tui.toml".source = (pkgs.formats.toml {}).generate "tui.toml" {
    api_url = "https://hofvarpnir.homelab.internal";
    token_file = "/run/agenix/hofvarpnir-tui";
  };
}
