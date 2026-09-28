{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: let
  zinc_oxide = pkgs.rustPlatform.buildRustPackage rec {
    pname = "zinc_oxide";
    version = "0.1.4";

    src = inputs.zinc-oxide;

    cargoLock = {
      lockFile = "${inputs.zinc-oxide}/Cargo.lock";
    };

    buildFeatures = ["nix"];

    nativeBuildInputs = with pkgs; [
      git
      nix
      pkg-config
    ];

    buildInputs = with pkgs; [
      openssl
    ];

    meta = with lib; {
      description = "A rust cli that checks recursively for git projects and reports their statuses";
      homepage = "https://github.com/Mozart409/zinc_oxide";
      license = licenses.mit;
      maintainers = [];
    };
  };
in {
  home.packages = [
    zinc_oxide
  ];
}
