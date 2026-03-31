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

  home.sessionVariables = {
    KUBECONFIG = "$HOME/.kube/config-k3s:$HOME/.kube/config";
  };

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
