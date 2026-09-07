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
	mp.commandv(
		"script-message-to",
		"osd_theme",
		"say",
		"Chapter skipping",
		chapterSkippingEnabled and "yes" or "no",
		"jumps past chapters named as openings, endings, credits or previews"
	)
end

function check_chapter(_, chapter)
	if not chapterSkippingEnabled or not chapter then
		return
	end

	-- Convert title to lowercase once to simplify matching
	local title = string.lower(chapter)

	for _, p in pairs(opt.patterns) do
		if string.find(title, p) then
			mp.commandv("script-message-to", "osd_theme", "say", "Skipping chapter", chapter, "matched the skip list")
			mp.command("no-osd add chapter 1")
			return
		end
	end
end

mp.observe_property("chapter-metadata/by-key/title", "string", check_chapter)
mp.add_key_binding("", "chapter-skip", toggleCheckChapter)
