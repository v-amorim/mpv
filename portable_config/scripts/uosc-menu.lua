-- uosc-menu.lua
-- Source: https://github.com/v-amorim/mpv
--
-- uosc builds its main menu from the "#!" comments in input.conf, but gives its
-- items no icons and nothing to say about themselves. This reads the same
-- comments, accepts an "@icon" and a "?description" token on any part of the
-- path, and hands uosc the finished menu, so uosc itself stays untouched and
-- upstream updates apply cleanly.
--
-- Icon names are Material Icons Rounded ligatures, the set bundled in
-- fonts/uosc_icons.otf: https://fonts.google.com/icons?icon.style=Rounded
--
--   CTRL+o script-binding uosc/open-file   #! Open File @file_open ?Browse and play
--   g      cycle interpolation             #! Video @movie > Interpolation @animation ?Kills judder
--   #                                      #! Video > ---
--
-- Activate with:  script-binding uosc_menu/menu

local mp = require("mp")
local utils = require("mp.utils")

local MENU_TYPE = "main-menu"
local script_name = mp.get_script_name()
local is_open = false
local items = nil

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "Line Art @brush ?Anime line work" -> "Line Art", "brush", "Anime line work"
local function split_part(part)
	local head, description = part:match("^(.-)%s*%?%s*(.+)$")
	head = head or part
	local title, icon = head:match("^(.-)%s+@([%w_]+)%s*$")
	return trim(title or head), icon, description and trim(description) or nil
end

local TOOLTIP_MAX = 130

-- what an entry does and the command behind it, shown under the menu on hover
local function tooltip_for(description, cmd)
	local text = cmd:gsub("%s+", " ")
	if description then
		text = description .. "  \xC2\xB7  " .. text
	end
	if #text > TOOLTIP_MAX then
		text = text:sub(1, TOOLTIP_MAX - 1) .. "\xE2\x80\xA6"
	end
	return text
end

-- every input.conf line that carries a "#!" menu comment, commented-out ones
-- included: those are menu entries that deliberately have no key
local function read_menu_lines()
	local conf = mp.get_property_native("input-conf")
	if conf == "" then
		conf = "~~/input.conf"
	end
	local path = mp.command_native({ "expand-path", conf })
	local out = {}
	local ok, iterator = pcall(io.lines, path)
	if not ok then
		mp.msg.error("cannot read " .. tostring(path))
		return out
	end
	for line in iterator do
		local key, cmd, comment = line:match("%s*([%S]+)%s+([^#]*)%s*(.-)%s*$")
		local menu_path = comment and comment:match("^#!%s*(.+)$")
		-- "#F2" is a disabled binding, not a menu entry
		if key and menu_path and not (key:sub(1, 1) == "#" and #key > 1) then
			out[#out + 1] = { key = key, cmd = trim(cmd or ""), path = menu_path }
		end
	end
	return out
end

-- Entries that carry a state: a property they flip, a value they select, or a
-- shader they load. They are drawn as a checkbox or a radio button, re-read from
-- mpv every time the menu opens.
local stateful = {}

local function basename(path)
	return (path:lower():match("([^/\\]+)$"))
end

local function as_number(value)
	local w, h = tostring(value):match("^(%d+%.?%d*):(%d+%.?%d*)$")
	if w then
		return tonumber(w) / tonumber(h)
	end
	return tonumber(value)
end

---@return table|nil state to track for this command
local function state_of(cmd)
	local prop = cmd:match("^cycle%s+([%w-_]+)%s*$")
	if prop then
		return { kind = "toggle", prop = prop }
	end
	local shader = cmd:match("^change%-list%s+glsl%-shaders%s+toggle%s+(%S+)")
	if shader then
		return { kind = "shader", file = basename(shader) }
	end
	local filter = cmd:match("^af%s+toggle%s+(.-)%s*;") or cmd:match("^af%s+toggle%s+(.+)$")
	if filter then
		filter = filter:gsub('^"', ""):gsub('"$', "")
		return { kind = "filter", needle = filter:match("%[(.+)%]") or filter }
	end
	local value
	prop, value = cmd:match("^set%s+([%w-_]+)%s+(.+)$")
	if prop then
		value = value:gsub(";%s*$", ""):gsub('^"', ""):gsub('"$', "")
		return { kind = "radio", prop = prop, value = value }
	end
	return nil
end

local function is_on(state)
	if state.kind == "toggle" then
		return mp.get_property_native(state.prop) and true or false
	elseif state.kind == "radio" then
		local current = mp.get_property(state.prop, "")
		if current == state.value then
			return true
		end
		-- numeric properties come back formatted ("-1.000000"), and an aspect ratio
		-- is written as "16:9" but stored as the division
		local a, b = as_number(current), as_number(state.value)
		return a ~= nil and b ~= nil and math.abs(a - b) < 0.0001
	elseif state.kind == "filter" then
		return mp.get_property("af", ""):find(state.needle, 1, true) ~= nil
	end
	for _, loaded in ipairs(mp.get_property_native("glsl-shaders") or {}) do
		if basename(loaded) == state.file then
			return true
		end
	end
	return false
end

local function refresh_state()
	for _, entry in ipairs(stateful) do
		local on = is_on(entry.state)
		entry.item.active = on
		if entry.state.kind == "radio" then
			entry.item.icon = on and "radio_button_checked" or "radio_button_unchecked"
		else
			entry.item.icon = on and "check_box" or "check_box_outline_blank"
		end
	end
end

local function build_items()
	local root = { items = {}, by_cmd = {} }
	local nodes = {}
	stateful = {}

	for _, bind in ipairs(read_menu_lines()) do
		local parts = {}
		for part in bind.path:gmatch("[^>]+") do
			parts[#parts + 1] = part
		end

		local target, id = root, ""
		for index, raw in ipairs(parts) do
			local title, icon, description = split_part(raw)
			if title:sub(1, 3) == "---" then
				-- a separator ends the path: anything after it would build a phantom
				-- submenu next to the real entry
				local last = target.items[#target.items]
				if last then
					last.separator = true
				end
				break
			elseif index < #parts then
				id = id .. ">" .. title
				local node = nodes[id]
				if not node then
					node = { items = {}, by_cmd = {} }
					node.item = { title = title, icon = icon, tooltip = description, items = node.items }
					nodes[id] = node
					target.items[#target.items + 1] = node.item
				else
					node.item.icon = node.item.icon or icon
					node.item.tooltip = node.item.tooltip or description
				end
				target = node
			elseif bind.cmd ~= "" and bind.cmd ~= "ignore" then
				local existing = target.by_cmd[bind.cmd]
				local has_key = bind.key ~= "#"
				if existing and has_key then
					existing.hint = existing.hint and existing.hint .. ", " .. bind.key or bind.key
				elseif not existing then
					local item = {
						title = title,
						icon = icon,
						value = bind.cmd,
						hint = has_key and bind.key or nil,
						tooltip = tooltip_for(description, bind.cmd),
					}
					target.by_cmd[bind.cmd] = item
					target.items[#target.items + 1] = item
					local state = state_of(bind.cmd)
					if state then
						-- flipping a box is rarely the only thing you came to do
						item.keep_open = true
						stateful[#stateful + 1] = { item = item, state = state }
					end
				end
			end
		end
	end

	return root.items
end

local function menu_json(at_cursor)
	return utils.format_json({
		type = MENU_TYPE,
		search_submenus = true,
		items = items,
		anchor_at_cursor = at_cursor or false,
		-- taking the events means uosc stops running commands and stops closing on
		-- activation, both of which this script does below instead
		callback = { script_name, "menu-event" },
		on_close = { "script-message-to", script_name, "menu-closed" },
	})
end

-- `submenu` is a uosc submenu id: the titles along the path joined by " > ".
-- `at_cursor` pins the menu where the pointer is, for a right click on the video;
-- opened from a button or a key it stays centered.
local function open(submenu, at_cursor)
	items = items or build_items()
	if #items == 0 then
		mp.osd_message("No menu entries in input.conf")
		return
	end
	refresh_state()
	local json = menu_json(at_cursor)
	-- an empty submenu id is still a lookup for uosc, so leave the argument off
	if submenu and submenu ~= "" then
		mp.commandv("script-message-to", "uosc", "open-menu", json, submenu)
	else
		mp.commandv("script-message-to", "uosc", "open-menu", json)
	end
	is_open = true
end

mp.register_script_message("menu-closed", function()
	is_open = false
end)

mp.register_script_message("menu-event", function(json)
	local event = utils.parse_json(json or "")
	if not event or event.type ~= "activate" or not event.value then
		return
	end
	mp.command(tostring(event.value))
	if not event.keep_open then
		mp.commandv("script-message-to", "uosc", "close-menu", MENU_TYPE)
		return
	end
	-- let the command land before reading the properties back
	mp.add_timeout(0.05, function()
		refresh_state()
		mp.commandv("script-message-to", "uosc", "update-menu", menu_json())
	end)
end)

mp.register_script_message("show-submenu", function(id)
	open(id)
end)

local function toggle(at_cursor)
	if is_open then
		mp.commandv("script-message-to", "uosc", "close-menu", MENU_TYPE)
	else
		open(nil, at_cursor)
	end
end

mp.add_key_binding(nil, "menu", function()
	toggle(false)
end)

mp.add_key_binding(nil, "menu-at-cursor", function()
	toggle(true)
end)
