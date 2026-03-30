{
  config,
  pkgs,
  lib,
  ...
}: {
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
    lc0
  ];
}
