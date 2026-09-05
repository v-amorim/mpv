--[[
    restart-mpv.lua - mpv script to restart the player

    This script is made to restart the mpv instance, meant to refresh any changes made to the configuration file.
	Use `F5` key to restart the player.

    Source: https://github.com/v-amorim/self-development/blob/main/config/mpv64/portable_config/scripts/restart-mpv.lua
]]
--

local utils = require("mp.utils")

local last_file_path = nil

function restart_mpv()
	-- Save the current file path before restarting
	last_file_path = mp.get_property("path")

	mp.command_native({ "quit" })

	local args = {}
	if last_file_path then
		args.args = { "mpv", last_file_path }
	else
		args.args = { "mpv" }
	end

	utils.subprocess_detached(args)
end

mp.add_key_binding("F5", "restart-mpv", restart_mpv)
