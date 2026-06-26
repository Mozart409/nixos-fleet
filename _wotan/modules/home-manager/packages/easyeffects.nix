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
    # EasyEffects inserts itself as a virtual PipeWire output sink ("Easy Effects
    # Sink"). Make it the default output and every app routed there (Brave, mpv,
    # etc.) is processed before being forwarded to the real device, regardless of
    # source. The "loudness" preset levels all sources toward a common loudness
    # and catches peaks with a limiter.
    #
    # Requires system-level `programs.dconf.enable = true`
    # (set in modules/nixos/desktop/default.nix).
    services.easyeffects = {
      enable = true;
      # Auto-load the preset below when the daemon starts.
      preset = "loudness";
    };

    # NOTE: the preset is shipped as a verbatim EasyEffects 8.x JSON file instead
    # of via `services.easyeffects.extraPresets`. The 8.x preset schema differs
    # from 7.x (e.g. the limiter `stereo-link` is a float, not the string
    # "Maximum", plus added `*-to-*` sidechain keys); going through Nix's toJSON
    # can also reformat floats. This file is byte-for-byte what EasyEffects 8.2.4
    # itself exports, so it loads with no "wrong format" error.
    #
    # Tuning: autogain `target` is the EBU R128 loudness goal in LUFS (-16 is
    # desktop-friendly; toward 0 = louder). Limiter `threshold` (-1 dB) leaves
    # headroom so boosted-quiet content can't clip; `alr` smooths gain changes.
    xdg.dataFile."easyeffects/output/loudness.json".text = ''
      {
          "output": {
              "autogain#0": {
                  "bypass": false,
                  "force-silence": false,
                  "input-gain": 0.0,
                  "maximum-history": 15,
                  "output-gain": 0.0,
                  "reference": "Integrated",
                  "silence-threshold": -70.0,
                  "target": -16.0
              },
              "blocklist": [],
              "limiter#0": {
                  "alr": true,
                  "alr-attack": 5.0,
                  "alr-knee": 0.0,
                  "alr-knee-smooth": -5.0,
                  "alr-release": 50.0,
                  "attack": 5.0,
                  "bypass": false,
                  "dithering": "None",
                  "gain-boost": true,
                  "input-gain": 0.0,
                  "input-to-link": -80.01,
                  "input-to-sidechain": -80.01,
                  "link-to-input": -80.01,
                  "link-to-sidechain": -80.01,
                  "lookahead": 5.0,
                  "mode": "Herm Thin",
                  "output-gain": 0.0,
                  "oversampling": "None",
                  "release": 5.0,
                  "sidechain-preamp": 0.0,
                  "sidechain-to-input": -80.01,
                  "sidechain-to-link": -80.01,
                  "sidechain-type": "Internal",
                  "stereo-link": 100.0,
                  "threshold": -1.0
              },
              "plugins_order": [
                  "autogain#0",
                  "limiter#0"
              ]
          }
      }
    '';
  };
}
