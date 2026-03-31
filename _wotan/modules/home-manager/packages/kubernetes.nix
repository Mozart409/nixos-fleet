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

  xdg.configFile."kubie/kubie.yaml".text = ''
    configs:
      include:
        - ${config.home.homeDirectory}/.kube/config*
  '';
}
