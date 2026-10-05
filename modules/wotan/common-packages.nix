{
  config,
  pkgs,
  username,
  ...
}: {
  imports = [
    ./basics.nix
  ];
  # Common system packages that should be available on all hosts
  environment.systemPackages = with pkgs; [
    # keep-sorted start
    alejandra
    attic-client # switch.sh pushes the system closure to ventara-attic
    claude-code
    curl
    dig
    dust
    git
    opencode
    pinentry-curses
    pinentry-gnome3
    vim # Essential editor
    wget
    # keep-sorted end
  ];

  # Common programs that should be enabled on all hosts
  programs = {
    zsh.enable = true;
    mtr.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
      pinentryPackage = pkgs.pinentry-gnome3;
    };
  };

  # The account itself (normal user, zsh, wheel + networkmanager) comes from
  # modules/base.nix; wotan only adds its desktop groups. No SSH keys: wotan
  # runs no sshd, so there is nothing for authorized_keys to authorize.
  homelab.users.${username}.extraGroups = ["scanner"];

  # Common networking settings
  networking.networkmanager.enable = true;
}
