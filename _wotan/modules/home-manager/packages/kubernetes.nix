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
    hcloud
  ];

  programs.kubeswitch = {
    enable = true;
    enableZshIntegration = true;
  };
}
