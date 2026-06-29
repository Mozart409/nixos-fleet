# EasyEffects Tuning Guide

System-wide loudness normalization for `wotan`, configured declaratively in
[`modules/home-manager/packages/easyeffects.nix`](../modules/home-manager/packages/easyeffects.nix)
and enabled with `desktop.easyeffects.enable = true;`.

EasyEffects inserts itself as a virtual PipeWire output sink (`easyeffects_sink`),
pinned as the default output, so every app (Brave, mpv, …) is processed before
reaching the real device.

## How it works

The `loudness` preset is shipped as a verbatim EasyEffects 8.2.4 JSON export
(not via Nix `toJSON`) because the 8.x schema is strict — any missing or
mistyped key triggers a "wrong format" error on load. Edit the JSON inside the
`xdg.dataFile."easyeffects/output/loudness.json"` block, then rebuild.

**Signal chain** (`plugins_order`): `autogain → compressor → limiter`

| Stage | Job |
|---|---|
| **autogain** | Levels loudness *between* sources toward an EBU R128 target (LUFS) |
| **compressor** | Tames dynamic range *within* a source (loud/quiet swings) |
| **limiter** | Catches peaks so boosted content can't clip |

## Applying changes

1. Edit `loudness.json` in `modules/home-manager/packages/easyeffects.nix`.
2. Rebuild: `./switch.sh` (or `nh os switch .#nixosConfigurations.wotan`).
3. Change **one** value at a time and listen for a day before the next tweak.

> **Schema safety:** to add a new plugin, create it once in the EasyEffects GUI
> with default settings, save it as a throwaway preset, and copy the exact
> exported block (correct keys + float formatting) into `loudness.json`. Don't
> hand-write plugin blocks from memory.

## autogain — overall loudness leveling

| Key | Current | Tune toward |
|---|---|---|
| `target` | `-16.0` | **Louder overall:** raise toward `-14` / `-12`. Quieter: lower. |
| `maximum-history` | `10.0` | **Snappier** adjustment: lower (e.g. `6`). **Smoother / less pumping:** raise (`15`). |
| `reference` | `"Integrated"` | `"Short-term"` / `"Momentary"` react faster to quiet→loud jumps, but pump more. |

The output-gain readout swinging between `0` and `+24 dB` is **normal** — `+24 dB`
is autogain's hard ceiling, hit when a source is so quiet it can't reach `target`.
It reflects loudness differences *between* sources, not a misconfiguration. Don't
lower `target` to "fix" it — quiet sources are already gain-capped, and it only
pushes loud sources into the limiter.

## compressor — dynamic range within a source

| Key | Current | Tune toward |
|---|---|---|
| `threshold` | `-20.0` | **More leveling** (quiet parts brought up): lower (`-24`). **Less:** raise (`-16`). |
| `ratio` | `3.0` | **Stronger** squashing: raise (`4`–`6`). **Gentler:** lower (`2`). |
| `attack` / `release` | `20` / `100` | Faster attack clamps transients harder; longer release = smoother, less pumping. |
| `makeup` | `0.0` | Add gain if compression makes things feel quiet (autogain mostly covers this). |

Current `threshold` / `ratio` are tuned down from the GUI defaults (`-12` / `4:1`)
for gentle dynamic-range control. All other compressor keys are the verbatim
8.2.4 export.

## limiter — peak safety (leave mostly alone)

| Key | Current | Note |
|---|---|---|
| `threshold` | `-1.0` | Lower (`-2`) = more headroom; closer to `0` = louder but clipping risk. |
| `lookahead` | `5.0` | Raise for harder peak catching, but it **adds latency** (bad for video / games). |

## Quick decision guide

- **Too quiet overall** → raise autogain `target` first (not the limiter).
- **Transitions between apps feel laggy** → lower autogain `maximum-history`.
- **One track's quiet/loud swings bug you** → lower compressor `threshold` or raise `ratio`.
- **Hearing pumping/breathing** → raise `maximum-history`, lengthen compressor `release`.

## Related

- Module: [`modules/home-manager/packages/easyeffects.nix`](../modules/home-manager/packages/easyeffects.nix)
- The Breeze Dark GUI theme is runtime state, not part of the flake.
