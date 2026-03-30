{
  config,
  pkgs,
  lib,
  ...
}: let
  lc0-cuda = pkgs.lc0.overrideAttrs (old: {
    buildInputs =
      old.buildInputs
      ++ [
        pkgs.cudaPackages.cudnn
        pkgs.cudaPackages.cuda_cudart
        pkgs.cudaPackages.libcublas
      ];
    mesonFlags =
      builtins.filter (f: f != "-Dplain_cuda=false" && f != "-Dnative_cuda=false") old.mesonFlags
      ++ [
        "-Dplain_cuda=true"
      ];
  });
in {
  home.packages = with pkgs; [
    # Wrap en-croissant to force X11/XWayland (Tauri/WebKit crashes on native Wayland)
    (symlinkJoin {
      name = "en-croissant-x11";
      paths = [en-croissant];
      buildInputs = [makeWrapper];
      postBuild = ''
        wrapProgram $out/bin/en-croissant \
          --set GDK_BACKEND x11 \
          --set WEBKIT_DISABLE_COMPOSITING_MODE 1
      '';
    })
    # lc0 with CUDA/cuDNN support for GPU acceleration
    lc0-cuda
  ];
}
