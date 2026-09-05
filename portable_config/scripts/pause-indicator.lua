--[[
    pause-indicator.lua - mpv script to restart the player

    Prints a pause icon in the middle of the screen when mpv is paused
	Modified version of the code available at: https://github.com/CogentRedTester/mpv-scripts

    Source: https://github.com/v-amorim/self-development/blob/main/config/mpv64/portable_config/scripts/restart-mpv.lua
]]
--

local mp = require("mp")
local screenx, screeny, aspect = mp.get_osd_size()

mp.observe_property("pause", "bool", function(_, paused)
	mp.add_timeout(0.1, function()
		if paused then
			mp.set_osd_ass(screenx, screeny, "{\\an9}⏸")
		else
			mp.set_osd_ass(screenx, screeny, "")
		end
	end)
end)
