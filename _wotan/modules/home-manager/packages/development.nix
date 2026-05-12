{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    bacon
    btop
    bun
    cargo-binstall
    cocogitto
    d2
    deadbranch
    devenv
    dioxus-cli
    dprint
    eza
    gnused
    hadolint
    insomnia
    jq
    keep-sorted
    lazydocker
    lefthook
    mergiraf
    nix-prefetch
    nix-prefetch-github
    nodejs_22
    otel-cli
    pkg-configUpstream
    pnpm
    pwgen
    python314Packages.huggingface-hub
    radicle-desktop
    radicle-tui
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
