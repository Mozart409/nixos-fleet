{
  lib,
  pkgs,
  ...
}: let
  # Jellyfish — a pure-CSS reskin of the stock Jellyfin web client, with rules
  # for Jellyfin 12's Modern (React) layout as well as the Legacy layouts, so
  # no client has to be switched to "Desktop (Legacy)" for it to apply.
  # https://github.com/n00bcodr/Jellyfish
  #
  # Pinned to a commit on main: upstream has cut no release since 1.0 (2025)
  # and ships straight from main. Bumping = change rev, set hash = lib.fakeHash,
  # build, paste the hash Nix reports.
  version = "unstable-2026-10-28";
  jellyfish = pkgs.fetchFromGitHub {
    owner = "n00bcodr";
    repo = "Jellyfish";
    rev = "206f50d80a29ea186dfc8dea2b41424120b0d40a";
    hash = "sha256-sapsZ7xc4iHPrdTnJdUKjol4mc+8yMRzy0+FfyRke38=";
  };

  # theme.css @imports this second repo (metadata-provider logos on item
  # pages) from jsDelivr, so it is vendored the same way.
  iconMetadata = pkgs.fetchFromGitHub {
    owner = "Druidblack";
    repo = "jellyfin-icon-metadata";
    rev = "b3f5b737e0274e93c0a00ac9aabeba1618322c93";
    hash = "sha256-PB3xJTVbzHdwWomtNvZvOibv5O9mrX+VLj7GqvQ0bok=";
  };

  # loginpage.css hotlinks its backdrop from imgur.
  loginBackdrop = pkgs.fetchurl {
    name = "jellyfish-login-backdrop.png";
    url = "https://i.imgur.com/Ewk3Pqw.png";
    hash = "sha256-KrXb0pFqcRgQKSUAi/EF4EyvS2EQwtwY1WFBoz1xqyw=";
  };

  # Keep jsDelivr, GitHub and imgur out of the client: every remote reference
  # in the files the theme actually loads is rewritten to this absolute path.
  # Absolute, not relative, because the palette sets --logo and
  # --background-image as url()s inside custom properties, and browsers do not
  # agree on what a relative URL there resolves against. Jellyfin serves the
  # webdir at <BaseUrl>/web, and BaseUrl is empty here (Caddy proxies the root).
  themeBase = "/web/jellyfish";
  themeDir = "$out/share/jellyfin-web/jellyfish";

  # Copy the prebuilt jellyfin-web output and add the theme, rather than
  # overrideAttrs'ing jellyfin-web — that would re-run the full npm production
  # build locally on every nixpkgs bump for what is ultimately a stylesheet.
  #
  # The theme lives in its own jellyfish/ subdir so it can never collide with
  # the webdir's own top-level files (assets/, etc.).
  themedWeb = pkgs.runCommand "jellyfin-web-jellyfish-${version}" {} ''
    mkdir -p $out/share
    cp -r ${pkgs.jellyfin-web}/share/jellyfin-web $out/share/jellyfin-web
    chmod -R u+w $out/share/jellyfin-web

    mkdir -p ${themeDir}
    cp -r ${jellyfish}/theme.css ${jellyfish}/loginpage.css \
      ${jellyfish}/fonts ${jellyfish}/colors ${jellyfish}/logos ${themeDir}/
    mkdir -p ${themeDir}/icon-metadata
    cp -r ${iconMetadata}/public-icon.css ${iconMetadata}/icons ${themeDir}/icon-metadata/
    install -Dm444 ${loginBackdrop} ${themeDir}/images/login-backdrop.png
    chmod -R u+w ${themeDir}

    # replace-fail on every remote reference: if upstream changes how it
    # loads a file, the build breaks instead of silently shipping a
    # CDN-backed client again.
    substituteInPlace ${themeDir}/theme.css \
      --replace-fail 'https://cdn.jsdelivr.net/gh/n00bcodr/Jellyfish/' '${themeBase}/' \
      --replace-fail 'https://cdn.jsdelivr.net/gh/Druidblack/jellyfin-icon-metadata/' '${themeBase}/icon-metadata/'
    substituteInPlace ${themeDir}/colors/jellyblue.css \
      --replace-fail 'https://cdn.jsdelivr.net/gh/n00bcodr/jellyfish/' '${themeBase}/' \
      --replace-fail 'https://cdn.jsdelivr.net/gh/n00bcodr/Jellyfish/' '${themeBase}/'
    substituteInPlace ${themeDir}/loginpage.css \
      --replace-fail 'https://i.imgur.com/Ewk3Pqw.png' '${themeBase}/images/login-backdrop.png'
    substituteInPlace ${themeDir}/icon-metadata/public-icon.css \
      --replace-fail 'https://cdn.jsdelivr.net/gh/Druidblack/jellyfin-icon-metadata@main/icons/' '${themeBase}/icon-metadata/icons/' \
      --replace-fail 'https://raw.githubusercontent.com/Druidblack/jellyfin-icon-metadata/refs/heads/main/icons/' '${themeBase}/icon-metadata/icons/'

    # replace-fail only proves each pattern matched at least once; this
    # catches any remote url() left over in the stylesheets the client loads
    # (comments and inline SVG data URIs mention http:// harmlessly). The
    # other palettes under colors/ still point at jsDelivr and are not loaded.
    if grep -nP 'url\(\s*["\x27]?https?://' \
      ${themeDir}/theme.css ${themeDir}/loginpage.css ${themeDir}/colors/jellyblue.css \
      ${themeDir}/fonts/*.css ${themeDir}/icon-metadata/public-icon.css; then
      echo "jellyfish: remote URL left in a loaded stylesheet" >&2
      exit 1
    fi

    # replace-fail: if upstream jellyfin-web ever restructures index.html, the
    # build breaks loudly instead of silently shipping an unthemed client.
    substituteInPlace $out/share/jellyfin-web/index.html \
      --replace-fail '</head>' \
        '<link rel="stylesheet" href="jellyfish/theme.css"></head>'
  '';
in {
  # services.jellyfin.package is a wrapper whose only tie to the frontend is
  # `--webdir=''${jellyfin-web}/share/jellyfin-web`, and jellyfin-web is a plain
  # function argument — so overriding it swaps the UI declaratively, with no
  # mutable state in dataDir. This is deliberately NOT the Dashboard > General >
  # "Custom CSS" box: that persists into branding.xml inside Jellyfin's state
  # dir, i.e. outside this repo (same class of problem ./sso-plugin.nix documents
  # for plugin settings).
  services.jellyfin.package = pkgs.jellyfin.override {jellyfin-web = themedWeb;};
}
