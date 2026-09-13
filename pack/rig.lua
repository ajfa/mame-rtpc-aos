-- Lua driver for the emulated RT PC: logs in on the console, optionally brings
-- up X11, and then obeys orders written to a file so the shell outside can
-- type, move the mouse, take snapshots and halt the machine.
--
--   K <text>    type it and press Enter      X <dx> <dy>  move the mouse
--   B <mask>    buttons, 32 left 128 right   S <name>     snapshot
--   W <secs>    wait                         L            log in and start X
dofile(os.getenv("RIG_KEYS") or "pack/keys.lua")

local CMD   = os.getenv("RIG_CMD") or "state/orders"
local ACK   = os.getenv("RIG_ACK") or "state/acks"
local WANTX = os.getenv("RIG_X") == "1"

local scr
for _, s in pairs(manager.machine.screens) do scr = s break end

local shot = 0
local function snap(tag)
    shot = shot + 1
    if scr then scr:snapshot(string.format("%02d_%s.png", shot, tag)) end
end

local function say(s)
    local f = io.open(ACK, "a")
    if f then f:write(s .. "\n") f:close() end
    emu.print_info("rig: " .. s)
end

-- mouse: the axes are relative, the device reports the difference since its
-- last report, so keep a running total and set that
local fx, fy = nil, nil
local btn = {}
for tag, port in pairs(manager.machine.ioport.ports) do
    if tag:find("mouse") then
        for _, field in pairs(port.fields) do
            if tag:sub(-2) == ":X" then fx = field
            elseif tag:sub(-2) == ":Y" then fy = field
            elseif tag:sub(-4) == ":BTN" then btn[field.mask] = field end
        end
    end
end

local ax, ay = 0, 0
local function move(dx, dy)
    ax = (ax + dx) % 4096
    ay = (ay + dy) % 4096
    if fx then fx:set_value(ax) end
    if fy then fy:set_value(ay) end
end

local function buttons(mask)
    for m, f in pairs(btn) do f:set_value((mask & m) ~= 0 and 1 or 0) end
end

local LOGIN = tonumber(os.getenv("RIG_LOGIN_WAIT") or "60")
local STEP  = tonumber(os.getenv("RIG_STEP") or "6")

function ATTEMPT()
    snap("before-login")
    TYPE("\n")            emu.wait(STEP)
    TYPE("root\n")        emu.wait(STEP * 2)
    TYPE("sh\n")          emu.wait(STEP)
    snap("after-login")
    if not WANTX then return end
    -- once the X server starts it owns the console keyboard, so the whole
    -- desktop has to go in on one line before it, and run detached
    TYPE("PATH=/usr/bin/X11:/bin:/usr/bin:/etc; DISPLAY=:0; export PATH DISPLAY\n")
    emu.wait(STEP)
    -- uwm only knows the WindowOps menu if it finds a uwmrc: its compiled in
    -- bindings name the menu without defining it
    TYPE("cp /usr/lib/X11/default.uwmrc /.uwmrc\n")
    emu.wait(STEP)
    TYPE("(Xibm :0 -ega /dev/console > /tmp/xlog 2>&1 & sleep 50; " ..
         "xterm -geometry 62x20+8+8 & sleep 25; " ..
         "xclock -geometry 120x120+500+8 & sleep 15; uwm &) &\n")
    emu.wait(STEP * 4)
    snap("after-x-start")
    emu.wait(STEP * 20)
end

local function orders()
    local f = io.open(CMD, "r")
    if not f then return end
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = line end
    f:close()
    if #lines == 0 then return end
    local w = io.open(CMD, "w") if w then w:close() end
    for _, line in ipairs(lines) do
        local op, rest = line:match("^(%a)%s?(.*)$")
        if op == "K" then TYPE(rest .. "\n") say("K " .. rest)
        elseif op == "X" then
            local dx, dy = rest:match("(-?%d+)%s+(-?%d+)")
            if dx then move(tonumber(dx), tonumber(dy)) end
            say("X " .. rest)
        elseif op == "B" then buttons(tonumber(rest) or 0) say("B " .. rest)
        elseif op == "S" then snap(rest ~= "" and rest or "order") say("S " .. rest)
        elseif op == "W" then emu.wait(tonumber(rest) or 1) say("W " .. rest)
        elseif op == "L" then ATTEMPT() say("L done")
        end
    end
end

-- no blind typing: the shell outside watches the screen and sends the L order
-- once the console has actually stopped printing and the prompt is there
emu.wait(LOGIN)
say("started")

while true do
    orders()
    emu.wait(0.2)
end
