{pkgs, ...}: {
  home.packages = with pkgs; [
    # keep-sorted start
    exiftool # metadata read/write/strip
    imagemagick # convert, mogrify, magick
    imv # Wayland image viewer
    libjpeg_turbo # jpegtran (lossless JPEG rotate/crop/optimize)
    libwebp # cwebp, dwebp
    oxipng # lossless PNG optimizer
    pngquant # lossy PNG palette compression
    vips # fast, low-memory batch processing
    # keep-sorted end
  ];
}
