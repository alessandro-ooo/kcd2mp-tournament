-- Example: web pages on surfaces in the world - a notice board, a tavern sign and letters painted on a wall.
--
-- /board hangs a notice board on the wall you look at, /sign a tavern sign, /paint the tavern's name painted on the wall
-- (each in front of you when you look at nothing within 8 m); /post <text> pins a notice on every board, /unpin takes the oldest down, /clearboards removes them all. Each board
-- is a web page (ui/board/) that every player's game near it draws on its own: when a player's copy is ready
-- (OnPlayerWebSurfaceReady) the mode sends it the notices, and when a notice is pinned every copy gets the new list. The board
-- has a use prompt: the use key on it shows the next notice on that player's copy (the page's KcdMp.onSurfaceUse), and the page
-- tells the mode which one was read (OnPlayerWebSurfaceEvent). The painted letters are a see-through board: its page draws the
-- letters alone on a clear background (ui/painted/), and the board's transparent option lets the wall show around them.
--
-- Hanging a board on a wall: the player's own game finds the point under the crosshair and the way the wall faces there
-- (client/place.lua, GetLookTarget); the mode puts the board's middle 3 cm out from that point, its face looking the way the
-- wall does. The chat then shows the CreateWebSurface line that makes the same board - place it by eye once, paste the line
-- into your own mode's OnGameModeInit, and it is there at every start.
--
-- Run it with [gamemode] script = "sdk/web/examples/notice-board/notice-board.lua" (its client/ and ui/ folders come with it),
-- or copy this folder into gamemodes/.

SetGameModeText("notice board example")

local notices = {
  { title = "Wanted", text = "A smith's apprentice. Ask at the forge by the gate." },
  { title = "Lost", text = "A brown mare with a white star. A reward for her return." },
}
local boards = {}   -- surface id -> true (the boards and the signs)

local function list()
  return { notices = notices }
end

-- a surface in front of the player, facing them: its centre `ahead` metres along their view, `up` metres above their feet. A
-- surface's yaw is the way its face looks - back toward the player, so their yaw turned around.
local function in_front(pid, ahead, up)
  local x, y, z = GetPlayerPos(pid)
  local yaw = GetPlayerYaw(pid)
  local rad = math.rad(yaw)
  return x - math.sin(rad) * ahead, y + math.cos(rad) * ahead, z + up, yaw + 180
end

-- each page's board: its size in metres (the page's shape), its options, and where it goes when the player looks at no wall
local SHAPES = {
  board = { w = 1.5, h = 1.0, ahead = 2.5, up = 1.5, options = { prompt = "Read the notices" } },
  sign = { w = 1.2, h = 0.6, ahead = 3, up = 2.2, options = {}, pitch = -10 },   -- add glow = 1 for a sign lit at night
  painted = { w = 3.2, h = 0.8, ahead = 3, up = 2.4, options = { transparent = true } },
}

-- the options as Lua source, for the line the chat shows
local function options_text(options)
  local keys = {}
  for k in pairs(options) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = options[k]
    parts[#parts + 1] = k .. " = " .. (type(v) == "string" and string.format("%q", v) or type(v) == "number" and string.format("%g", v)
      or tostring(v))
  end
  if #parts == 0 then return "{}" end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

-- the player's game answered "board.look": the point on the wall and the way it faces there, or "none"
local function place(pid, page, spot)
  local shape = SHAPES[page]
  if not shape then return end
  local x, y, z, nx, ny, nz = spot:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
  x, y, z, nx, ny, nz = tonumber(x), tonumber(y), tonumber(z), tonumber(nx), tonumber(ny), tonumber(nz)
  local yaw, pitch
  local px, py, pz = GetPlayerPos(pid)
  -- trust the answer no further than any input: a point near the player, on a surface that stands up (a floor or a ceiling
  -- would leave the board's turn to chance - in front of the player then)
  local on_wall = x and nz and px and math.abs(nz) < 0.85
    and (x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2 < 12 ^ 2
  if on_wall then
    -- a surface's yaw is the way its face looks: along (-sin yaw, cos yaw), so the wall's normal turned into degrees; the pitch
    -- leans the top away from the reader, as far as the wall leans back
    yaw = math.deg(math.atan(-nx, ny))
    pitch = math.deg(math.asin(math.max(-1, math.min(1, nz))))
    x, y, z = x + nx * 0.03, y + ny * 0.03, z + nz * 0.03
  else
    x, y, z, yaw = in_front(pid, shape.ahead, shape.up)
    pitch = shape.pitch or 0
  end
  -- rounded as the line below prints them, so the pasted line makes exactly this board
  local function round(v, step) return math.floor(v / step + 0.5) * step end
  x, y, z, yaw, pitch = round(x, 0.01), round(y, 0.01), round(z, 0.01), round(yaw % 360, 0.1), round(pitch, 0.1)
  local options = {}
  for k, v in pairs(shape.options) do options[k] = v end
  if pitch ~= 0 then options.pitch = pitch end
  local id = CreateWebSurface(page, x, y, z, yaw, shape.w, shape.h, options)
  if not id then return SendClientMessage(pid, COLOR_SERVER, "That did not work - the server log says why.") end
  boards[id] = true
  local line = string.format('CreateWebSurface("%s", %.2f, %.2f, %.2f, %.1f, %g, %g, %s)', page, x, y, z, yaw,
    shape.w, shape.h, options_text(options))
  SendClientMessage(pid, COLOR_SERVER, (on_wall and "On the wall. " or "In front of you (no wall in sight). ") .. "To make it at every start:")
  SendClientMessage(pid, COLOR_SERVER, line)
  Log(GetPlayerName(pid) .. " placed: " .. line)
end

function OnGameModeInit()
  -- the player's game knows where they look: ask it, the answer comes back in OnClientEvent
  RegisterCommand("board", function(pid)
    SendClientEvent(pid, "board.look", "board")
  end, { help = "Hang a notice board on the wall you look at (aim at where its middle goes)" })

  RegisterCommand("paint", function(pid)
    SendClientEvent(pid, "board.look", "painted")
  end, { help = "Paint the tavern's name on the wall you look at" })

  RegisterCommand("sign", function(pid)
    SendClientEvent(pid, "board.look", "sign")
  end, { help = "Hang a tavern sign on the wall you look at" })

  RegisterCommand("post", function(pid, args)
    if args == "" then return SendClientMessage(pid, COLOR_SERVER, "Usage: /post <text>") end
    table.insert(notices, { title = GetPlayerName(pid), text = args:sub(1, 200) })
    if #notices > 6 then table.remove(notices, 1) end
    for id in pairs(boards) do
      if GetWebSurfacePage(id) == "board" then SendWebSurfaceMessage(id, list()) end
    end
  end, { help = "Pin a notice on every board" })

  RegisterCommand("unpin", function()
    table.remove(notices, 1)
    for id in pairs(boards) do
      if GetWebSurfacePage(id) == "board" then SendWebSurfaceMessage(id, list()) end
    end
  end, { help = "Take the oldest notice down" })

  RegisterCommand("clearboards", function()
    for id in pairs(boards) do DestroyEntity(id) end
    boards = {}
  end, { help = "Remove every board and sign" })
end

-- a player's copy of a page is ready (it came into range, or its page loaded again): send it what it shows
function OnPlayerWebSurfaceReady(pid, id)
  if GetWebSurfacePage(id) == "board" then
    SendPlayerWebSurfaceMessage(pid, id, list())
  elseif GetWebSurfacePage(id) == "sign" or GetWebSurfacePage(id) == "painted" then
    SendPlayerWebSurfaceMessage(pid, id, { name = "The Pike and Perch", line = "Ale - Mead - Roast pike" })
  end
end

-- the use key on a board's prompt (the page shows the next notice on its own)
function OnPlayerUseWebSurface(pid, id)
  Log(GetPlayerName(pid) .. " uses the board " .. id)
end

-- the client script's answer to "board.look": "<page> x y z nx ny nz" or "<page> none"
function OnClientEvent(pid, name, payload)
  if name == "board.spot" then
    local page, spot = payload:match("^(%a+) (.*)$")
    if page then place(pid, page, spot) end
  end
end

-- what a page sends: check it like any input from a player
function OnPlayerWebSurfaceEvent(pid, id, name, payload)
  if name == "board.read" then
    local i = tonumber(payload)
    local notice = i and notices[i]
    if notice then
      SendClientMessage(pid, COLOR_SERVER, "You read the notice: " .. notice.title)
    end
  end
end

function OnPlayerSpawn(pid)
  SendClientMessage(pid, COLOR_SERVER, "Look at a wall: /board hangs a notice board there, /sign a tavern sign, /paint paints its name; /post <text> pins a notice.")
end
