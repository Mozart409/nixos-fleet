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

    services.tumbler.enable = true;
  };
}
