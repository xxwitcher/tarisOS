-- Copyright (C) 2026 George Dobreff ("Witcher") and contributors
-- SPDX-License-Identifier: GPL-3.0-only

-- TarisOS's Hyprland config (/usr/share/taris/hypr, from the taris-desktop package: updates
-- reach it). ~/.config/hypr/hyprland.lua loads it; your own changes go in ~/.config/hypr/user.lua,
-- loaded last, or come from the Window style, Displays and Keyboard pages in Settings.

local home = os.getenv("HOME")
local share = "/usr/share/taris/hypr"
local terminal = os.getenv("TERMINAL") or "kitty"
local browser = "chromium"
local files = "nautilus --new-window"

-- Monitors: everything at its preferred mode, scale 2 suits Apple Silicon panels
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 2 })

-- Environment
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("GDK_SCALE", "2")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XCURSOR_SIZE", "24")
-- Chinese, Japanese or Korean typing (fcitx5, installed from Settings > Language & Region)
local fcitx = io.open("/usr/bin/fcitx5")
if fcitx then
  fcitx:close()
  hl.env("QT_IM_MODULE", "fcitx")
  hl.env("XMODIFIERS", "@im=fcitx")
  hl.env("SDL_IM_MODULE", "fcitx")
end

-- Autostart
hl.on("hyprland.start", function()
  hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
  hl.exec_cmd("dbus-update-activation-environment --systemd --all")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark")
  hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
  hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
  hl.exec_cmd("wl-paste --watch cliphist store")
  -- A new account's defaults (colours, wallpaper, web apps) before the shell reads them, and
  -- Chromium's settings (taris-chromium)
  hl.exec_cmd("sh -c '/usr/lib/taris/user-defaults --if-new; [ -x /usr/lib/taris/chromium-flags ] && /usr/lib/taris/chromium-flags; exec taris shell -d'")
  -- Apps set to Open at Login (~/.config/autostart; the dock's menu sets them)
  hl.exec_cmd("systemctl --user start xdg-desktop-autostart.target")
end)

-- The system's keyboard layout (chosen on first boot) until one is picked in Settings > Keyboard
local layout, variant = "us", ""
local kb = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf")
if kb then
  for line in kb:lines() do
    layout = line:match('Option%s+"XkbLayout"%s+"([^"]*)"') or layout
    variant = line:match('Option%s+"XkbVariant"%s+"([^"]*)"') or variant
  end
  kb:close()
end

-- Look and feel (border size and gaps come from the Window style page)
hl.config({
  general = { layout = "dwindle" },
  -- Splits keep their direction: otherwise dwindle picks it again from each area's shape, and
  -- resizing a tiled window flips splits between side by side and stacked, moving windows around.
  -- New windows open to the right or below, wherever the pointer is.
  dwindle = { preserve_split = true, force_split = 2 },
  decoration = { rounding = 12, blur = { enabled = true, size = 6, passes = 2 } },
  input = {
    kb_layout = layout,
    kb_variant = variant,
    repeat_rate = 40,
    repeat_delay = 250,
    follow_mouse = 1,
    -- Physical clicks only: on the Asahi touchpad, disable_while_typing doesn't stop a palm's taps
    -- while typing. Settings > Keyboard & trackpad turns tapping back on.
    touchpad = { natural_scroll = true, tap_to_click = false, disable_while_typing = true, clickfinger_behavior = true },
  },
  misc = { disable_hyprland_logo = true, disable_splash_rendering = true },
})

-- Apps
hl.bind("SUPER + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind("SUPER + B", hl.dsp.exec_cmd(browser))
hl.bind("SUPER + E", hl.dsp.exec_cmd(files))
hl.bind("SUPER + SPACE", hl.dsp.global("taris:launcher"))
hl.bind("SUPER + TAB", hl.dsp.global("taris:overview"))
hl.bind("SUPER + ESCAPE", hl.dsp.global("taris:session"))
hl.bind("SUPER + L", hl.dsp.global("taris:lock"))
hl.bind("SUPER + V", hl.dsp.exec_cmd("taris clipboard"))
hl.bind("PRINT", hl.dsp.global("taris:screenshot"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("taris record -r"))

-- Windows
hl.bind("SUPER + W", hl.dsp.window.close())
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
-- (SUPER + M minimizes, from taris.lua)
hl.bind("SUPER + SHIFT + M", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))
for key, dir in pairs({ LEFT = "l", RIGHT = "r", UP = "u", DOWN = "d" }) do
  hl.bind("SUPER + " .. key, hl.dsp.focus({ direction = dir }))
end
-- Apps don't maximize themselves: kitty, for one, saves the state it was closed in and asks to be
-- maximized again, and Hyprland then keeps a tiled window maximized. The shell's maximize buttons
-- aren't requests from the app, so they still work.
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
-- XWayland apps' drag-and-drop surfaces (no class or title) never take the focus
hl.window_rule({
  name = "fix-xwayland-drags",
  match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
  no_focus = true,
})
-- The terminal opens floating in the middle of the screen, at 60% of its width and height
hl.window_rule({
  name = "terminal-floating",
  match = { class = "^(kitty)$" },
  float = true,
  center = true,
  size = { "monitor_w*0.6", "monitor_h*0.6" },
})
-- Nautilus's previews (Space) float in the middle
hl.window_rule({ match = { class = "^(org.gnome.NautilusPreviewer)$" }, float = true, center = true })

hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Workspaces
for i = 1, 9 do
  hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind("SUPER + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Media and hardware keys (Taris shows the OSD)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
-- The keyboard's backlight (the Touch Bar's keys, or the keyboard's own on Macs without one)
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%+"), { locked = true, repeating = true })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd("brightnessctl -d kbd_backlight set 10%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.global("taris:brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("taris:brightnessDown"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.global("taris:mediaToggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("taris:mediaNext"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("taris:mediaPrev"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.global("taris:mediaToggle"), { locked = true })
hl.bind("SHIFT + XF86AudioPlay", hl.dsp.global("taris:mediaSwitch"), { locked = true })

-- Double-tapping Fn (the globe key) switches input sources. Only quick taps with no other key in
-- between count, so Fn + arrows, Fn + Delete and the Touch Bar's F-keys never switch. Settings >
-- Keyboard & trackpad turns it off when another way is picked (taris_fn_switch, in
-- hypr-settings.lua and live).
_G.taris_fn_switch = true
local fnKey = 472 -- KEY_FN, as xkbcommon numbers it
local fnPressed, fnTapped
hl.on("input.keyboard.key", function(code, time, state)
  if not _G.taris_fn_switch then
    return
  end
  if code ~= fnKey then
    if state == 1 then
      fnPressed, fnTapped = nil, nil
    end
  elseif state == 1 then
    fnPressed = time
  elseif state == 0 then
    if fnPressed and time - fnPressed < 300 then
      if fnTapped and fnPressed - fnTapped < 400 then
        fnTapped = nil
        hl.dispatch(hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
      else
        fnTapped = time
      end
    else
      fnTapped = nil
    end
    fnPressed = nil
  end
end)

-- The shell's integration (layer rules, gestures, window style, CTRL + Q, SUPER + M and SUPER + A,
-- settings), then your own changes
-- (A machine without taris-desktop yet, set up by an older install.sh: its link to the checkout's)
local integration = share .. "/taris.lua"
local f = io.open(integration)
if f then f:close() else integration = home .. "/.config/taris/hypr-taris.lua" end
pcall(dofile, integration)
pcall(dofile, home .. "/.config/hypr/user.lua")
