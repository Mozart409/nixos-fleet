{pkgs, ...}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      luajitPackages.tiktoken_core
      ripgrep
      lynx
    ];

    plugins.copilot-chat = {
      enable = true;
    };
  };
}
