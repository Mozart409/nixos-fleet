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
        - ~/.kube/config
        - ~/.kube/config-k3s
  '';
}
