{pkgs, ...}: {
  programs.nixvim = {
    extraPackages = with pkgs; [
      chafa
      libcaca
      viu
    ];
    plugins.fff = {
      enable = false;
      autoLoad = false;
      settings = {
        key_bindings = {
          close = [
            "<Esc>"
            "<C-c>"
          ];
          select = [
            "<CR>"
            "<Enter>"
          ];
          move_down = [
            "<Down>"
            "<S-Tab>"
          ];
          move_up = [
            "<Up>"
            "<Tab>"
          ];
          open_split = "<C-s>";
          open_tab = "<C-t>";
          open_vsplit = "<C-v>";
          select_file = "<CR>";
        };
        layout = {
          height = 0.8;
          preview_position = "right";
          width = 0.8;
        };
        max_results = 25;
      };
    };
  };
}
