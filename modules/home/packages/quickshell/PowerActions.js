.pragma library

// PowerMenu.qml's entries, kept out of the QML so the command lines can be
// tested without a running shell: quickshell-tests/power-menu.test.mjs checks
// every binary, subcommand and Hyprland dispatcher here against the pinned
// packages (`just quickshell-test`). `colour` names a Theme property.
//
// The commands are deliberately the same ones the Hyprland keybinds and
// wlogout use, so the menu and the keyboard never disagree about what "lock"
// means. Since Hyprland's Lua config (0.57), `hyprctl dispatch` takes a Lua
// dispatcher expression: the old `hyprctl dispatch exit` is a silent no-op.
var actions = [
  {
    icon: "󰌾",
    label: "Lock",
    colour: "accent",
    exec: ["loginctl", "lock-session"]
  },
  {
    icon: "󰤄",
    label: "Suspend",
    colour: "special",
    exec: ["systemctl", "suspend"]
  },
  {
    icon: "󰗽",
    label: "Log out",
    colour: "peach",
    exec: ["hyprctl", "dispatch", "hl.dsp.exit()"]
  },
  {
    icon: "󰜉",
    label: "Reboot",
    colour: "warn",
    exec: ["systemctl", "reboot"]
  },
  {
    icon: "󰐥",
    label: "Shut down",
    colour: "crit",
    exec: ["systemctl", "poweroff"]
  }
];
