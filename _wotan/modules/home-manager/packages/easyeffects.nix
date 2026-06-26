{
  config,
  pkgs,
  lib,
  ...
}: {
  options = {
    desktop.easyeffects.enable =
      lib.mkEnableOption "EasyEffects system-wide loudness normalization (EBU R128 auto gain + limiter)";
  };

  config = lib.mkIf config.desktop.easyeffects.enable {
    # EasyEffects inserts itself as a virtual PipeWire output sink, so every app
    # routed to the default output (Brave, mpv, etc.) is processed regardless of
    # source. The "loudness" preset below levels all sources toward a common
    # target loudness and catches peaks with a limiter.
    #
    # Requires system-level `programs.dconf.enable = true`
    # (set in modules/nixos/desktop/default.nix).
    services.easyeffects = {
      enable = true;

      # Auto-load the preset below when the daemon starts.
      preset = "loudness";

      extraPresets = {
        loudness = {
          output = {
            blocklist = [];
            "plugins_order" = [
              "autogain#0"
              "limiter#0"
            ];

            # EBU R128 loudness normalization. Boosts quiet sources and tames
            # loud ones toward -16 LUFS (desktop-friendly; broadcast default is
            # -23). Raise `target` toward 0 for louder, lower for quieter.
            "autogain#0" = {
              bypass = false;
              "input-gain" = 0.0;
              "output-gain" = 0.0;
              "maximum-history" = 15;
              reference = "Integrated";
              "silence-threshold" = -70.0;
              target = -16.0;
            };

            # Catches peaks after auto gain so boosted-quiet content can't clip.
            "limiter#0" = {
              bypass = false;
              "input-gain" = 0.0;
              "output-gain" = 0.0;
              "gain-boost" = true;
              mode = "Herm Thin";
              oversampling = "None";
              dithering = "None";
              threshold = -1.0;
              "sidechain-preamp" = 0.0;
              lookahead = 5.0;
              attack = 5.0;
              release = 5.0;
              "stereo-link" = "Maximum";
              "external-sidechain" = false;
              alr = false;
              "alr-attack" = 5.0;
              "alr-release" = 50.0;
              "alr-knee" = 0.0;
            };
          };
        };
      };
    };
  };
}
