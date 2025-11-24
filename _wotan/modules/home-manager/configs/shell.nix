{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;
    autocd = true;
    zprof.enable = false;
    historySubstringSearch.enable = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    shellAliases = {
      l = "ls -lah";
      lg = "lazygit";
      ld = "lazydocker";
      sys = "systemctl status";
      syr = "systemctl restart";
      k = "kubectl";
      flk = "cd /etc/nixos";
      dps = "docker compose ps";
      dup = "docker compose up -d --build --remove-orphans";
      dwn = "docker compose down";
      n = "nvim .";
    };
    oh-my-zsh = {
      enable = true;
      # theme = "fino";
      theme = "dogenpunk";
      plugins = [
        "git"
        "z"
      ];
    };
  };
}
