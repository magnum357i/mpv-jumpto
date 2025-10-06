--v1.0
local utf8   = require "fastutf8"
local input  = {

    color      = "000000",
    font_size  = 0,
    max_length = 500,
    format     = "",
    acceptOnly = ""  --digits,text
}
local cursor = 0
local text   = ""

local function filter(str)

    if input.acceptOnly == "" then return str end

    if input.acceptOnly == "digits" then

        return str:gsub("%D+", "")
    elseif input.acceptOnly == "text" then

        return str:gsub("%d+", "")
    end
end

function input.get_clipboard()

    local text = mp.get_property("clipboard/text", "")
    text       = filter(text)

    return text
end

function input.get_text()

    return text
end

function input.texts()

    local preCursor, postCursor = "", ""

    if text == "" then return "", string.format("{\\p1\\c&H%s&}m 0 0 l 1 0 l 1 %s l 0 %s", input.color, input.font_size, input.font_size) end

    preCursor  = cursor == 0 and "" or utf8.sub(text, 1, cursor)
    postCursor = utf8.sub(text, cursor + 1, 0)

    return
    preCursor..postCursor,
    string.format("{\\bord0\\alpha&HFF&\\fs%s}", input.font_size)..preCursor..string.format("{\\alpha&H00&\\p1\\c&H%s&}m 0 0 l 1 0 l 1 %s l 0 %s{\\p0\\alpha&HFF&}", input.color, input.font_size, input.font_size)..postCursor
end

function input.bindings(afterChanges)

    local list = {

        cursorhome = {

            key  = "home",
            func = function ()

                cursor = 0

                if afterChanges then afterChanges() end
            end,
            opts = nil
        },

        cursorend = {

            key  = "end",
            func = function ()

                cursor = utf8.len(text)

                if afterChanges then afterChanges() end
            end,
            opts = nil
        },

        cursorleft = {
            key  = "left",
            func = function ()

                if text ~= "" and input.format ~= "" and cursor > 0 and string.find(utf8.sub(text, cursor, cursor), "%p") then

                    cursor = cursor - 1
                end

                cursor = cursor - 1
                cursor = math.max(cursor, 0)

                if afterChanges then afterChanges() end
            end,
            opts = {repeatable = true}
        },

        cursorright = {

            key  = "right",
            func = function ()

                local count = utf8.len(text)
                cursor      = cursor + 1

                if text ~= "" and input.format ~= "" and string.find(utf8.sub(text, cursor + 1, cursor + 1), "%p") then

                    cursor = cursor + 1
                end

                cursor = math.min(cursor, count)

                if afterChanges then afterChanges() end
            end,
            opts = {repeatable = true}
        },

        paste = {

            key  = "ctrl+v",
            func = function ()

                local clipboardText = input.get_clipboard()

                if input.format == "" then

                    local preCursor  = utf8.sub(text, 1,          cursor)
                    local postCursor = utf8.sub(text, cursor + 1, 0)
                    text             = preCursor..clipboardText..postCursor
                    local count      = utf8.len(text)

                    if count > input.max_length then

                        text   = utf8.sub(text, 1, input.max_length)
                        cursor = count
                    else

                        cursor = cursor + utf8.len(clipboardText)
                    end

                    if afterChanges then afterChanges() end
                elseif text ~= clipboardText and string.find(clipboardText, "^"..input.format.."$") then

                    text   = clipboardText
                    cursor = utf8.len(text)

                    if afterChanges then afterChanges() end
                end
            end,
            opts = nil
        },

        deletebackward = {

            key  = "bs",
            func = function ()

                if input.format ~= "" then return end

                if cursor == 0 then return end

                cursor           = cursor - 1
                cursor           = math.max(cursor, 0)
                local preCursor  = cursor == 0 and "" or utf8.sub(text, 1, cursor)
                local postCursor = utf8.sub(text, cursor + 2, 0)
                text      = preCursor..postCursor

                if afterChanges then afterChanges() end
            end,
            opts = {repeatable = true}
        },

        deleteforward = {

            key  = "del",
            func = function ()

                if input.format ~= "" then return end

                local count = utf8.len(text)

                if count == cursor then return end

                local preCursor  = cursor == 0 and "" or utf8.sub(text, 1, cursor)
                local postCursor = utf8.sub(text, cursor + 2, 0)
                text             = preCursor..postCursor

                if afterChanges then afterChanges() end
            end,
            opts = {repeatable = true}
        },

        input = {

            key  = "any_unicode",
            func = function (info)

                if info.key_text and filter(info.key_text) ~= "" and (info.event == "press" or info.event == "down" or info.event == "repeat") then

                    local preCursor, postCursor
                    local count = utf8.len(text)

                    if input.format == "" then

                        if count > input.max_length then return end

                        if count == 0 then

                            text = info.key_text
                        else

                            preCursor  = cursor == 0 and "" or utf8.sub(text, 1, cursor)
                            postCursor = utf8.sub(text, cursor + 1, 0)
                            text       = preCursor..info.key_text..postCursor
                        end

                        cursor = cursor + 1
                    else

                        preCursor      = cursor == 0 and "" or utf8.sub(text, 1, cursor)
                        postCursor     = utf8.sub(text, cursor + 2, 0)
                        local tempText = preCursor..info.key_text..postCursor

                        if not string.find(tempText, "^"..input.format.."$") or count == cursor then return end

                        text   = tempText
                        cursor = cursor + 1

                        if text ~= "" and input.format ~= "" and string.find(utf8.sub(text, cursor + 1, cursor + 1), "%p") then

                            cursor = cursor + 1
                        end
                    end

                    if afterChanges then afterChanges() end
                end
            end,
            opts = {repeatable = true, complex = true}
        }

    }

    return list
end

function input.default(str)

    if input.format ~= "" and not string.find(str, "^"..input.format.."$") then error("Default value does not match the required format.") end

    text   = filter(str)
    cursor = utf8.len(text)
end

function input.reset()

    input.color      = "000000"
    input.font_size  = 0
    input.max_length = 500
    input.format     = ""
    input.acceptOnly = ""
    cursor           = 0
    text             = ""
end

input.init = input.reset

return input