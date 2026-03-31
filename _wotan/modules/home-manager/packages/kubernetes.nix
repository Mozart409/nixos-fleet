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
    settings = {
      kind = "SwitchConfig";
      version = "v1alpha1";
      kubeconfigStores = [
        {
          kind = "filesystem";
          kubeconfigName = "config*";
          paths = ["~/.kube"];
        }
      ];
    };
  };
}
