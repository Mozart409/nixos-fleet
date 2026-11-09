{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk4,
  libGL,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  wayland,
  commandLineArgs ? "",
}:
# Prebuilt upstream tarball, patched with autoPatchelf. Bump = version + hash
# (hash from the release's sha256 digest via `nix hash convert --to sri`).
# Reads Chromium policies from /etc/chromium/policies.
stdenv.mkDerivation (finalAttrs: let
  runtimeLibs = [
    libGL
    libva
    vulkan-loader
    pipewire
    libpulseaudio
    wayland
    gtk3
    gtk4
    libnotify
    (lib.getLib systemd)
  ];
in {
  pname = "helium";
  version = "0.21.1.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-bNfyQBU8ucDN+ie/GmZR3crnOomK/ESak90Q2oO0vUU=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    glib
    libdrm
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    (lib.getLib systemd)
    stdenv.cc.cc.lib
  ];

  runtimeDependencies = runtimeLibs;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Optional Qt theming shims; dropping them avoids pulling in Qt.
    rm -f libqt5_shim.so libqt6_shim.so

    mkdir -p $out/opt/helium $out/bin
    cp -r . $out/opt/helium

    makeWrapper $out/opt/helium/helium $out/bin/helium \
      --set CHROME_WRAPPER $out/bin/helium \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath runtimeLibs} \
      --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}" \
      --add-flags "${commandLineArgs}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    install -Dm644 helium.desktop $out/share/applications/helium.desktop
    install -Dm644 product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
  '';

  meta = {
    description = "Private, fast and honest web browser based on Chromium";
    homepage = "https://helium.computer";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "helium";
  };
})
