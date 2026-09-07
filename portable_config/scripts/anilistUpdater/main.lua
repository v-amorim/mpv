-- https://github.com/AzuredBlue/mpv-anilist-updater

local utils = require("mp.utils")

local function say(label, state, detail)
	mp.commandv("script-message-to", "osd_theme", "say", label, state or "", detail or "")
end

-- The python side marks these on stdout so the OSD can say what to do next.
local function report(output)
	if output:find("ANILIST_NOT_LINKED", 1, true) then
		say("AniList", "not linked", "copy a token, then press the setup binding")
	elseif output:find("ANILIST_EXPIRED", 1, true) then
		say("AniList", "expired", "copy a fresh token, then press the setup binding")
	else
		local name = output:match("LINKED: (%S+)")
		if name then
			say("AniList", "linked", "as " .. name)
		end
	end
end

function callback(success, result, error)
	if result.status == 0 then
		mp.osd_message("Updated anime correctly.", 2)
	end
	report(result.stdout or "")
end

local function get_python_command()
	local os_name = package.config:sub(1, 1)
	if os_name == "\\" then
		-- Windows
		return "python"
	else
		-- Linux
		return "python3"
	end
end

local python_command = get_python_command()

-- Make sure it doesnt trigger twice in 1 video
local triggered = false

-- Function to check if we've reached 85% of the video
function check_progress()
	if triggered then
		return
	end

	local percent_pos = mp.get_property_number("percent-pos")

	if percent_pos then
		if percent_pos >= 85 then
			update_anilist("update")
			triggered = true
		end
	end
end

-- Function to launch the .py script
function update_anilist(action)
	if action == "launch" then
		mp.osd_message("Launching AniList", 2)
	end
	local script_dir = debug.getinfo(1).source:match("@?(.*/)")
	local directory = mp.get_property("working-directory")
	-- It seems like in Linux working-directory sometimes returns it without a "/" at the end
	local path = ((directory:sub(-1) == "/" or directory:sub(-1) == "\\") and directory or directory .. "/")
		.. mp.get_property("path") -- Absolute path of the file we are playing
	local table = {}
	table.name = "subprocess"
	table.args = { python_command, script_dir .. "anilistUpdater.py", path, action }
	table.capture_stdout = true
	local cmd = mp.command_native_async(table, callback)
end

-- The token goes over stdin rather than argv, which any process list can read.
function link_anilist()
	local token = mp.get_property("clipboard/text")
	if not token or token:match("^%s*$") then
		say("AniList", "no token", "copy the token from the AniList page first")
		return
	end

	local script_dir = debug.getinfo(1).source:match("@?(.*/)")
	mp.command_native_async({
		name = "subprocess",
		args = { python_command, script_dir .. "anilistUpdater.py", "--setup" },
		stdin_data = token,
		capture_stdout = true,
	}, function(success, result, error)
		report(result.stdout or "")
	end)
end

mp.observe_property("percent-pos", "number", check_progress)

-- Reset triggered
mp.register_event("file-loaded", function()
	triggered = false
end)

-- Keybinds, modify as you please
mp.add_key_binding("", "update_anilist", function()
	update_anilist("update")
end)

mp.add_key_binding("", "launch_anilist", function()
	update_anilist("launch")
end)

mp.add_key_binding("", "link_anilist", link_anilist)
