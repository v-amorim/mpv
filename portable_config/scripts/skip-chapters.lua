require("mp.options")
local opt = {
	-- Simplified patterns (all lowercase)
	patterns = {
		-- Opening variants
		"^op$",
		"^opening",
		-- "intro",
		-- Ending variants
		"^ed$",
		"^ending",
		"credits",
		-- Extra variants
		"preview$",
		"^pv$",
		"yokoku",
	},
}

read_options(opt)

local chapterSkippingEnabled = true

function toggleCheckChapter()
	chapterSkippingEnabled = not chapterSkippingEnabled
	mp.osd_message("Chapter skipping " .. (chapterSkippingEnabled and "enabled" or "disabled"))
end

function check_chapter(_, chapter)
	if not chapterSkippingEnabled or not chapter then
		return
	end

	-- Convert title to lowercase once to simplify matching
	local title = string.lower(chapter)

	for _, p in pairs(opt.patterns) do
		if string.find(title, p) then
			mp.command('show-text "Skipping chapter: ' .. chapter .. '"')
			mp.command("no-osd add chapter 1")
			return
		end
	end
end

mp.observe_property("chapter-metadata/by-key/title", "string", check_chapter)
mp.add_key_binding("", "chapter-skip", toggleCheckChapter)
