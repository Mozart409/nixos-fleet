{...}: {
  # Git base for every home-manager user: the fleet (flake.nix homeManagerNixvim)
  # and wotan (modules/home/configs/programs.nix, which adds identity/signing).
  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.sshCommand = "ssh -o ConnectTimeout=5";
    };
    ignores = [
      "*~"
      "*.swp"
    ];
  };
}
