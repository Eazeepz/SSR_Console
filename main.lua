-- SR1_Console: Developer console toggle + keyboard input
-- Combines Console Toggle (F7 on/off) + Console Keyboard (stage 2)
-- Single mod: press ~ to open, type commands, press ~ to close.
--
-- Toggle key: default is ~ (VK_OEM_3). Change in mod.ini with a key name
-- ("F8") or a raw VK code (121). See README.md for common codes.

local ADDR = tonumber(wml.setting("address", "0x83710223"))

-- Resolve the toggle key. The loader's name table has no entry for ~,
-- so a single "~" string is mapped to VK_OEM_3 (0xC0). Plain key names
-- ("F7") and decimal VK codes ("121") pass through unchanged.
local KEY = wml.setting("key", "~")
if KEY == "~" then
  KEY = 0xC0
elseif type(KEY) == "string" and KEY:match("^%d+$") then
  KEY = tonumber(KEY)
end

local function num(name, default)
  return math.tointeger(tonumber(wml.setting(name, default)) or default) or default
end

local FLAG_DOWN   = num("flag_down", 1)
local FLAG_UP     = num("flag_up", 2)
local FLAG_REPEAT = num("flag_repeat", 4)
local USE_REPEAT  = num("repeat", 1)
local MAX_LOGGED  = num("log_events", 40)

local CONSOLE = ADDR
local PARENT, READER, POLLER = 0x82648ED8, 0x82649B78, 0x827166F8
local ERROR_EMPTY = 0x10D2   -- what the real API returns when no key is waiting

-- Keys that get forwarded (Windows virtual-key codes).
local keys = {}
local function add_range(a, b) for k = a, b do keys[#keys + 1] = k end end
add_range(0x41, 0x5A)  -- A-Z
add_range(0x30, 0x39)  -- 0-9
add_range(0x60, 0x69)  -- numpad 0-9
for _, k in ipairs({ 0x20, 0x0D, 0x08, 0x09, 0x2E, 0x24, 0x23, 0x25, 0x26, 0x27, 0x28,
                     0x10, 0x11, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xDB, 0xDC, 0xDD, 0xDE }) do
  keys[#keys + 1] = k
end

local queue, held = {}, {}
local was_on, logged = false, 0

local function console_on()
  return wml.read_u8(CONSOLE) == 1
end

local function push(vk, flags)
  if #queue < 64 then queue[#queue + 1] = { vk = vk, flags = flags } end
end

local function take_all(on)
  for _, k in ipairs(keys) do wml.take_key(k, on) end
end

-- 1. Each frame: hotkey toggles the console byte, then capture typing keys while it's on.
wml.on_frame(function()
  if wml.key_pressed(KEY) then
    -- Read the byte instead of keeping our own on/off copy, so an external
    -- source (e.g. Whompays Trainer's menu) can never get out of step.
    local now = console_on() and 0 or 1
    wml.write_u8(CONSOLE, now)
    wml.log("Console flag " .. (now == 1 and "ON" or "OFF") ..
            ", byte reads back " .. tostring(wml.read_u8(CONSOLE)))
    queue, held = {}, {}
  end

  local on = console_on()
  if on ~= was_on then
    was_on = on
    take_all(on)
    queue, held = {}, {}
    wml.log("keyboard capture " .. (on and "ON" or "OFF"))
  end
  if not on then return end
  for _, k in ipairs(keys) do
    local h = held[k]
    if wml.key_down(k) then
      if not h then
        held[k] = 0
        push(k, FLAG_DOWN)
      else
        held[k] = h + 1
        if USE_REPEAT == 1 and h >= 30 and (h - 30) % 3 == 0 then
          push(k, FLAG_DOWN | FLAG_REPEAT)
        end
      end
    elseif h then
      held[k] = nil
      push(k, FLAG_UP)
    end
  end
end)

-- 2. Make the game's keystroke reader run every frame while the console is on.
wml.hook(PARENT, function(ctx)
  ctx:call_original()
  if console_on() then
    local keep = ctx:r(3)
    ctx:call(READER)
    ctx:set_r(3, keep)
  end
end)

-- 3. Feed the game real keystrokes instead of "device not connected".
wml.hook(POLLER, function(ctx)
  if not console_on() then
    ctx:call_original()
    return
  end
  local p  = ctx:r(5) & 0xFFFFFFFF
  local ev = table.remove(queue, 1)
  if ev and p ~= 0 then
    wml.write_u16(p,     ev.vk)     -- VirtualKey
    wml.write_u16(p + 2, 0)         -- Unicode (the game does not read it)
    wml.write_u16(p + 4, ev.flags)  -- Flags
    wml.write_u8(p + 6, 0)          -- UserIndex
    wml.write_u8(p + 7, 0)          -- HidCode
    ctx:set_r(3, 0)
    if logged < MAX_LOGGED then
      logged = logged + 1
      wml.log(string.format("key event vk=0x%02X flags=0x%X", ev.vk, ev.flags))
    end
  else
    ctx:set_r(3, ERROR_EMPTY)
  end
end)

wml.log("SR1_Console loaded. ~ toggles console, then type commands.")
