-- sub-select-menu.lua
-- Source: https://github.com/v-amorim/moonlight-mpv
--
-- sub-select.lua picks a subtitle track from the rules in sub-select.json and
-- says nothing about it: which rule won, or whether it ran at all. This draws
-- the rules, marks the one that matched, and lets you switch it off.
--
-- The rules and the match come from sub-select.lua over user-data, which is the
-- only place either is known.
--
-- Activate with:  script-binding sub_select_menu/menu

local mp = require("mp")
local utils = require("mp.utils")

local MENU_TYPE = "sub-select-menu"
local script_name = mp.get_script_name()
local MIDDOT = "  \xC2\xB7  "
local is_open = false

-- sub-select spells "match anything" and "match nothing" as language codes
local WORDS = { ["*"] = "any", ["no"] = "none" }

local function langs(value)
	if type(value) ~= "table" then
		value = { value }
	end
	local out = {}
	for _, item in ipairs(value) do
		out[#out + 1] = WORDS[item] or item
	end
	return table.concat(out, ", ")
end

-- a rule that inherits names no audio of its own
local function rule_title(pref)
	local subs = langs(pref.slang) .. " subtitles"
	if pref.alang then
		return langs(pref.alang) .. " audio, " .. subs
	end
	local parent = pref.inherit == "^" and "the rule above" or ("the rule " .. tostring(pref.inherit))
	return parent .. ", " .. subs
end

local function qualifiers(pref)
	local parts = {}
	if pref.whitelist then
		parts[#parts + 1] = "only " .. table.concat(pref.whitelist, ", ")
	end
	if pref.blacklist then
		parts[#parts + 1] = "never " .. table.concat(pref.blacklist, ", ")
	end
	if pref.condition then
		parts[#parts + 1] = "when " .. pref.condition
	end
	return #parts > 0 and table.concat(parts, MIDDOT) or nil
end

local function track_row(matched)
	local track = mp.get_property_native("current-tracks/sub")
	if not track then
		return {
			title = "No subtitle track is showing",
			hint = matched and "the rule below asked for none" or nil,
			selectable = false,
			italic = true,
			muted = true,
		}
	end
	local name = track.lang or "und"
	if track.title then
		name = name .. MIDDOT .. track.title
	end
	return {
		title = name,
		hint = "track " .. track.id,
		selectable = false,
		italic = true,
		muted = true,
	}
end

local function build_items()
	local prefs = mp.get_property_native("user-data/sub-select/prefs") or {}
	local matched = mp.get_property_native("user-data/sub-select/matched")
	local enabled = mp.get_property_native("user-data/sub-select/enabled")
	local items = { track_row(matched) }
	items[1].separator = true

	for index, pref in ipairs(prefs) do
		items[#items + 1] = {
			title = rule_title(pref),
			hint = qualifiers(pref),
			active = matched == index,
			selectable = false,
		}
	end

	if not matched then
		items[#items + 1] = {
			title = enabled and "No rule matched this file" or "Switched off, so no rule ran",
			align = "center",
			selectable = false,
			italic = true,
			muted = true,
		}
	end
	items[#items].separator = true

	items[#items + 1] = {
		title = "Pick a subtitle track automatically",
		icon = enabled and "check_box" or "check_box_outline_blank",
		keep_open = true,
		value = "toggle",
	}
	items[#items + 1] = {
		title = "Run the rules again now",
		icon = "refresh",
		value = "rerun",
	}

	return items
end

local function menu_json()
	return utils.format_json({
		type = MENU_TYPE,
		title = "Automatic subtitles",
		items = build_items(),
		callback = { script_name, "menu-event" },
		on_close = { "script-message-to", script_name, "menu-closed" },
	})
end

mp.register_script_message("menu-event", function(json)
	local event = utils.parse_json(json or "")
	if not event or event.type ~= "activate" then
		return
	end

	if event.value == "toggle" then
		mp.commandv("script-message-to", "sub_select", "sub-select", "toggle")
	elseif event.value == "rerun" then
		mp.commandv("script-message-to", "sub_select", "select-subtitles")
	end

	-- let sub-select finish before reading back what it decided
	mp.add_timeout(0.15, function()
		if is_open then
			mp.commandv("script-message-to", "uosc", "update-menu", menu_json())
		end
	end)
end)

mp.register_script_message("menu-closed", function()
	is_open = false
end)

mp.add_key_binding(nil, "menu", function()
	if is_open then
		mp.commandv("script-message-to", "uosc", "close-menu", MENU_TYPE)
	else
		mp.commandv("script-message-to", "uosc", "open-menu", menu_json())
		is_open = true
	end
end)
