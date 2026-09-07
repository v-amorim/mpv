--[[
    watched-folder.lua - mpv script to move files to a subfolder upon playing

    This script automatically moves the previously played file to a subfolder named "watched" upon loading a new file.
	Use `F10` key to toggle automatic file moving on/off with an OSD message.

    Source: https://github.com/v-amorim/self-development/blob/main/config/mpv64/portable_config/scripts/watched-folder.lua
]]
--

local utils = require("mp.utils")

local subfolder = "watched"
local previousFilePath = nil
local fileMovingEnabled = true

function movePreviousFile()
	if fileMovingEnabled and previousFilePath then
		local thisFolder, _ = utils.split_path(previousFilePath)
		local destFolder = utils.join_path(thisFolder, subfolder)

		local args = { "cmd.exe", "/C", "md", destFolder, "&", "move", previousFilePath, destFolder }
		utils.subprocess({ args = args, playback_only = false })
		previousFilePath = nil
	end
end

function recordPreviousFile()
	previousFilePath = mp.get_property("path")
end

local function pending()
	if not fileMovingEnabled then
		return "the files you finish stay where they are"
	end
	if not previousFilePath then
		return "the file you finish moves into the " .. subfolder .. " folder when the next one starts"
	end
	local _, name = utils.split_path(previousFilePath)
	return name .. " moves into the " .. subfolder .. " folder when the next file starts"
end

function toggleFileMoving()
	fileMovingEnabled = not fileMovingEnabled
	local state = fileMovingEnabled and "yes" or "no"
	mp.commandv("script-message-to", "osd_theme", "say", "File moving", state, pending())
end

mp.register_event("start-file", movePreviousFile)
mp.register_event("file-loaded", recordPreviousFile)

mp.add_key_binding("", "watched-folder", toggleFileMoving)
