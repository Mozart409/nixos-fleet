{
  config,
  pkgs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    # keep-sorted start
    hcloud
    helm-ls
    helmfile
    helmsman
    kubectl
    kubernetes-helm
    talosctl
    # keep-sorted end
  ];

  home.sessionVariables = {
    KUBECONFIG = "$HOME/.kube/config";
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
