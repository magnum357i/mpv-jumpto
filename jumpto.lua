--Author: Emilia (https://github.com/EmiliaTheGoddess) & Magnum357 (https://github.com/magnum357i)

frameNumber = ""
keyMapping = {
    NUMBER0 = function()
        if frameNumber ~= "" then
        frameNumber = frameNumber.."0"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
        end
    end,
    NUMBER1 = function()
        frameNumber = frameNumber.."1"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER2 = function()
        frameNumber = frameNumber.."2"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER3 = function()
        frameNumber = frameNumber.."3"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER4 = function()
        frameNumber = frameNumber.."4"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER5 = function()
        frameNumber = frameNumber.."5"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER6 = function()
        frameNumber = frameNumber.."6"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER7 = function()
        frameNumber = frameNumber.."7"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER8 = function()
        frameNumber = frameNumber.."8"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    NUMBER9 = function()
        frameNumber = frameNumber.."9"
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    BS = function()
        if frameNumber ~= "" then frameNumber = frameNumber:sub(1, -2) end
        mp.osd_message(string.format("Enter frame: %s", frameNumber), 5)
    end,
    ESC = function()
        mp.osd_message("Cancelled jump")
        quitJumpTo()
    end,
    ENTER = function()
        moveToFrame()
        quitJumpTo()
    end
}

function moveToFrame()
if tonumber(frameNumber) >= tonumber(mp.get_property("estimated-frame-count")) then
mp.osd_message("Frame number is greater than total frame number.", 5)
else
local fps = mp.get_property("container-fps")
    if fps == nil then
    mp.osd_message("Failed to get framerate.", 5)
    else
    local time    = frameNumber / fps
    local hours   = math.floor(time / 3600)
    local minutes = math.floor((time % 3600) / 60)
    local seconds = time % 60
    local seekto  = string.format("%02d:%02d:%06.3f", hours, minutes, seconds)
    mp.commandv("seek", seekto, "absolute")
    mp.osd_message("")
    end
end
end

function jumpTo()
mp.osd_message(string.format("Enter frame: %s", "?"), 15)
for key, func in pairs(keyMapping) do
if tonumber(string.sub(key,-1,-1)) ~= nil then key = string.sub(key,-1,-1) end
mp.add_forced_key_binding(key, "JUMPTO-"..key, func)
end
end

function quitJumpTo()
for key, func in pairs(keyMapping) do
    if tonumber(string.sub(key,-1,-1)) ~= nil then
    key = string.sub(key,-1,-1)
    end
mp.remove_key_binding("JUMPTO-"..key)
end
frameNumber = ""
end

function currentFrame()
local currentFrameNumber = mp.get_property("estimated-frame-number")
mp.osd_message(string.format("Current frame: %s", currentFrameNumber), 5)
end

mp.add_key_binding("ctrl+j", "jumpto", jumpTo)
mp.add_key_binding("ctrl+J", "currentframe", currentFrame)
