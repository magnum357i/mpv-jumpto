--[[

╔════════════════════════════════╗
║           MPV jumpto           ║
║             v2.0.5             ║
╚════════════════════════════════╝

]]

local options = require 'mp.options'
local assdraw = require "mp.assdraw"
local input   = require "input"
local config  = {

    font_size          = 24,
    width              = 280,
    box_alpha          = 80,         --0-255
    box_color          = "000000",
    cursor_color       = "white",    --white,black
    padding            = 16,
    round              = 8,
    label_text         = "Jump to:",
    max_length         = 10,
    copy_aegisub_style = true        --If true, copies in "0:00:00.00" format to the clipboard.
}
local jumpMode             = ""
local opened               = false
local isWindows            = package.config:sub(1, 1) ~= '/'
local data                 = {}
local overlay              = mp.create_osd_overlay("ass-events")
local textOverlay          = mp.create_osd_overlay("ass-events")
textOverlay.compute_bounds = true
textOverlay.hidden         = true

options.read_options(config, "jumpto")

local function tableMerge(t1, t2)

    local t3 = {}

    for k, v in pairs(t1) do t3[k] = v end
    for k, v in pairs(t2) do t3[k] = v end

    return t3
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

local function calculateTextWidth(text, fontSize)

    textOverlay.res_x, textOverlay.res_y = data.screenWidth, data.screenHeight
    textOverlay.data                     = "{\\bord0\\b0\\fs"..fontSize.."}"..text
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
    ass:append(string.format("{\\bord0\\1c&H%s&\\1a&H%x&}", assColor(config.box_color), config.box_alpha))
    ass:draw_start()
    ass:round_rect_cw(0, 0, data.boxWidth, data.boxHeight, config.round, config.round)
    ass:draw_stop()

    --label

    ass:new_event()
    ass:an(7)
    ass:pos(data.x + config.padding, data.y + config.padding)
    ass:append(string.format("{\\bord0\\fs%s}", config.font_size))
    ass:append(config.label_text)

    local labelWidth           = calculateTextWidth(config.label_text, config.font_size)
    local text, textWithCursor = input.texts()

    --input

    ass:new_event()
    ass:an(7)
    ass:pos(data.x + config.padding + labelWidth, data.y + config.padding)
    ass:append(text)

    --cursor

    ass:new_event()
    ass:pos(data.x + config.padding + labelWidth, data.y + config.padding)
    ass:append(textWithCursor)

    --update

    updateOverlay(ass.text)
end

local function setClipboard()

    local time = input.get_text()

    if config.copy_aegisub_style then time = time:gsub("(%.%d%d)%d$", "%1") end

    if isWindows then

        runCommand({"powershell", "-NoProfile", "-Command", 'Set-Clipboard -Value @"\n'..time..'\n"@'})
    else

        runCommand({"xclip", "-selection", "clipboard", '<<EOF\n'..time..'\nEOF\n'})
    end

    if jumpMode == "frame" then

        mp.osd_message("Frame number copied.", 3)
    else

        mp.osd_message("Timestamp copied.", 3)
    end
end

local function frame2timestamp(frame)

    local fps  = mp.get_property("container-fps")
    local time = tonumber(frame) / fps
    local h    = math.floor(time / 3600)
    local m    = math.floor(time / 60) % 60
    local s    = time % 60

    return string.format("%d:%02d:%06.3f", h, m, s)
end

local function currentTime()

    local frameNumber = mp.get_property("estimated-frame-number")

    if jumpMode == "frame" then return frameNumber end

    return frame2timestamp(frameNumber)
end

local function jumpTo()

    local time = input.get_text()

    if jumpMode == "frame" then

        time = tonumber(time)

        if not time then

            mp.osd_message("Frame number is unvalid.", 3)

            return
        elseif time >= tonumber(mp.get_property("estimated-frame-count")) then

            mp.osd_message("Frame number is greater than total frame number.", 3)

            return
        end

        mp.commandv("seek", frame2timestamp(time), "absolute")

        return
    end

    mp.commandv("seek", time, "absolute")
    mp.osd_message("")
end

local function toggle(mode)

    if not opened then

        input.init()

        jumpMode           = mode
        input.font_size    = config.font_size
        input.cursor_theme = config.cursor_color

        if jumpMode == "frame" then

            input.max_length  = config.max_length
            input.accept_only = "digits"
        else

            input.format = "[0-9]:[0-5][0-9]:[0-5][0-9]%.[0-9][0-9][0-9]"
        end

        input.default(currentTime())

        setBindings()
        fillData()
        render()

        opened = true
    else

        input.reset()

        unsetBindings()
        updateOverlay("", 0, 0)

        opened = false

        collectgarbage()
    end
end

local function bindingList()

    local inputBindings = input.bindings({

        after_changes = function()

            render()
        end,

        edit_clipboard = function(text)

            if #text == 10 then text = text.."0" end

            return text
        end
    })

    local defaultBindings = {

        close = {

            key  = "esc",
            func = function ()

                toggle()
            end,
            opts = nil
        },

        copy = {

            key  = "ctrl+c",
            func = function ()

                toggle()
                setClipboard()
            end,
            opts = nil
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

    return tableMerge(defaultBindings, inputBindings)
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
        mp.osd_message(string.format("%s / %s", number, total), 3)
    elseif direction == "forward" then

        number = number + 1

        mp.commandv("frame-step", 1, "mute")
        mp.osd_message(string.format("%s / %s", number, total), 3)
    end
end

mp.add_key_binding("Ctrl+j", "jumpto_frame",     function() if opened and jumpMode == "timestamp" then toggle() end toggle("frame")     end)
mp.add_key_binding("Ctrl+J", "jumpto_timestamp", function() if opened and jumpMode == "frame"     then toggle() end toggle("timestamp") end)

mp.add_key_binding(nil, "jumpto_prevframe",      function() stepFrame("back")    end, {repeatable=true})
mp.add_key_binding(nil, "jumpto_nextframe",      function() stepFrame("forward") end, {repeatable=true})