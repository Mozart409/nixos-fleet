{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./basics.nix
  ];
  # Common system packages that should be available on all hosts
  environment.systemPackages = with pkgs; [
    vim # Essential editor
    wget
    curl
    git
    dust
    alejandra
    pinentry-curses
    pinentry-gnome3
    dig
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

  # Common user configuration
  users.users.amadeus = {
    isNormalUser = true;
    description = "amadeus";
    extraGroups = ["networkmanager" "wheel" "scanner"];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHv1USrKf6yIjg8dZolm37xGysGfj18ol1KUKqsVuQHa amadeus@wotan"
    ];
  };

  # Common networking settings
  networking.networkmanager.enable = true;
}
