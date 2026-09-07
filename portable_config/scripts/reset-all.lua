-- reset-all.lua
-- Source: https://github.com/v-amorim/moonlight-mpv
--
-- Puts playback back to a fresh-start state without reloading the file:
-- zoom, pan, aspect, rotation, panscan, speed, delays, subtitle placement and
-- the color controls all go back to their defaults, and glsl-shaders is cleared.
--
-- Volume and mute are deliberately left alone, so a reset never blasts audio.
--
-- Activate with:  script-binding reset-all

local mp = require("mp")

local DEFAULTS = {
	["video-zoom"] = 0,
	["video-pan-x"] = 0,
	["video-pan-y"] = 0,
	["video-align-x"] = 0,
	["video-align-y"] = 0,
	["video-aspect-override"] = -1,
	["video-rotate"] = 0,
	["panscan"] = 0,
	["speed"] = 1,
	["sub-delay"] = 0,
	["audio-delay"] = 0,
	["sub-scale"] = 1,
	["sub-pos"] = 100,
	["sub-visibility"] = true,
	["contrast"] = 0,
	["brightness"] = 0,
	["gamma"] = 0,
	["saturation"] = 0,
	["hue"] = 0,
}

mp.add_key_binding(nil, "reset-all", function()
	for prop, value in pairs(DEFAULTS) do
		mp.set_property_native(prop, value)
	end
	mp.commandv("change-list", "glsl-shaders", "clr", "")
	mp.osd_message("Reset: zoom | pan | aspect | speed | delays | subs | colors")
end)
