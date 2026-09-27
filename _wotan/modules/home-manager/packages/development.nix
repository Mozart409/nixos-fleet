{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    bacon
    bruno
    bruno-cli
    btop
    bun
    cargo-binstall
    cocogitto
    d2
    deadbranch
    deadnix
    devenv
    dprint
    eza
    gnused
    insomnia
    jq
    keep-sorted
    lefthook
    mergiraf
    nix-prefetch
    nix-prefetch-github
    nodejs_26
    otel-cli
    pkg-configUpstream
    pnpm
    pwgen
    python3
    python314Packages.huggingface-hub
    rainfrog
    rustscan
    tpi
    vale
    wasm-bindgen-cli
    wev
    zk
    # keep-sorted end
  ];
}
