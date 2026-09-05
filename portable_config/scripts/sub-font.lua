-- sub-font.lua
-- Source: https://github.com/v-amorim/mpv
--
-- One font choice, whatever the subtitle file is.
--
-- Plain text subtitles (srt, vtt) carry no styling, so mpv renders them with
-- `sub-font`. ASS scripts carry their own styles and ignore it: the only way in
-- is `sub-ass-style-overrides`, which in turn does nothing for plain text. So a
-- single key had to pick the wrong one half the time.
--
-- This mirrors `sub-font` into a FontName override, leaving any other override
-- (colours, bold) alone, so setting `sub-font` is enough for both.
--
-- ASS styling only gives way when `sub-ass-override` is `yes` or higher.
--
-- To let an ASS script use the font it asks for again:
--   script-message-to sub_font use-file-font

local mp = require("mp")

local function set_font_override(font)
	local kept = {}
	for _, entry in ipairs(mp.get_property_native("sub-ass-style-overrides") or {}) do
		if not entry:lower():match("^fontname=") then
			kept[#kept + 1] = entry
		end
	end
	if font and font ~= "" then
		kept[#kept + 1] = "FontName=" .. font
	end
	mp.set_property_native("sub-ass-style-overrides", kept)
end

-- The observer reports the current value the moment it is registered. Mirroring
-- that one would force the configured font onto every ASS script before the user
-- asks for anything, so the first report only primes the mirror.
local armed = false

mp.observe_property("sub-font", "string", function(_, font)
	if not armed then
		armed = true
		return
	end
	set_font_override(font)
end)

-- Only the override goes: `sub-font` still styles the plain text subtitles that
-- name no font of their own, and picking a font again re-arms the mirror.
mp.register_script_message("use-file-font", function()
	set_font_override(nil)
	mp.osd_message("Subtitle font: as the file asks")
end)
