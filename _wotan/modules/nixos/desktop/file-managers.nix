{
  config,
  pkgs,
  lib,
  ...
}: {
  options.desktop.fileManagers = {
    enable = lib.mkEnableOption "GUI file manager (Thunar)";
  };

  config = lib.mkIf (config.desktop.enable && config.desktop.fileManagers.enable) {
    programs.thunar = {
      enable = true;
      plugins = with pkgs; [
        # keep-sorted start
        thunar-archive-plugin
        thunar-volman
        # keep-sorted end
      ];
    };

    environment.systemPackages = with pkgs; [
      exo # exo-open, used by Thunar's "Open Terminal Here"
      file-roller # archive backend for thunar-archive-plugin ("Extract Here" / "Create Archive")
      unrar # RAR5 extraction for file-roller

      # Thumbnail/preview generators for tumbler
      ffmpegthumbnailer # video thumbnails
      poppler-utils # PDF thumbnails (pdftoppm)
      libgsf # ODF/MS Office thumbnails
      freetype # font previews
      webp-pixbuf-loader # webp image previews
      librsvg # SVG previews
      libheif # HEIF/HEIC image previews

      # GStreamer codecs (video/audio preview)
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
    ];

    # Thunar's default "Open Terminal Here" action runs
    # `exo-open --launch TerminalEmulator`; exo resolves that via helpers.rc
    # (read from XDG_CONFIG_DIRS, so /etc/xdg works system-wide).
    environment.etc."xdg/xfce4/helpers.rc".text = ''
      TerminalEmulator=kitty
    '';

    services.tumbler.enable = true;
  };
}
