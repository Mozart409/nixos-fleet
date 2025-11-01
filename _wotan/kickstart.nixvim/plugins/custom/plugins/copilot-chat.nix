{pkgs, ...}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      lua53Packages.tiktoken_core
      ripgrep
      lynx
    ];

    plugins.copilot-chat = {
      enable = true;
    };
  };
}
