{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    kubectl
    kubernetes-helm
    helm-ls
    helmsman
    helmfile
    talosctl
    kubie
    hcloud
  ];
}
