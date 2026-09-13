-- Type into the RT PC keyboard by driving the matrix directly.
-- MAME's natural keyboard drops every shifted character on this machine, so
-- shift is held down around the keypress the way a person would do it.

KEYS = {}          -- char -> {field=, shift=bool}
local shift_field

local function learn()
    for tag, port in pairs(manager.machine.ioport.ports) do
        if tag:find("keyboard") then
            for name, field in pairs(port.fields) do
                if name == "Left Shift" then shift_field = field end
                if name == "Space" then KEYS[" "] = {field = field, shift = false} end
                if name == "Enter" then KEYS["\n"] = {field = field, shift = false} end
                local lo, hi = name:match("^(%S)%s%s+(%S)$")
                if lo then
                    KEYS[lo] = {field = field, shift = false}
                    KEYS[hi] = {field = field, shift = true}
                elseif #name == 1 then
                    KEYS[name] = {field = field, shift = false}
                end
            end
        end
    end
end

local function hold(field, on) field:set_value(on and 1 or 0) end

function TYPE(text)
    if not shift_field then learn() end
    for i = 1, #text do
        local c = text:sub(i, i)
        local k = KEYS[c]
        if not k then
            emu.print_error("keys.lua: no key for [" .. c .. "]")
        else
            if k.shift then hold(shift_field, true); emu.wait(0.06) end
            hold(k.field, true)
            emu.wait(0.06)
            hold(k.field, false)
            emu.wait(0.04)
            if k.shift then hold(shift_field, false) end
            emu.wait(0.10)
        end
    end
end
