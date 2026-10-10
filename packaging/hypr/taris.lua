-- Copyright (C) 2026 George Dobreff ("Witcher") and contributors
-- SPDX-License-Identifier: GPL-3.0-only

-- TarisOS: the shell's integration with Hyprland (/usr/share/taris/hypr), loaded from the end of
-- hyprland.lua. Settings made on the Displays and Keyboard pages live in
-- ~/.config/taris/hypr-settings.lua; the Window style page writes ~/.config/taris/window-style.conf.

local home = os.getenv("HOME")
local qs = "taris-qs -c taris"

-- Panels animate themselves
hl.layer_rule({ match = { namespace = "taris-(border-exclusion|area-picker|overview)" }, no_anim = true })
hl.layer_rule({ match = { namespace = "taris-(drawers|background)" }, animation = "fade" })

-- Shell shortcuts
hl.bind("SUPER + GRAVE", hl.dsp.global("taris:overview"))
pcall(hl.unbind, "SUPER + SPACE")
hl.bind("SUPER + SPACE", hl.dsp.global("taris:launcher"))
hl.bind("SUPER + N", hl.dsp.global("taris:sidebar"))
hl.bind("SUPER + COMMA", hl.dsp.exec_cmd(qs .. " ipc call nexus open"))

-- 3-finger swipe up opens the window overview, down closes it
hl.gesture({ fingers = 3, direction = "up", action = function()
  hl.dispatch(hl.dsp.global("taris:overviewOpen"))
end })
hl.gesture({ fingers = 3, direction = "down", action = function()
  hl.dispatch(hl.dsp.global("taris:overviewClose"))
end })

-- Window style (Settings > Window style writes window-style.conf: key=value lines)
local style = { gradient = "0", bordertheme = "1", colors = "c4b5fd a855f7 da70d6", solid = "", inactive = "5b3a7a", fade = "1", swipe = "1", roundingon = "1", rounding = "60", bordersize = "1", gapsin = "1", gapsout = "3", columns = "0", floatnew = "0", opacity = "100", blur = "1", blursize = "6", blurpasses = "2", shellblur = "1" }
local function read_conf(path, into)
  local f = io.open(path)
  if not f then return end
  for line in f:lines() do
    local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if k then into[k] = v end
  end
  f:close()
end
read_conf(home .. "/.config/taris/window-style.conf", style)
-- The border in the colour scheme's colours (theme-border.conf, written by the shell on every
-- scheme change) until colours are picked on the Window style page
if style.bordertheme ~= "0" then
  local theme = {}
  read_conf(home .. "/.config/taris/theme-border.conf", theme)
  if theme.colors and theme.inactive then
    style.colors, style.inactive, style.solid = theme.colors, theme.inactive, ""
  end
end

-- Windows (same as the witchers-tweaks rounding, wide-columns and window-mode; border size and
-- gaps are set at the end of this file). New windows tile unless floatnew is on.
if style.roundingon == "1" then
  local percent = tonumber(style.rounding) or 60
  hl.config({ decoration = { rounding = math.floor(math.min(100, percent) * 32 / 100 + 0.5) } })
end
if style.columns == "1" then
  hl.config({ scrolling = { column_width = 0.97 } })
end
if style.floatnew == "1" then
  hl.window_rule({ match = { class = ".*" }, float = true })
end

-- File pickers and other dialogs open like Taris's settings: centred above everything, the
-- rest dimmed, no border or shadow. Every dialog the desktop portal shows (whichever app asked),
-- and the usual Open/Save dialogs apps draw themselves, by title. modules/windowcontrols in the
-- shell matches the same windows (no window buttons on them).
local dialog_class = "^(xdg-desktop-portal-gtk)$"
local dialog_title = "^(Open (File|Files|Folder)|Select (a File|Folder|Directory)|Save (File|As|Image|Image As)|Choose (a )?File)(…|\\.\\.\\.)?$"
for _, match in ipairs({ { class = dialog_class }, { title = dialog_title } }) do
  hl.window_rule({ match = match, float = true, center = true, size = { 900, 600 }, border_size = 0, no_shadow = true, pin = true, dim_around = true })
end

if style.fade == "1" then
  hl.animation({ leaf = "workspaces", enabled = true, speed = 4, bezier = "default", style = "slidefade 20%" })
end

-- 3-finger horizontal swipe between workspaces, tuned like the witchers-tweaks swipe: a short
-- swipe is enough and a quick flick commits. The standalone config doesn't define the gesture, so
-- it's only here (defining it twice in your own config is an error).
if style.swipe == "1" then
  pcall(hl.gesture, { fingers = 3, direction = "horizontal", action = "workspace" })
  hl.config({ gestures = {
    workspace_swipe_distance = 150, -- px for a full swipe (default 300)
    workspace_swipe_cancel_ratio = 0.15, -- commit after 15% instead of 50%
    workspace_swipe_min_speed_to_force = 5, -- a quick flick switches (default 30)
    workspace_swipe_create_new = true, -- past the last workspace makes a new one
    workspace_swipe_forever = true, -- keep going past neighbours in one swipe
  } })
end

-- Keybindings from the witchers-tweaks: CTRL+Q closes the window, SUPER+M minimizes it (into
-- special:minimized, where the dock brings it back) and SUPER+A opens the default agent in a
-- terminal (SUPER+B, the browser, is in the standalone config)
hl.bind("CTRL + Q", hl.dsp.window.close(), { description = "Close window" })
hl.bind("SUPER + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { description = "Minimize window" })
hl.bind("SUPER + A", hl.dsp.global("taris:agent"), { description = "Agent" })

-- Keyboard options from the witchers-tweaks, added to the ones already set: left Ctrl and left
-- Super trade places (the right-hand keys stay), and Caps Lock is a plain Caps Lock: not a compose
-- key, and not cancelled by Shift (shift:both_capslock_cancel made Shift + 1 turn Caps Lock off
-- and type 1 instead of !). Settings > Keyboard & trackpad changes either; what it saves there is
-- loaded after this (hypr-settings.lua) and wins.
pcall(function()
  local options = hl.get_config("input.kb_options")
  options = (type(options) == "string" and options ~= "[[EMPTY]]") and options or ""
  local kept = {}
  for option in options:gmatch("[^,]+") do
    if option ~= "compose:caps" and option ~= "shift:both_capslock_cancel" and option ~= "ctrl:swap_lwin_lctl" then
      kept[#kept + 1] = option
    end
  end
  kept[#kept + 1] = "ctrl:swap_lwin_lctl"
  local new = table.concat(kept, ",")
  if new ~= options then
    hl.config({ input = { kb_options = new } })
  end
end)

-- The border: a three-colour gradient turning around the active window (gradient=1), or one
-- colour (solid, else the first of colors). Hyprland's borderangle loop stops after one turn on
-- 0.56, so a timer turns the gradient (~13 s per turn at ~30 fps); one timer per session, which
-- a reload with the gradient off switches off (it redraws the screen on every turn). The shell
-- changes the colours live (on a scheme change) through taris_set_border, so it needn't
-- reload Hyprland, which would close its settings.
local function hex_list(spec)
  local colors = {}
  for hex in (spec or ""):gmatch("%x%x%x%x%x%x") do colors[#colors + 1] = hex:lower() end
  return colors
end

local function inactive_of(inactive)
  if inactive and inactive:match("^%x%x%x%x%x%x$") then return "rgba(" .. inactive .. "aa)" end
end

if style.gradient == "1" then
  local function gradient_of(spec)
    local colors = hex_list(spec)
    if #colors ~= 3 then return nil end
    local gradient, weights = {}, { 3, 3, 2 }
    for i, hex in ipairs(colors) do
      for _ = 1, weights[i] do gradient[#gradient + 1] = "rgba(" .. hex .. "ee)" end
    end
    return gradient
  end

  _G.taris_border_angle = _G.taris_border_angle or 45
  function _G.taris_set_border(colors, inactive)
    _G.taris_border_gradient = gradient_of(colors) or _G.taris_border_gradient or gradient_of("c4b5fd a855f7 da70d6")
    local col = { active_border = { colors = _G.taris_border_gradient, angle = _G.taris_border_angle } }
    col.inactive_border = inactive_of(inactive)
    hl.config({ general = { col = col } })
  end
  _G.taris_border_gradient = nil
  _G.taris_set_border(style.colors, style.inactive)

  function _G.taris_border_tick()
    _G.taris_border_angle = (_G.taris_border_angle + 360 * 33 / 13330) % 360
    hl.config({ general = { col = { active_border = { colors = _G.taris_border_gradient, angle = _G.taris_border_angle } } } })
  end
  -- (A timer Hyprland has let go of errors: a new one then)
  if not (_G.taris_border_timer and pcall(_G.taris_border_timer.set_enabled, _G.taris_border_timer, true)) then
    _G.taris_border_timer = hl.timer(function()
      if _G.taris_border_tick then _G.taris_border_tick() end
    end, { timeout = 33, type = "repeat" })
  end
else
  _G.taris_border_tick = nil
  if _G.taris_border_timer then pcall(_G.taris_border_timer.set_enabled, _G.taris_border_timer, false) end

  -- colors: the scheme's on a scheme change (its first is the border colour)
  function _G.taris_set_border(colors, inactive)
    local active = hex_list(colors)[1]
    local col = { inactive_border = inactive_of(inactive) }
    if active then col.active_border = "rgba(" .. active .. "ee)" end
    hl.config({ general = { col = col } })
  end
  local solid = style.solid ~= "" and style.solid or style.colors
  _G.taris_set_border(solid, style.inactive)
end

-- Title bars on floating windows (ported from the witchers-tweaks titlebars tweak): the
-- hyprbars plugin (/usr/lib/taris/hyprbars, built for the installed Hyprland by the taris-desktop
-- package's pacman hook) as an invisible strip just above the
-- window's top edge, to drag it by (double-click maximizes). The close, minimize and maximize
-- buttons grow out of the window's top-left corner on hover (modules/windowcontrols). Tiled
-- windows get no strip. A build for another Hyprland version doesn't load (Hyprland checks).
if style.titlebars ~= "0" then
  pcall(function()
    -- (A build an older install.sh made in the home folder comes first where there is one: swapping
    -- a loaded plugin for another copy would make Hyprland unload it in the running session)
    local dir = home .. "/.local/share/taris/hyprbars"
    local f = io.open(dir .. "/built-for")
    if not f then
      dir = "/usr/lib/taris/hyprbars"
      f = io.open(dir .. "/built-for")
    end
    local so = dir .. "/hyprbars.so"
    -- hl.plugin.load only lists the plugin; it has to be listed on every parse, loaded or not,
    -- or Hyprland unloads it, reloads the config and loops
    if f then
      f:close()
      pcall(hl.plugin.load, so)
    end
    if hl.plugin.hyprbars then
      hl.config({ plugin = { hyprbars = {
        bar_height = 14,
        bar_color = "rgba(00000000)",
        bar_title_enabled = false,
        bar_part_of_window = false,
        bar_precedence_over_border = false,
        bar_blur = false,
        on_double_click = "hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"maximized\" })'",
      } } })
      hl.window_rule({ match = { float = false }, ["hyprbars:no_bar"] = true })
      -- Only floating ones (a maximized one would sit below the strip): leaving fullscreen drops
      -- this rule's no_bar and with it the float = false one's, which isn't checked again, so a
      -- tiled window matching this came back from fullscreen 14 px lower
      hl.window_rule({ match = { float = true, fullscreen = true }, ["hyprbars:no_bar"] = true })
      hl.window_rule({ match = { class = dialog_class }, ["hyprbars:no_bar"] = true })
      hl.window_rule({ match = { title = dialog_title }, ["hyprbars:no_bar"] = true })
    end
  end)
end

-- SUPER + T: a tiled window made floating keeps its tiled size, often most of the screen, so it
-- shrinks to at most 65% x 70% of the screen and is centred. (Hyprland sends no event when a
-- window floats, so this is done by the key itself.) Errors go to $XDG_RUNTIME_DIR/taris-hypr.log,
-- as Hyprland's own log is usually off.
local function toggle_float()
  local w = hl.get_active_window()
  if w == nil then return end
  local was_tiled = not w.floating
  local size_w, size_h = w.size[1] or w.size.x, w.size[2] or w.size.y
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  if not was_tiled or (tonumber(w.fullscreen) or 0) ~= 0 or w.monitor == nil then return end

  local m = w.monitor
  local max_w = math.floor(m.width / m.scale * 0.65)
  local max_h = math.floor(m.height / m.scale * 0.7)
  if size_w > max_w or size_h > max_h then
    hl.dispatch(hl.dsp.window.resize({ x = math.min(size_w, max_w), y = math.min(size_h, max_h) }))
  end
  hl.dispatch(hl.dsp.window.center())
end
pcall(hl.unbind, "SUPER + T")
hl.bind("SUPER + T", function()
  local ok, err = pcall(toggle_float)
  if not ok then
    local f = io.open((os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/taris-hypr.log", "a")
    if f then
      f:write(os.date("%H:%M:%S "), "SUPER + T: ", tostring(err), "\n")
      f:close()
    end
  end
end, { description = "Toggle window floating/tiling" })

-- Floating windows resize by dragging their border; tiled windows don't. Follows Hyprland's
-- events, nothing polls.
if style.borderresize ~= "0" then
  local resizing = nil
  local function follow()
    local w = hl.get_active_window()
    local want = w ~= nil and w.floating == true and (tonumber(w.fullscreen) or 0) == 0
    if want ~= resizing then
      resizing = want
      hl.config({ general = { resize_on_border = want } })
    end
  end
  for _, event in ipairs({ "window.active", "window.update_rules", "window.fullscreen", "window.close", "workspace.active" }) do
    hl.on(event, function() pcall(follow) end)
  end
  pcall(follow)
end

-- Settings from the Taris settings app (last, so they win)
pcall(dofile, home .. "/.config/taris/hypr-settings.lua")

-- Border size and gaps from the Window style page, after hypr-settings.lua so they win over the
-- same options set on the old Hyprland page
hl.config({ general = {
  border_size = tonumber(style.bordersize) or 1,
  gaps_in = tonumber(style.gapsin) or 1,
  gaps_out = tonumber(style.gapsout) or 3,
} })

-- Windows' opacity and the blur behind them, from the Window style page, after hypr-settings.lua
-- too. The blur's size and passes are Hyprland's one setting for everything it blurs, the shell's
-- panels included (their layer rule is the shell's: Colours.qml, with shellblur). With window
-- blur off, windows opt out by a rule, so the panels can still be blurred; with both off, nothing
-- is.
local opacity = math.max(0.3, math.min(1, (tonumber(style.opacity) or 100) / 100))
hl.config({ decoration = {
  active_opacity = opacity,
  inactive_opacity = opacity,
  blur = {
    enabled = style.blur ~= "0" or style.shellblur ~= "0",
    size = math.max(1, math.min(20, tonumber(style.blursize) or 6)),
    passes = math.max(1, math.min(4, tonumber(style.blurpasses) or 2)),
  },
} })
if style.blur == "0" then
  hl.window_rule({ name = "taris-no-window-blur", match = { class = ".*" }, no_blur = true })
end
-- Apps whose content would fade with the window stay solid: the browser and the web apps, video,
-- images, PDFs and VS Code. The terminal stays solid as a window too and makes only its own background
-- see-through, at the same opacity (kitty's background_opacity, which the shell writes from this
-- setting: services/WindowStyle.qml), so its text stays sharp.
hl.window_rule({
  name = "taris-solid-apps",
  match = { class = "^(chromium|chrome-.*|mpv|imv|imv-dir|org\\.gnome\\.Evince|evince|code|com\\.microsoft\\.VSCode|kitty)$" },
  opacity = "1.0 override",
})
