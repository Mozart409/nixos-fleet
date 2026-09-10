pragma Singleton

import QtQuick

// Single source of truth for every colour, size and duration in the shell.
// Widgets never hardcode a hex value -- retheming happens here and nowhere
// else. Quickshell registers any `pragma Singleton` file in the config
// directory as a singleton type, so this is reachable as plain `Theme.*`.
QtObject {
  // Surfaces ----------------------------------------------------------------
  // Colours are ARGB with the alpha byte first. The bar is deliberately close
  // to opaque: at lower alpha the module pills picked up whatever wallpaper
  // sat behind them and the same widget read differently on each monitor.
  readonly property color bar: "#f5111119" // bar background
  readonly property color surface: "#1e1e28" // popup / raised panel body
  readonly property color module: "#1cffffff" // resting pill fill
  readonly property color moduleHover: "#30ffffff" // pill fill under the cursor
  readonly property color border: "#33ffffff"

  // Text --------------------------------------------------------------------
  readonly property color text: "#cfd6f4"
  readonly property color subtext: "#a6adc8"
  readonly property color muted: "#6c7086"
  readonly property color inverse: "#12121a" // text drawn on top of `accent`

  // Semantic ----------------------------------------------------------------
  readonly property color accent: "#33ccff"
  readonly property color good: "#a6e3a1"
  readonly property color warn: "#f5c542"
  readonly property color crit: "#ff6b6b"
  readonly property color special: "#cba6f7"
  readonly property color peach: "#fab387"

  // Typography --------------------------------------------------------------
  // Two distinct families on purpose: Berkeley Mono has no Nerd Font glyph
  // coverage, so anything that renders an icon must ask for the Nerd Font by
  // name. Never use `font.families` here -- this Qt build errors on the list
  // form and takes the whole config down with it.
  //
  // "Symbols Nerd Font" and not "FiraCode Nerd Font": FiraCode is not
  // installed on this host, so that name resolved to Noto Sans and every glyph
  // arrived through fontconfig's per-character fallback instead -- which works
  // until it doesn't, and gives inconsistent metrics in the meantime. Check
  // with `fc-match "<name>"` before changing this; if it answers with a
  // different family, the font you asked for isn't there.
  readonly property string font: "Berkeley Mono"
  readonly property string iconFont: "Symbols Nerd Font"
  readonly property int fontSize: 13
  readonly property int smallSize: 11
  readonly property int iconSize: 14

  // Metrics -----------------------------------------------------------------
  readonly property int barHeight: 34
  readonly property int moduleHeight: 24
  readonly property int radius: 7
  readonly property int pad: 9 // horizontal padding inside a pill
  readonly property int gap: 6 // between pills
  readonly property int groupGap: 12 // between groups of pills

  readonly property int anim: 150 // standard transition, ms
  readonly property int animSlow: 300

  // Maps a 0-100 "how loaded is it" number onto the semantic ramp. Used by
  // every resource readout so CPU, RAM, GPU and disk agree on what "hot" is.
  function loadColor(pct) {
    if (pct >= 85)
      return crit;
    if (pct >= 60)
      return warn;
    return text;
  }

  // Same ramp, inverted, for values where *low* is the problem (free disk).
  function headroomColor(pct) {
    if (pct <= 15)
      return crit;
    if (pct <= 30)
      return warn;
    return text;
  }
}
