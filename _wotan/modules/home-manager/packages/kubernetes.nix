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

  home.file.".kube/kubie.yaml".text = ''
    configs:
      include:
        - ~/.kube/config
        - ~/.kube/config-*
      exclude:
        - ~/.kube/kubie.yaml
  '';
}
