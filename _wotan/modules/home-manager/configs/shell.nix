{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.zsh = {
    enable = true;
    zprof.enable = false;
    history = {
      expireDuplicatesFirst = true;
      extended = true;
      ignoreDups = true;
      save = 5000;
      size = 5000;
      saveNoDups = true;
      share = true;
    };
    setOptions = [
      "HIST_IGNORE_SPACE"
    ];
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
      pup = "podman-compose up -d";
      pwn = "podman-compose down";
      n = "nvim .";
      t = "tmux";
      op = "nix run github:anomalyco/opencode";
      zkdir = "cd ~/code/zettelkasten/";
      s = "kitty +kitten ssh";
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
