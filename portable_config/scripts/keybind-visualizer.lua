-- keybind-visualizer.lua
-- Source: https://github.com/v-amorim/mpv
--
-- An interactive on-screen keyboard for mpv. Toggle it, then move the mouse
-- over any key to see its bindings.
--
-- Bindings are read live from mpv's "input-bindings" property, so it reflects
-- whatever the user has in input.conf (plus builtin defaults).
--
-- The drawn physical layouts live in an external JSON data file (mpv cannot
-- auto-detect the OS keyboard layout). Pick one, or add your own, via:
--   script-opts/keybind-visualizer.conf
--     layout=abnt2                                  (key in the JSON "layouts")
--     layouts_file=keybind-visualizer-layouts.json  (searched in mpv config dir)
--
-- Activate with:  script-binding keybind-visualizer
-- Close with ESC (or toggle again).

local mp = require("mp")
local utils = require("mp.utils")

local options = { layout = "abnt2", layouts_file = "script-opts/keybind-visualizer-layouts.json" }
require("mp.options").read_options(options, "keybind-visualizer")

----------------------------------------------------------------------
-- Load layout data from JSON. Each key entry: { id, label, mpv?, x, y, w?, h? }
-- (units; rendering scales to screen). A layout has `center` + `bottom`; the
-- shared `frow`/`nav`/`numpad` clusters are reused by every layout.
----------------------------------------------------------------------
local load_error = nil

local function load_layout_data()
	-- try the configured path, then its basename at the config root, so the
	-- JSON can live in a subfolder (script-opts/) or the config root.
	local path = mp.find_config_file(options.layouts_file)
	if not path then
		local base = options.layouts_file:match("([^/\\]+)$")
		if base then
			path = mp.find_config_file(base)
		end
	end
	if not path then
		return nil, "layouts file not found: " .. options.layouts_file
	end
	local f = io.open(path, "r")
	if not f then
		return nil, "cannot open " .. path
	end
	local content = f:read("*all")
	f:close()
	local data, err = utils.parse_json(content or "")
	if not data then
		return nil, "JSON parse error in " .. path .. ": " .. tostring(err)
	end
	if type(data.shared) ~= "table" or type(data.layouts) ~= "table" then
		return nil, "layouts file missing 'shared'/'layouts' keys"
	end
	return data
end

-- flow one row left-to-right: x is summed from widths (default 1); {gap=n}
-- advances x without emitting a key; y comes from the row.
local function flow_row(row, out)
	local x = row.x or 0
	local y = row.y or 0
	for _, cell in ipairs(row.keys or {}) do
		if cell.gap then
			x = x + cell.gap
		else
			out[#out + 1] = {
				id = cell.id,
				label = cell.label,
				mpv = cell.mpv,
				w = cell.w,
				h = cell.h,
				x = x,
				y = y,
			}
			x = x + (cell.w or 1)
		end
	end
end

local function assemble(data, name)
	local L = data.layouts[name] or data.layouts.abnt2
	if not L then
		return {}
	end
	local keys = {}
	for _, row in ipairs((data.shared and data.shared.rows) or {}) do
		flow_row(row, keys)
	end
	for _, row in ipairs(L.rows or {}) do
		flow_row(row, keys)
	end
	return keys
end

local KEYS = {}
local GRID_W, GRID_H = 1, 1
local ID2KEY = {}
local layout_data = nil
local layout_names = {}
local layout_name = (options.layout or "abnt2"):lower()

-- Mouse cluster, drawn beside the keyboard. Coordinates are relative to the
-- mouse origin (placed just right of the keyboard); units match the keys.
local MOUSE_BODY_REL = { x = 0, y = 0.4, w = 4.3, h = 5.8 }
local MOUSE_REL = {
	{ id = "MBTN_LEFT", label = "L", mpv = "MBTN_LEFT", x = 0.2, y = 0.65, w = 1.7, h = 2.0 },
	{ id = "WHEEL_UP", label = "▲", mpv = "WHEEL_UP", x = 1.95, y = 0.65, w = 0.5, h = 0.75 },
	{ id = "MBTN_MID", label = "M", mpv = "MBTN_MID", x = 1.95, y = 1.43, w = 0.5, h = 0.45 },
	{ id = "WHEEL_DOWN", label = "▼", mpv = "WHEEL_DOWN", x = 1.95, y = 1.9, w = 0.5, h = 0.75 },
	{ id = "MBTN_RIGHT", label = "R", mpv = "MBTN_RIGHT", x = 2.5, y = 0.65, w = 1.7, h = 2.0 },
	{ id = "MBTN_FORWARD", label = "X2", mpv = "MBTN_FORWARD", x = -0.5, y = 1.2, w = 0.55, h = 0.7 },
	{ id = "MBTN_BACK", label = "X1", mpv = "MBTN_BACK", x = -0.5, y = 2.0, w = 0.55, h = 0.7 },
}
local MOUSE_NAMES = {
	MBTN_LEFT = "Left Click",
	MBTN_RIGHT = "Right Click",
	MBTN_MID = "Middle / Wheel Click",
	WHEEL_UP = "Wheel Up",
	WHEEL_DOWN = "Wheel Down",
	MBTN_BACK = "Back",
	MBTN_FORWARD = "Forward",
}
local mouse_body = nil -- { x, y, w, h } in grid units, set by rebuild_keys

-- (re)build KEYS, grid extent and id index for the current layout_name
local function rebuild_keys()
	KEYS = assemble(layout_data, layout_name)
	-- place the mouse cluster just to the right of the widest keyboard column
	local kbw = 0
	for _, k in ipairs(KEYS) do
		local ex = k.x + (k.w or 1)
		if ex > kbw then
			kbw = ex
		end
	end
	local mx0 = kbw + 0.7
	for _, m in ipairs(MOUSE_REL) do
		KEYS[#KEYS + 1] =
			{ id = m.id, label = m.label, mpv = m.mpv, x = mx0 + m.x, y = m.y, w = m.w, h = m.h, mouse = true }
	end
	mouse_body = { x = mx0 + MOUSE_BODY_REL.x, y = MOUSE_BODY_REL.y, w = MOUSE_BODY_REL.w, h = MOUSE_BODY_REL.h }

	GRID_W, GRID_H = 1, 1
	for _, k in ipairs(KEYS) do
		local ex = k.x + (k.w or 1)
		local ey = k.y + (k.h or 1)
		if ex > GRID_W then
			GRID_W = ex
		end
		if ey > GRID_H then
			GRID_H = ey
		end
	end
	local mex, mey = mouse_body.x + mouse_body.w, mouse_body.y + mouse_body.h
	if mex > GRID_W then
		GRID_W = mex
	end
	if mey > GRID_H then
		GRID_H = mey
	end

	ID2KEY = {}
	for _, k in ipairs(KEYS) do
		ID2KEY[k.id] = k
		if k.mpv then
			k.mpv_lc = k.mpv:lower()
		end
	end
end

do
	local data, err = load_layout_data()
	if not data then
		load_error = err
		mp.msg.error(err)
	else
		layout_data = data
		for name in pairs(data.layouts) do
			layout_names[#layout_names + 1] = name
		end
		table.sort(layout_names)
		if not data.layouts[layout_name] then
			mp.msg.warn("unknown layout '" .. tostring(options.layout) .. "', falling back")
			layout_name = data.layouts.abnt2 and "abnt2" or layout_names[1] or "abnt2"
		end
		rebuild_keys()
	end
end

----------------------------------------------------------------------
-- Colors: Moonlight theme, written as normal #RRGGBB hex.
----------------------------------------------------------------------
-- ASS wants colors in &HBBGGRR& byte order, so to_ass() reverses the byte
-- pairs once at load time; the rest of the script reads ready-to-use values.
local function to_ass(rgb)
	return rgb:sub(5, 6) .. rgb:sub(3, 4) .. rgb:sub(1, 2)
end

local C = {}
for name, rgb in pairs({
	dim = "0d0e17", -- #0d0e17  full-screen dim behind the keyboard
	key_bg = "191726", -- #191726  unbound key fill
	key_brd = "2d3654", -- #2d3654  unbound key border
	bind_bg = "1f2335", -- #1f2335  bound key fill
	bind_brd = "3c466f", -- #3c466f  bound key border
	hover_bg = "3c466f", -- #3c466f  hovered key fill
	hover_brd = "7386d0", -- #7386d0  hovered key border
	text = "f8eaf8", -- #f8eaf8  key labels + info panel text
	text_dim = "aea4bf", -- #aea4bf  unbound key labels + "No bindings" text
	panel_bg = "191726", -- #191726  info panel background
	panel_brd = "3c466f", -- #3c466f  info panel border
	accent = "7386d0", -- #7386d0  binding combos + layout button + cursor dot
	header = "ced9ff", -- #ced9ff  info panel title (key name)
	sep = "6e7681", -- #6e7681  separator line between bindings
}) do
	C[name] = to_ass(rgb)
end

----------------------------------------------------------------------
-- State
----------------------------------------------------------------------
local overlay = nil
local active = false
local geom = nil
local hovered = nil
local saved_autohide = nil
local mouse_x, mouse_y = nil, nil
local button_rect = nil -- clickable layout-switch button { x, y, w, h }
local BK = {} -- lowercased base key -> sorted list of binding entries

----------------------------------------------------------------------
-- Read bindings from the input-bindings property
----------------------------------------------------------------------
local MODS = { ctrl = true, shift = true, alt = true, meta = true }

-- split "Ctrl+Shift+x" into modifier flags + base key (case-insensitive mods)
local function parse_combo(key)
	local ctrl, shift, alt, meta = false, false, false, false
	local rest = key or ""
	while true do
		local tok, after = rest:match("^(%a+)%+(.+)$")
		if tok and MODS[tok:lower()] then
			local t = tok:lower()
			if t == "ctrl" then
				ctrl = true
			elseif t == "shift" then
				shift = true
			elseif t == "alt" then
				alt = true
			elseif t == "meta" then
				meta = true
			end
			rest = after
		else
			break
		end
	end
	if rest:match("^[A-Z]$") then
		shift = true
		rest = rest:lower()
	end
	return ctrl, shift, alt, meta, rest
end

local function mods_key(c, s, a, m)
	return (c and "c" or "") .. (s and "s" or "") .. (a and "a" or "") .. (m and "m" or "")
end
local function mods_label(c, s, a, m)
	return (c and "Ctrl+" or "") .. (s and "Shift+" or "") .. (a and "Alt+" or "") .. (m and "Win+" or "")
end

local function build_bindings()
	BK = {}
	local list = mp.get_property_native("input-bindings") or {}
	-- keep the highest-priority binding for each (base, modifiers) combo
	local best = {}
	for _, e in ipairs(list) do
		local section = e.section or "default"
		if section == "default" then
			local cmd = (e.cmd or ""):gsub("^%s+", ""):gsub("%s+$", "")
			if cmd ~= "" and cmd:lower() ~= "ignore" then
				local c, s, a, m, base = parse_combo(e.key or "")
				if base ~= "" then
					local bk = base:lower()
					local mk = mods_key(c, s, a, m)
					local uid = bk .. "|" .. mk
					local pr = e.priority or 0
					local prev = best[uid]
					if (not prev) or pr >= prev.priority then
						best[uid] = {
							priority = pr,
							base = bk,
							c = c,
							s = s,
							a = a,
							m = m,
							label = mods_label(c, s, a, m),
							cmd = cmd,
							comment = e.comment,
						}
					end
				end
			end
		end
	end
	for _, b in pairs(best) do
		BK[b.base] = BK[b.base] or {}
		table.insert(BK[b.base], b)
	end
	for _, lst in pairs(BK) do
		table.sort(lst, function(x, y)
			local nx = (x.c and 1 or 0) + (x.s and 1 or 0) + (x.a and 1 or 0) + (x.m and 1 or 0)
			local ny = (y.c and 1 or 0) + (y.s and 1 or 0) + (y.a and 1 or 0) + (y.m and 1 or 0)
			if nx ~= ny then
				return nx < ny
			end
			return x.label < y.label
		end)
	end
end

local function bindings_for(id)
	local k = ID2KEY[id]
	if not k or not k.mpv_lc then
		return nil
	end
	return BK[k.mpv_lc]
end

local function has_bindings(id)
	local lst = bindings_for(id)
	return lst ~= nil and #lst > 0
end

local function binding_desc(b)
	local t = b.comment
	if t and t ~= "" then
		t = t:gsub("^#!%s*", ""):gsub("^#%s*", "")
	end
	if not t or t == "" then
		t = b.cmd
	end
	t = t:gsub("%s+", " ")
	return t
end

-- combo labels carry multi-byte glyphs (arrows), so padding needs characters, not bytes
local function ulen(s)
	local _, n = s:gsub("[^\128-\191]", "")
	return n
end

-- word-wrap a string to a max width (in characters), hard-breaking words that
-- are longer than the width; returns a list of lines.
local function wrap_text(s, width)
	if width < 4 then
		width = 4
	end
	local words = {}
	for w in s:gmatch("%S+") do
		while #w > width do
			words[#words + 1] = w:sub(1, width)
			w = w:sub(width + 1)
		end
		words[#words + 1] = w
	end
	local lines, line = {}, ""
	for _, w in ipairs(words) do
		if line == "" then
			line = w
		elseif #line + 1 + #w <= width then
			line = line .. " " .. w
		else
			lines[#lines + 1] = line
			line = w
		end
	end
	if line ~= "" then
		lines[#lines + 1] = line
	end
	if #lines == 0 then
		lines[1] = ""
	end
	return lines
end

-- human readable key name for the info panel header / combos
local function key_name(id, label)
	if MOUSE_NAMES[id] then
		return MOUSE_NAMES[id]
	end
	local s = id:match("^Key(.+)$")
	if s then
		return s
	end
	s = id:match("^Digit(.+)$")
	if s then
		return s
	end
	s = id:match("^Numpad(.+)$")
	if s then
		return "KP " .. s
	end
	return label
end

----------------------------------------------------------------------
-- ASS helpers
----------------------------------------------------------------------
local function round(v)
	return math.floor(v + 0.5)
end

local function rect_draw(w, h)
	return string.format("m 0 0 l %d 0 l %d %d l 0 %d", w, w, h, h)
end

-- rounded rectangle path (corners approximated with bezier control at corner)
local function rrect_draw(w, h, r)
	if r * 2 > w then
		r = w / 2
	end
	if r * 2 > h then
		r = h / 2
	end
	local wr, hr = w - r, h - r
	return string.format(
		"m %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d l %d %d b %d %d %d %d %d %d",
		r,
		0,
		wr,
		0,
		w,
		0,
		w,
		0,
		w,
		r,
		w,
		hr,
		w,
		h,
		w,
		h,
		wr,
		h,
		r,
		h,
		0,
		h,
		0,
		h,
		0,
		hr,
		0,
		r,
		0,
		0,
		0,
		0,
		r,
		0
	)
end

local function esc(s)
	s = s:gsub("\\", "\\\xE2\x81\xA0")
	s = s:gsub("{", "\\{"):gsub("}", "\\}")
	return s
end

----------------------------------------------------------------------
-- Geometry
----------------------------------------------------------------------
local function compute_geom()
	-- osd-dimensions is the coordinate space ASS overlays render in and that
	-- mouse-pos is reported in, so layout + hit-testing stay aligned in
	-- fullscreen / HiDPI (get_osd_size can differ).
	local dim = mp.get_property_native("osd-dimensions")
	if not dim or not dim.w or dim.w == 0 then
		return nil
	end
	local w, h = dim.w, dim.h
	-- the panel needs room for the busiest key (6 bindings plus separators), so it
	-- gets the larger share of the vertical stack and the keyboard shrinks to suit
	local panel_units = 6
	local header_units = 0.9
	local stack = header_units + 0.3 + GRID_H + 0.6 + panel_units
	local ku = math.min((w * 0.96) / GRID_W, (h * 0.94) / stack)
	local kbd_w = GRID_W * ku
	local kbd_h = GRID_H * ku
	local header_h = header_units * ku
	local ox = (w - kbd_w) / 2
	-- top-anchor the keyboard so the info panel can grow downward to fit every
	-- binding (no "+N more"); keep a small centering bias when there is slack.
	local nominal = header_h + ku * 0.3 + kbd_h + ku * 0.6 + panel_units * ku
	local top = math.max(ku * 0.4, math.min((h - nominal) / 2, ku * 1.2))
	local oy = top + header_h + ku * 0.3
	local panel_y = oy + kbd_h + ku * 0.6
	return {
		sw = w,
		sh = h,
		ku = ku,
		ox = ox,
		oy = oy,
		gap = math.max(2, ku * 0.07),
		kbd_h = kbd_h,
		panel_y = panel_y,
		panel_max_h = math.max(ku * 1.5, h - panel_y - ku * 0.4),
		header_y = top,
		header_h = header_h,
	}
end

local function key_rect(k)
	local g = geom
	local px = g.ox + k.x * g.ku
	local py = g.oy + k.y * g.ku
	local pw = (k.w or 1) * g.ku - g.gap
	local ph = (k.h or 1) * g.ku - g.gap
	return px, py, pw, ph
end

local function key_at(mx, my)
	if not geom then
		return nil
	end
	for _, k in ipairs(KEYS) do
		local px, py, pw, ph = key_rect(k)
		if mx >= px and mx <= px + pw and my >= py and my <= py + ph then
			return k.id
		end
	end
	return nil
end

----------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------
local function build_info_lines(id)
	local g = geom
	local k = ID2KEY[id]
	local name = key_name(id, k and k.label or id)

	-- base font for the panel; every line sets \fs explicitly so the smaller
	-- separator font does not leak into the lines that follow it (\N keeps
	-- inline overrides within one ASS event).
	local info_fs = math.max(1, round(g.ku * 0.3))
	local sep_fs = math.max(1, round(info_fs * 0.55))
	local line_h = info_fs * 1.2 -- rendered height of a normal line
	local sep_h = sep_fs * 1.2 -- rendered height of a separator line

	-- returns lines plus the precise total height (separators are shorter, so
	-- a uniform per-line height would make the panel box too tall)
	local lines = {}
	local total_h = 0
	lines[#lines + 1] = string.format("{\\fs%d\\b1\\1c&H%s&}%s{\\b0\\1c&H%s&}", info_fs, C.header, esc(name), C.text)
	total_h = total_h + line_h
	local lst = bindings_for(id)
	if not lst or #lst == 0 then
		lines[#lines + 1] = string.format("{\\fs%d\\1c&H%s&}No bindings", info_fs, C.text_dim)
		return lines, total_h + line_h
	end

	-- how many physical lines fit in the panel, and chars per line by width
	local max_lines = math.max(3, math.floor((g.panel_max_h - g.ku * 0.5) / line_h))
	local inner_px = GRID_W * g.ku - g.ku * 0.9
	local max_chars = math.max(20, math.floor(inner_px / (info_fs * 0.6)))

	-- thin separator (smaller font) between bindings
	local sep =
		string.format("{\\fs%d\\1c&H%s&}%s", sep_fs, C.sep, string.rep("\xE2\x94\x80", math.floor(max_chars * 0.98)))

	-- every description starts at one column, so the combo pads out to the widest
	local div = "\xE2\x94\x82"
	local combo_w = 0
	for _, b in ipairs(lst) do
		combo_w = math.max(combo_w, ulen(b.label .. name))
	end
	local indent = combo_w + 3 -- pad + space + divider + space

	local budget = max_lines - 1 -- title already used one line
	local shown = 0
	for i, b in ipairs(lst) do
		local combo = b.label .. name
		local wrapped = wrap_text(binding_desc(b), math.max(8, max_chars - indent))
		local need = #wrapped + ((i > 1) and 1 or 0) -- +1 for the separator row
		local reserve = (i == #lst) and 0 or 1
		if budget - need < reserve then
			lines[#lines + 1] = string.format("{\\fs%d\\1c&H%s&}... (+%d more)", info_fs, C.text_dim, #lst - shown)
			total_h = total_h + line_h
			break
		end
		if i > 1 then
			lines[#lines + 1] = sep
			total_h = total_h + sep_h
		end
		-- first physical line: accent combo, padded, then the divider and first chunk
		lines[#lines + 1] = string.format(
			"{\\fs%d\\1c&H%s&}%s%s{\\1c&H%s&}\\h%s\\h{\\1c&H%s&}%s",
			info_fs,
			C.accent,
			esc(combo),
			string.rep("\\h", combo_w - ulen(combo)),
			C.sep,
			div,
			C.text,
			esc(wrapped[1])
		)
		-- continuation lines: hanging indent under the description
		for j = 2, #wrapped do
			lines[#lines + 1] =
				string.format("{\\fs%d\\1c&H%s&}%s%s", info_fs, C.text, string.rep("\\h", indent), esc(wrapped[j]))
		end
		total_h = total_h + #wrapped * line_h
		budget = budget - need
		shown = shown + 1
	end
	return lines, total_h
end

local function render()
	if not active or not overlay then
		return
	end
	geom = compute_geom()
	if not geom then
		return
	end
	local g = geom

	overlay.res_x = g.sw
	overlay.res_y = g.sh

	-- error state: no usable layout data
	if load_error or #KEYS == 0 then
		local msg = load_error or "no keys in layout '" .. layout_name .. "'"
		overlay.data = string.format(
			"{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H70&\\p1}%s{\\p0}\\n"
				.. "{\\an5\\pos(%d,%d)\\fs%d\\bord2\\shad0\\3c&H000000&\\1c&H%s&}keybind-visualizer: %s",
			C.dim,
			rect_draw(round(g.sw), round(g.sh)),
			round(g.sw / 2),
			round(g.sh / 2),
			round(g.sh * 0.03),
			C.text,
			esc(msg)
		)
		overlay:update()
		return
	end

	local a = {}

	-- full screen dim
	a[#a + 1] = string.format(
		"{\\an7\\pos(0,0)\\bord0\\shad0\\1c&H%s&\\1a&H70&\\p1}%s{\\p0}",
		C.dim,
		rect_draw(round(g.sw), round(g.sh))
	)

	-- mouse body (drawn behind the mouse buttons, which live in KEYS)
	if mouse_body then
		local bx = g.ox + mouse_body.x * g.ku
		local by = g.oy + mouse_body.y * g.ku
		local bw = mouse_body.w * g.ku
		local bh = mouse_body.h * g.ku
		a[#a + 1] = string.format(
			"{\\an7\\pos(%d,%d)\\bord2\\shad0\\3c&H%s&\\1c&H%s&\\1a&H10&\\p1}%s{\\p0}",
			round(bx),
			round(by),
			C.key_brd,
			C.key_bg,
			rrect_draw(round(bw), round(bh), round(g.ku * 0.55))
		)
		a[#a + 1] = string.format(
			"{\\an5\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}MOUSE",
			round(bx + bw / 2),
			round(by + bh * 0.8),
			round(g.ku * 0.3),
			C.text_dim
		)
	end

	-- keys
	for _, k in ipairs(KEYS) do
		local px, py, pw, ph = key_rect(k)
		local bg, brd
		if k.id == hovered then
			bg, brd = C.hover_bg, C.hover_brd
		elseif has_bindings(k.id) then
			bg, brd = C.bind_bg, C.bind_brd
		else
			bg, brd = C.key_bg, C.key_brd
		end
		a[#a + 1] = string.format(
			"{\\an7\\pos(%d,%d)\\bord2\\shad0\\3c&H%s&\\1c&H%s&\\1a&H08&\\p1}%s{\\p0}",
			round(px),
			round(py),
			brd,
			bg,
			rect_draw(round(pw), round(ph))
		)
	end

	-- labels
	local fs = round(g.ku * 0.34)
	for _, k in ipairs(KEYS) do
		local px, py, pw, ph = key_rect(k)
		local col = has_bindings(k.id) and C.text or C.text_dim
		if k.id == hovered then
			col = C.text
		end
		a[#a + 1] = string.format(
			"{\\an5\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}%s",
			round(px + pw / 2),
			round(py + ph / 2),
			fs,
			col,
			esc(k.label)
		)
	end

	-- info panel: build the lines first, then size the background to fit them
	local info_fs = round(g.ku * 0.3)
	local panel_lines, content_h
	if hovered then
		panel_lines, content_h = build_info_lines(hovered)
	else
		panel_lines = {
			string.format(
				"{\\fs%d\\1c&H%s&}Move the mouse over a key to see its bindings.   {\\1c&H%s&}ESC{\\1c&H%s&} to close.",
				info_fs,
				C.text,
				C.accent,
				C.text
			),
		}
		content_h = info_fs * 1.2
	end
	local pad_top, pad_bot = g.ku * 0.25, g.ku * 0.25
	local panel_h = math.max(g.ku, math.min(g.panel_max_h, pad_top + content_h + pad_bot))

	a[#a + 1] = string.format(
		"{\\an7\\pos(%d,%d)\\bord2\\shad0\\3c&H%s&\\1c&H%s&\\1a&H10&\\p1}%s{\\p0}",
		round(g.ox),
		round(g.panel_y),
		C.panel_brd,
		C.panel_bg,
		rect_draw(round(GRID_W * g.ku), round(panel_h))
	)
	a[#a + 1] = string.format(
		"{\\an7\\pos(%d,%d)\\bord0\\shad0\\q2}%s",
		round(g.ox + g.ku * 0.4),
		round(g.panel_y + pad_top),
		table.concat(panel_lines, "\\N")
	)

	-- clickable layout-switch button (header band, above the keyboard)
	local lay_label = "LAYOUT: " .. layout_name:upper()
	if #layout_names > 1 then
		lay_label = lay_label .. "   (click to change)"
	end
	local bfs = round(g.header_h * 0.48)
	local bx, by, bh = g.ox, g.header_y, g.header_h
	local bw = math.max(g.ku * 4, #lay_label * bfs * 0.5 + g.ku * 0.6)
	button_rect = { x = bx, y = by, w = bw, h = bh }
	local over_btn = mouse_x ~= nil and mouse_x >= bx and mouse_x <= bx + bw and mouse_y >= by and mouse_y <= by + bh
	a[#a + 1] = string.format(
		"{\\an7\\pos(%d,%d)\\bord2\\shad0\\3c&H%s&\\1c&H%s&\\1a&H08&\\p1}%s{\\p0}",
		round(bx),
		round(by),
		over_btn and C.hover_brd or C.bind_brd,
		over_btn and C.hover_bg or C.bind_bg,
		rect_draw(round(bw), round(bh))
	)
	a[#a + 1] = string.format(
		"{\\an4\\pos(%d,%d)\\fs%d\\bord0\\shad0\\1c&H%s&}%s",
		round(bx + g.ku * 0.3),
		round(by + bh / 2),
		bfs,
		over_btn and C.accent or C.text,
		esc(lay_label)
	)

	-- cursor dot (sits exactly under the real pointer when spaces are aligned)
	if mouse_x then
		local r = math.max(3, round(g.ku * 0.06))
		a[#a + 1] = string.format(
			"{\\an7\\pos(%d,%d)\\bord1\\3c&H000000&\\shad0\\1c&H%s&\\1a&H20&\\p1}%s{\\p0}",
			round(mouse_x - r),
			round(mouse_y - r),
			C.accent,
			rect_draw(r * 2, r * 2)
		)
	end

	overlay.data = table.concat(a, "\n")
	overlay:update()
end

----------------------------------------------------------------------
-- Mouse / events
----------------------------------------------------------------------
local function on_mouse(_, val)
	if not active then
		return
	end
	local mx, my
	if type(val) == "table" then
		mx, my = val.x, val.y
	else
		local pos = mp.get_property_native("mouse-pos")
		if pos then
			mx, my = pos.x, pos.y
		end
	end
	if not mx then
		return
	end
	mouse_x, mouse_y = mx, my
	hovered = key_at(mx, my)
	render()
end

local function on_resize()
	if active then
		render()
	end
end

-- advance to the next layout in the JSON (sorted) and redraw
local function cycle_layout()
	if load_error or #layout_names < 2 then
		return
	end
	local idx = 1
	for i, n in ipairs(layout_names) do
		if n == layout_name then
			idx = i
			break
		end
	end
	layout_name = layout_names[idx % #layout_names + 1]
	rebuild_keys()
	hovered = nil
	render()
end

local function on_click()
	if not active or not button_rect then
		return
	end
	local pos = mp.get_property_native("mouse-pos")
	if not pos then
		return
	end
	local r = button_rect
	if pos.x >= r.x and pos.x <= r.x + r.w and pos.y >= r.y and pos.y <= r.y + r.h then
		cycle_layout()
	end
end

----------------------------------------------------------------------
-- Toggle
----------------------------------------------------------------------
local function close()
	if not active then
		return
	end
	active = false
	hovered = nil
	mp.unobserve_property(on_mouse)
	mp.unobserve_property(on_resize)
	mp.remove_key_binding("keybind-visualizer-esc")
	mp.remove_key_binding("keybind-visualizer-click")
	if saved_autohide ~= nil then
		mp.set_property("cursor-autohide", saved_autohide)
		saved_autohide = nil
	end
	if overlay then
		overlay:remove()
	end
end

local function open()
	if active then
		return
	end
	if not overlay then
		overlay = mp.create_osd_overlay("ass-events")
	end
	build_bindings()
	active = true
	hovered = nil
	mouse_x, mouse_y = nil, nil
	local pos = mp.get_property_native("mouse-pos")
	if pos then
		mouse_x, mouse_y = pos.x, pos.y
	end
	saved_autohide = mp.get_property("cursor-autohide")
	mp.set_property("cursor-autohide", "no")
	mp.observe_property("mouse-pos", "native", on_mouse)
	mp.observe_property("osd-dimensions", "native", on_resize)
	mp.add_forced_key_binding("ESC", "keybind-visualizer-esc", close)
	mp.add_forced_key_binding("MBTN_LEFT", "keybind-visualizer-click", on_click)
	render()
end

local function toggle()
	if active then
		close()
	else
		open()
	end
end

mp.add_key_binding(nil, "keybind-visualizer", toggle)
mp.register_event("shutdown", function()
	if overlay then
		overlay:remove()
	end
end)
