--[[

╔════════════════════════════════╗
║           MPV jumpto           ║
║             v2.0.0             ║
╚════════════════════════════════╝

]]

local assdraw = require "mp.assdraw"
local config  = {

    border       = 0,
    font_size    = 24,
    width        = 280,
    box_alpha    = 80,
    box_color    = "000000",
    cursor_color = "FFFFFF",
    padding      = 16,
    round        = 8,
    label_text   = "Jump to:",
    max_length   = 10
}

local opened               = false
local isWindows            = package.config:sub(1, 1) ~= '/'
local cursor               = 0
local frameNumber          = ""
local utf8                 = {}
local data                 = {}
local overlay              = mp.create_osd_overlay("ass-events")
local textOverlay          = mp.create_osd_overlay("ass-events")
textOverlay.compute_bounds = true
textOverlay.hidden         = true

function utf8.next(str, pos)

    local b = str:byte(pos)

    if b < 128 then

        return 1
    elseif b < 224 then

        return 2
    elseif b < 240 then

        return 3
    end

    return 4
end

function utf8.len(str)

    local n, i, bytes = 0, 1, #str

    while i <= bytes do

        n = n + 1
        i = i + utf8.next(str, i)
    end

    return n
end

function utf8.sub(str,sstart,send)

    local content     = ""
    local n, i, bytes = 0, 1, #str
    local si, li      = 0, 0

    sstart = math.max(sstart, 1)

    while i <= bytes do

        n          = n + 1
        local size = utf8.next(str, i)

        if n == sstart then si = i                  end
        if n == send   then li = i + size - 1 break end

        i = i + size
    end

    if si == 0 and li == 0 then return "" end

    return str:sub(si, (li > 0) and li or bytes)
end

local function currentFrame()

    return mp.get_property("estimated-frame-number")
end

local function runCommand(args)

    return mp.command_native({

        name           = 'subprocess',
        playback_only  = false,
        capture_stdout = true,
        capture_stderr = true,
        args           = args
    })
end

local function assColor(rgbColor)

    local r, g, b = rgbColor:sub(1, 2), rgbColor:sub(3, 4), rgbColor:sub(5, 6)

    return b..g..r
end

local function reset()

    cursor      = 0
    frameNumber = ""
end

local function calculateTextWidth(text, fontSize)

    textOverlay.res_x, textOverlay.res_y = data.screenWidth, data.screenHeight
    textOverlay.data                     = "{\\fs"..fontSize.."}"..text
    local res                            = textOverlay:update()

    return (res and res.x1) and (res.x1 - res.x0) or 0
end

local function getScaledResolution()

    local width, height = mp.get_osd_size()
    local scale         = height / 720

    return width / scale, height / scale
end

local function fillData()

    data.screenWidth, data.screenHeight = getScaledResolution()
    data.lineHeight                     = config.font_size
    data.lineHeight                     = config.font_size
    data.boxWidth, data.boxHeight       = config.width, data.lineHeight + config.padding * 2
    data.x, data.y                      = data.screenWidth / 2 - data.boxWidth / 2, data.screenHeight / 2 - data.boxHeight / 2
end

local function updateOverlay(content, x, y)

    if overlay.data == content and overlay.res_x == data.screenWidth and overlay.res_y == data.screenHeight then return end

    overlay.data  = content
    overlay.res_x = (x and x > 0) and x or data.screenWidth
    overlay.res_y = (y and y > 0) and x or data.screenHeight
    overlay.z     = 2000

    overlay:update()
end

local function render()

    local ass = assdraw.ass_new()

    --background

    ass:new_event()
    ass:an(7)
    ass:pos(data.x , data.y)
    ass:append(string.format("{\\bord0\\blur0\\1c&H%s&\\1a&H%x&}", assColor(config.box_color), config.box_alpha))
    ass:draw_start()
    ass:round_rect_cw(0, 0, data.boxWidth, data.boxHeight, config.round, config.round)
    ass:draw_stop()

    --label

    ass:new_event()
    ass:an(7)
    ass:pos(data.x + config.padding, data.y + config.padding)
    ass:append(string.format("{\\bord0\\fs%s}", config.font_size))
    ass:append(config.label_text)

    local preCursor, postCursor = "", ""
    local labelWidth            = calculateTextWidth(config.label_text, config.font_size)

    if frameNumber ~= "" then

        preCursor  = cursor == 0 and "" or utf8.sub(frameNumber, 1, cursor)
        postCursor = utf8.sub(frameNumber, cursor + 1, 0)
    end

    --input

    ass:new_event()
    ass:an(7)
    ass:pos(data.x + config.padding + labelWidth, data.y + config.padding)
    ass:append(string.format("{\\bord%s\\fs%s}", config.border, config.font_size))
    ass:append(preCursor..postCursor)

    --cursor

    ass:new_event()
    ass:pos(data.x + config.padding + labelWidth, data.y + config.padding)
    ass:append(string.format("{\\bord0\\alpha&HFF&\\fs%s}", config.font_size))
    ass:append(preCursor..string.format("{\\alpha&H00&\\p1\\c&H%s&}m 0 0 l 1 0 l 1 %s l 0 %s{\\p0\\alpha&HFF&}", assColor(config.cursor_color), config.font_size, config.font_size)..postCursor)

    --update

    updateOverlay(ass.text)
end

local function getClipboard()

    local text = mp.get_property("clipboard/text", "")

    return text:gsub("%D+", "")
end

local function setClipboard(text)

    if isWindows then

        runCommand({"powershell", "-NoProfile", "-Command", 'Set-Clipboard -Value @"\n'..text..'\n"@'})
    else

        runCommand({"xclip", "-selection", "clipboard", '<<EOF\n'..text..'\nEOF\n'})
    end
end

local function jumpTo()

    if tonumber(frameNumber) >= tonumber(mp.get_property("estimated-frame-count")) then

        mp.osd_message("Frame number is greater than total frame number.", 5)

        return
    end

    local fps = mp.get_property("container-fps")

    if fps == nil then

        mp.osd_message("Failed to get framerate.", 5)

        return
    end

    local time    = tonumber(frameNumber) / fps
    local hours   = math.floor(time / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = time % 60
    local seekto  = string.format("%02d:%02d:%06.3f", hours, minutes, seconds)

    mp.commandv("seek", seekto, "absolute")
    mp.osd_message("")

    reset()
end

local function setDefaults()

    frameNumber = currentFrame()
    cursor      = utf8.len(frameNumber)
end

local function toggle()

    if not opened then

        setDefaults()
        setBindings()
        fillData()
        render()

        opened = true
    else

        unsetBindings()
        updateOverlay("", 0, 0)

        opened = false
    end
end

local function bindingList()

    local bindings = {

        close = {

            key  = "esc",
            func = function ()

                toggle()
            end,
            opts = nil
        },

        cursorhome = {
            key  = "home",
            func = function ()

                cursor = 0

                render()
            end,
            opts = nil
        },

        cursorend = {

            key  = "end",
            func = function ()

                cursor = utf8.len(frameNumber)

                render()
            end,
            opts = nil
        },

        cursorleft = {
            key  = "left",
            func = function ()

                cursor = cursor - 1
                cursor = math.max(cursor, 0)

                render()
            end,
            opts = {repeatable = true}
        },

        cursorright = {

            key  = "right",
            func = function ()

                local charCount = utf8.len(frameNumber)
                cursor          = cursor + 1
                cursor          = math.min(cursor, charCount)

                render()
            end,
            opts = {repeatable = true}
        },

        copy = {

            key  = "ctrl+c",
            func = function ()

                setClipboard(frameNumber)

                mp.osd_message("Copied frame number.", 5)

                toggle()
            end,
            opts = nil
        },

        paste = {

            key  = "ctrl+v",
            func = function ()

                local preCursor  = utf8.sub(frameNumber, 1,          cursor)
                local postCursor = utf8.sub(frameNumber, cursor + 1, 0)
                local clipboard  = getClipboard()
                frameNumber      = preCursor..clipboard..postCursor
                cursor           = cursor + utf8.len(clipboard)

                render()
            end,
            opts = nil
        },

        deletebackward = {

            key  = "bs",
            func = function ()

                if cursor == 0 then return end

                cursor           = cursor - 1
                cursor           = math.max(cursor, 0)
                local preCursor  = cursor == 0 and "" or utf8.sub(frameNumber, 1, cursor)
                local postCursor = utf8.sub(frameNumber, cursor + 2, 0)
                frameNumber      = preCursor..postCursor

                render()
            end,
            opts = {repeatable = true}
        },

        deleteforward = {

            key  = "del",
            func = function ()

                local charCount = utf8.len(frameNumber)

                if charCount == cursor then return end

                local preCursor  = cursor == 0 and "" or utf8.sub(frameNumber, 1, cursor)
                local postCursor = utf8.sub(frameNumber, cursor + 2, 0)
                frameNumber      = preCursor..postCursor

                render()
            end,
            opts = {repeatable = true}
        },

        enter = {

            key  = "enter",
            func = function ()

                toggle()
                jumpTo()
            end,
            opts = nil
        },

        click = {

            key  = "mbtn_left",
            func = function ()

                toggle()
            end,
            opts = nil
        }
    }

    for i = 0, 9 do

        i = tostring(i)

        bindings["number"..i] = {

            key  = i,
            func = function ()

                local charCount = utf8.len(frameNumber)

                if charCount > config.max_length then return end

                if charCount == 0 then

                    frameNumber = i
                else

                    local preCursor  = cursor == 0 and "" or utf8.sub(frameNumber, 1, cursor)
                    local postCursor = utf8.sub(frameNumber, cursor + 1, 0)
                    frameNumber      = preCursor..i..postCursor
                end

                cursor = cursor + 1

                render()
            end,
            opts = {repeatable = true}
        }
    end

    return bindings
end

function setBindings()

    for name, binding in pairs(bindingList()) do mp.add_forced_key_binding(binding.key, "jumpto_"..name, binding.func, binding.opts) end
end

function unsetBindings()

    for name in pairs(bindingList()) do mp.remove_key_binding("jumpto_"..name) end
end

local function stepFrame(direction)

    local number = tonumber(mp.get_property("estimated-frame-number"))
    local total  = tonumber(mp.get_property("estimated-frame-count"))

    if direction == "back" then

        number = number - 1

        if number < 0 then return end

        mp.commandv("frame-back-step")
        mp.osd_message(string.format("%s / %s", number, total), 5)
    elseif direction == "forward" then

        number = number + 1

        mp.commandv("frame-step", 1, "mute")
        mp.osd_message(string.format("%s / %s", number, total), 5)
    end
end

mp.add_key_binding("Ctrl+j", "jumpto", toggle)
mp.add_key_binding(nil, "jumpto_prevframe", function() stepFrame("back")    end, {repeatable=true})
mp.add_key_binding(nil, "jumpto_nextframe", function() stepFrame("forward") end, {repeatable=true})