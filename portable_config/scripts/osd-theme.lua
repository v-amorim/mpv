-- One OSD message shape for input.conf:
--   expand-properties script-message-to osd_theme say "<label>" "<state>" "<detail>"
-- State may be empty. "yes"/"no" become a green "on" / red "off".

-- Moonlight, in the &HBBGGRR& order ASS wants, from the oh-my-posh palette.
local LABEL = '&HFFD9CE&' -- terminal_brightgray #CED9FF
local ON = '&H95EF49&' -- terminal_green #49EF95
local OFF = '&H715FCA&' -- terminal_error #CA5F71
local VALUE = '&HF3AB5D&' -- terminal_blue #5DABF3
local DETAIL = '&HE6B9AC&' -- terminal_bluegray #ACB9E6
local OUTLINE = '&H36231E&' -- main_background #1E2336

-- mpv answers in its own vocabulary: loop-file set to "yes" reads back as "inf".
local BOOLEAN_WORDS = { yes = 'on', on = 'on', inf = 'on', no = 'off', off = 'off' }

-- Overlay coordinates are fixed at 720 tall, so these scale with the window.
local ANCHOR = '{\\an7\\pos(26,24)\\fs34\\bord2\\shad1\\b1\\3c' .. OUTLINE .. '\\4c' .. OUTLINE .. '}'
local DETAIL_SIZE = '{\\fs26\\b0}'

local overlay = mp.create_osd_overlay('ass-events')
local hide_timer

local function paint(colour, text)
    return string.format('{\\1c%s}%s', colour, text)
end

local function state_chunk(state)
    if not state or state == '' then return '' end
    local word = BOOLEAN_WORDS[state]
    if word then
        return ' ' .. paint(word == 'on' and ON or OFF, word)
    end
    return ' ' .. paint(VALUE, state)
end

mp.register_script_message('say', function(label, state, detail)
    local text = ANCHOR .. paint(LABEL, label) .. state_chunk(state)
    if detail and detail ~= '' then
        text = text .. '\\N' .. DETAIL_SIZE .. paint(DETAIL, detail)
    end

    overlay.data = text
    overlay:update()

    if hide_timer then hide_timer:kill() end
    hide_timer = mp.add_timeout(mp.get_property_number('osd-duration', 1000) / 1000, function()
        overlay:remove()
    end)
end)
