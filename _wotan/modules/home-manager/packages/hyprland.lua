-- Hyprland Lua config, migrated from the hyprlang settings in
-- modules/nixos/desktop/hyprland.nix and hosts/wotan/desktop-config.nix
-- (Hyprland 0.56 moved to Lua as the config format it looks for first).
--
-- Dispatcher/field names below were verified against the Hyprland source at
-- the pinned commit (src/config/lua/bindings/LuaBindingsDispatchers.cpp and
-- LuaBindingsConfigRules.cpp), not guessed from docs -- the wiki is
-- JS-rendered and wasn't fetchable. The `monitor = "l"/"r"/"u"/"d"` selector
-- on the four Ctrl+Arrow "push to monitor" binds is the one piece inferred
-- from the shared selector parser rather than directly observed live --
-- worth a real test after applying.
--
-- modules/nixos/desktop/hyprland.nix still generates the old hyprlang
-- /etc/xdg/hypr/hyprland.conf, and ~/.config/hypr/hyprland.conf still
-- sources it, as a fallback if this file ever fails to load. Binds here
-- must be kept in sync with hyprland.nix by hand -- there is no shared
-- source of truth between the two formats.

------------------
---- MONITORS ----
------------------

hl.monitor({ output = "DP-3", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "2560x0", scale = 1 })

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout = "de",
        follow_mouse = 1,
        numlock_by_default = true,
        sensitivity = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 20,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        layout = "dwindle",
        resize_on_border = false,
    },

    decoration = {
        rounding = 10,
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
            color = 0xee1a1a1a,
        },
        blur = {
            enabled = false,
        },
    },

    cursor = {
        no_hardware_cursors = 1,
    },
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("sleep 1 && next-wallpaper --transition-type random --transition-fps 60")
    -- hyprsunset runs via its systemd user service (hyprsunset.service), see
    -- modules/home-manager/packages/hyprland-configs.nix for why.
    hl.exec_cmd("hypridle")
end)

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- Application launcher
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("wofi --show drun"))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("rofi -show drun -run-command 'bash -c \"{cmd}\"'"))

-- Terminal
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("kitty"))

-- Browser
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("brave"))

-- Text editor
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("neovim"))

-- File manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("thunar"))

-- Wallpaper
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("next-wallpaper"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("previous-wallpaper"))

-- Screenshot (saves to ~/Pictures/hyprshot and copies to clipboard)
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region --freeze -o ~/Pictures/hyprshot"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window -o ~/Pictures/hyprshot"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m output --freeze -o ~/Pictures/hyprshot"))

-- Lockscreen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Exit menu
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("wlogout"))

-- Window controls
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.layout("togglesplit"))

-- Focus
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move/swap window within workspace; crosses to adjacent monitor only
-- when there is no window in that direction
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- Push window to an adjacent monitor unconditionally (works for tiled and
-- fullscreen windows, e.g. moving a fullscreen video)
hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.move({ monitor = "r" }))
hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.move({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.move({ monitor = "d" }))

-- Media keys (pass through to applications like Firefox)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))

-- Hyprsunset temperature adjustment (+/- 500K)
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("hyprctl hyprsunset temperature +500"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("hyprctl hyprsunset temperature -500"))
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.exec_cmd("pkill hyprsunset; hyprsunset -i"))

-- Window grouping (tabbed layout)
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + TAB", hl.dsp.group.next())
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.group.prev())
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.window.move({ out_of_group = true }))

-- Audio output switching (rofi menu / pwvucontrol GUI)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("audio-switch"))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd("pwvucontrol"))

-- Workspace bindings (number row: code:10-18)
for i = 0, 8 do
    local ws = i + 1
    hl.bind(mainMod .. " + code:1" .. i, hl.dsp.focus({ workspace = ws }))
    hl.bind(mainMod .. " + SHIFT + code:1" .. i, hl.dsp.window.move({ workspace = ws }))
end

-- Numpad workspace bindings (KP_1-KP_9)
-- Numpad layout: 7(79) 8(80) 9(81) / 4(83) 5(84) 6(85) / 1(87) 2(88) 3(89)
local numpadCodes = { 87, 88, 89, 83, 84, 85, 79, 80, 81 } -- KP_1 through KP_9
for i, code in ipairs(numpadCodes) do
    hl.bind(mainMod .. " + code:" .. code, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + code:" .. code, hl.dsp.window.move({ workspace = i }))
end

-- Mouse bindings
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- Force Brave windows to open tiled (it sometimes requests floating)
hl.window_rule({
    name = "brave-tile",
    match = { class = "(?i)brave.*" },
    tile = true,
})

-- ueberzugpp (yazi image preview) must stay floating
hl.window_rule({
    name = "ueberzugpp",
    match = { class = "ueberzugpp" },
    no_focus = true,
    no_shadow = true,
    no_blur = true,
    border_size = 0,
    float = true,
    no_anim = true,
    pin = true,
    no_initial_focus = true,
})

-- Left monitor (DP-3) - workspaces 1-5
hl.workspace_rule({ workspace = "1", monitor = "DP-3", default = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-3" })
hl.workspace_rule({ workspace = "3", monitor = "DP-3" })
hl.workspace_rule({ workspace = "4", monitor = "DP-3" })
hl.workspace_rule({ workspace = "5", monitor = "DP-3" })

-- Right monitor (DP-2) - workspaces 6-10
hl.workspace_rule({ workspace = "6", monitor = "DP-2", default = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-2" })
hl.workspace_rule({ workspace = "8", monitor = "DP-2" })
hl.workspace_rule({ workspace = "9", monitor = "DP-2" })
hl.workspace_rule({ workspace = "10", monitor = "DP-2" })
