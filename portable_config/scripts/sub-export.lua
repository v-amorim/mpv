--  https://github.com/kelciour/mpv-scripts
--  Usage:
--     Select subtitles and press Shift + X.
--
--  Note:
--     Requires FFmpeg in PATH environment variable or edit ffmpeg_path in the script options,
--     for example, by replacing [[ffmpeg]] with [[C:\Programs\ffmpeg\bin\ffmpeg.exe]]
--  Note:
--     A small circle at the top-right corner is a sign that export is happenning now.
--  Note:
--     The exported subtitles will be automatically selected with visibility set to true.
--  Note:
--     It could take ~1-5 minutes to export subtitles.

utils = require("mp.utils")

---- Script Options ----
ffmpeg_path = [[ffmpeg]]
------------------------

function say(state, detail)
	mp.commandv("script-message-to", "osd_theme", "say", "Subtitle export", state, detail)
end

-- ffmpeg only reports progress into a file, so it is polled while the export runs
progress_path = utils.join_path(os.getenv("TEMP") or ".", "mpv-sub-export.progress")
progress_timer = nil

function read_progress()
	local file = io.open(progress_path, "r")
	if not file then
		return nil
	end
	local seconds
	for line in file:lines() do
		local hours, minutes, rest = line:match("^out_time=(%d+):(%d+):([%d%.]+)")
		if hours then
			seconds = hours * 3600 + minutes * 60 + rest
		end
	end
	file:close()
	return seconds
end

function export_selected_subtitles()
	local i = 0
	local tracks_count = mp.get_property_number("track-list/count")
	while i < tracks_count do
		local track_type = mp.get_property(string.format("track-list/%d/type", i))
		local track_index = mp.get_property_number(string.format("track-list/%d/ff-index", i))
		local track_selected = mp.get_property(string.format("track-list/%d/selected", i))
		local track_lang = mp.get_property(string.format("track-list/%d/lang", i))
		local track_external = mp.get_property(string.format("track-list/%d/external", i))
		local track_codec = mp.get_property(string.format("track-list/%d/codec", i))

		if track_type == "sub" and track_selected == "yes" then
			if track_external == "yes" then
				say("nothing to do", "the selected track is already a file on disk, not one inside the video")
				return
			end

			local video_file = mp.get_property("working-directory") .. "/" .. mp.get_property("filename")

			local subtitles_ext = ".srt"
			if track_codec == "ass" then
				subtitles_ext = ".ass"
			end

			if track_codec == "srt" then
				subtitles_ext = ".srt"
			end

			if track_lang ~= nil then
				subtitles_ext = "." .. track_lang .. subtitles_ext
			end

			subtitles_file = mp.get_property("working-directory")
				.. "/"
				.. mp.get_property("filename/no-ext")
				.. subtitles_ext

			args = {
				ffmpeg_path,
				"-y",
				"-hide_banner",
				"-loglevel",
				"error",
				"-progress",
				progress_path,
				"-i",
				video_file,
				"-map",
				string.format("0:%d", track_index),
				subtitles_file,
			}

			process()

			break
		end

		i = i + 1
	end
end

-- the output is the video's own name plus ".<lang>.<ext>", and release names are
-- long enough to wrap the screen twice, so only the tail is worth showing
function output_suffix()
	local _, name = utils.split_path(subtitles_file)
	local stem = mp.get_property("filename/no-ext") or ""
	if stem ~= "" and name:sub(1, #stem + 1) == stem .. "." then
		return name:sub(#stem + 2)
	end
	return name
end

function process()
	local duration = mp.get_property_number("duration")
	os.remove(progress_path)

	local function report()
		local done = read_progress()
		local percent = done and duration and math.min(99, math.floor(done / duration * 100))
		local detail = "writing " .. output_suffix()
		if percent then
			detail = detail .. "  \xC2\xB7  " .. percent .. "%"
		end
		mp.commandv("script-message-to", "osd_theme", "busy", "Subtitle export", detail)
	end

	report()
	progress_timer = mp.add_periodic_timer(0.25, report)

	-- running it in the background is what lets the spinner turn and the
	-- percentage climb; the synchronous call froze mpv for the whole export
	mp.command_native_async({
		name = "subprocess",
		args = args,
		playback_only = false,
		capture_stderr = true,
	}, function(_, res)
		progress_timer:kill()
		os.remove(progress_path)
		finish(res)
	end)
end

function finish(res)
	if res.status == 0 then
		say("done", "wrote " .. output_suffix() .. ", now selected")
		mp.commandv("sub-add", subtitles_file)
		mp.set_property("sub-visibility", "yes")
	else
		say("failed", "ffmpeg would not write it, so the track is probably neither ASS nor SRT")
	end
end

mp.add_key_binding("", "export-selected-subtitles", export_selected_subtitles)
