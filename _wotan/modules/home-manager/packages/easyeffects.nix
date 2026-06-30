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
    # Chain (plugins_order): autogain -> compressor -> limiter. Autogain levels
    # loudness between sources toward `target`, the compressor tames dynamic range
    # within a source, then the limiter catches peaks.
    #
    # Tuning: autogain `target` is the EBU R128 loudness goal in LUFS (-16 is
    # desktop-friendly; toward 0 = louder); `maximum-history` (20s) is the trailing
    # window it averages over — shorter reacts faster but pumps more (e.g. game
    # ambience over-boosting when a streamer falls silent). Compressor
    # `threshold` (-20 dB) / `ratio` (3:1) are tuned down from the GUI defaults
    # (-12 dB / 4:1) to gently reduce dynamic range; all other compressor keys are
    # verbatim EasyEffects 8.2.4 export. Limiter `threshold` (-1 dB) leaves
    # headroom so boosted-quiet content can't clip; `alr` smooths gain changes.
    xdg.dataFile."easyeffects/output/loudness.json".text = ''
      {
          "output": {
              "autogain#0": {
                  "bypass": false,
                  "force-silence": false,
                  "input-gain": 0.0,
                  "maximum-history": 20,
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
              "compressor#0": {
                  "attack": 20.0,
                  "boost-amount": 6.0,
                  "boost-threshold": -72.0,
                  "bypass": false,
                  "dry": -80.01,
                  "hpf-frequency": 10.0,
                  "hpf-mode": "Off",
                  "input-gain": 0.0,
                  "input-to-link": -80.01,
                  "input-to-sidechain": -80.01,
                  "knee": -6.0,
                  "link-to-input": -80.01,
                  "link-to-sidechain": -80.01,
                  "lpf-frequency": 20000.0,
                  "lpf-mode": "Off",
                  "makeup": 0.0,
                  "mode": "Downward",
                  "output-gain": 0.0,
                  "ratio": 3.0,
                  "release": 100.0,
                  "release-threshold": -80.01,
                  "sidechain": {
                      "lookahead": 0.0,
                      "mode": "Peak",
                      "preamp": 0.0,
                      "reactivity": 10.0,
                      "source": "Middle",
                      "stereo-split-source": "Left/Right",
                      "type": "Feed-forward"
                  },
                  "sidechain-to-input": -80.01,
                  "sidechain-to-link": -80.01,
                  "stereo-split": false,
                  "threshold": -20.0,
                  "wet": 0.0
              },
              "plugins_order": [
                  "autogain#0",
                  "compressor#0",
                  "limiter#0"
              ]
          }
      }
    '';

    # Pin "Easy Effects Sink" as the default output so apps route through the
    # effects automatically — declaratively, without relying on WirePlumber's
    # mutable ~/.local/state. The EE sink is a client-created null-sink that no
    # WirePlumber rules-table targets, so a `priority.session` rule can't attach
    # to it; instead this oneshot sets the configured-default metadata by name
    # (exactly what `wpctl set-default` does) once the sink appears. It runs with
    # and re-runs after the EE daemon (PartOf), and falls back gracefully to the
    # hardware sink if EasyEffects ever isn't running.
    systemd.user.services.easyeffects-default-sink = {
      Unit = {
        Description = "Route the default audio output through EasyEffects";
        After = ["easyeffects.service"];
        PartOf = ["easyeffects.service"];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = let
          ee-default-sink = pkgs.writeShellScript "ee-default-sink" ''
            set -eu
            # EasyEffects creates "easyeffects_sink" shortly after the daemon
            # starts; wait up to ~30s for it before pinning it as default.
            for _ in $(seq 1 60); do
              if ${pkgs.pipewire}/bin/pw-cli ls Node 2>/dev/null | grep -q '"easyeffects_sink"'; then
                ${pkgs.pipewire}/bin/pw-metadata -n default 0 \
                  default.configured.audio.sink '{"name":"easyeffects_sink"}'
                exit 0
              fi
              sleep 0.5
            done
            echo "easyeffects_sink did not appear within timeout" >&2
            exit 1
          '';
        in "${ee-default-sink}";
      };

      Install.WantedBy = ["easyeffects.service"];
    };
  };
}
