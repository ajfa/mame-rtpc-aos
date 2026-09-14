-- Mouse probe: does the host mouse reach MAME at all?
-- Reads the emulated mouse ports and writes what it sees to the ack file.
-- No AOS needed: the port values follow the host mouse whether or not the
-- guest is listening, which separates "host to MAME" from "MAME to guest".
local ACK = os.getenv("RIG_ACK") or "state/acks"

local function say(s)
    local f = io.open(ACK, "a")
    if f then f:write(s .. "\n") f:close() end
    emu.print_info("mouse: " .. s)
end

local px, py, pb
for tag, port in pairs(manager.machine.ioport.ports) do
    if tag == ":kls:locc:mouse:X" then px = port
    elseif tag == ":kls:locc:mouse:Y" then py = port
    elseif tag == ":kls:locc:mouse:BTN" then pb = port end
end

if not px then say("NO-PORTS") return end

emu.wait(2)
local x0, y0 = px:read(), py:read()
say("start x=" .. x0 .. " y=" .. y0)

local movidos, botones = 0, 0
-- emu.wait counts EMULATED seconds, and with -nothrottle those run far
-- faster than real ones: the window has to be measured with the host clock
-- or it closes before anybody has moved anything.
local deadline = os.time() + 25
while os.time() < deadline do
    emu.wait(0.25)
    local x, y = px:read(), py:read()
    if x ~= x0 or y ~= y0 then
        movidos = movidos + 1
        if movidos <= 5 then say(string.format("motion %d: x=%d y=%d", movidos, x, y)) end
        x0, y0 = x, y
    end
    if pb then
        local b = pb:read()
        if b ~= 0 then botones = botones + 1 end
    end
end

say("TOTAL motions=" .. movidos .. " reads-with-button=" .. botones)
if movidos > 0 then say("VERDICT MOUSE-REACHES-MAME")
else say("VERDICT MOUSE-DOES-NOT-REACH-MAME") end
