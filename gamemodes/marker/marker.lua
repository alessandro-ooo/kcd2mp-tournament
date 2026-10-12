-- KCD:MP example game mode with a client half: the checkpoint run.
--
-- The server half (this file) hands every player a checkpoint - a point a few steps from the spawn - and
-- the next one when they reach it; the client half (client/marker.lua, sent to every player when they
-- join) draws the checkpoint in the world with the distance and tells the server when the player is
-- there. Everything that decides is here: which point, whether it counts, the score. The client only
-- draws and reports. Run with `--gamemode gamemodes/marker/marker.lua` (or `[gamemode] script` in
-- server.toml); the client/ folder next to this file is what the server sends (`[client] scripts`
-- names another folder).

SetGameModeText("marker")

local spawnX, spawnY, spawnZ = GetDefaultSpawn()
local COURSE = {{12, 0}, {12, 12}, {0, 12}, {-12, 0}}   -- offsets from the spawn, in metres, one after the other
local REACH = 2.5                                        -- metres: the server's own idea of "there"

local progress = {}   -- pid -> the index of the checkpoint the player is heading for
local laps = {}       -- pid -> laps finished

local function fmt(...) return string.format(...) end

local function checkpoint(i)
  local dx, dy = COURSE[i][1], COURSE[i][2]
  local x, y = spawnX + dx, spawnY + dy
  -- the height from the server's heightmap when it has one; the client puts the mark on the ground it sees anyway
  return x, y, GetTerrainHeight(x, y) or spawnZ
end

local function sendCheckpoint(pid)
  local i = progress[pid] or 1
  local x, y, z = checkpoint(i)
  -- the payload is whatever the two halves agree on: here three numbers with a comma between them
  SendClientEvent(pid, "marker", fmt("%.1f,%.1f,%.1f", x, y, z))
end

function OnGameModeInit()
  Log(fmt("marker on %s: %d checkpoints around the spawn %.1f %.1f", GetLevel(), #COURSE, spawnX, spawnY))
end

function OnPlayerSpawn(pid)
  progress[pid] = 1
  laps[pid] = laps[pid] or 0
  GameText(pid, "Run the checkpoints", 2000)
  sendCheckpoint(pid)
end

function OnPlayerDisconnect(pid)
  progress[pid] = nil
  laps[pid] = nil
end

function OnClientEvent(pid, name, payload)
  if name ~= "marker_reached" then return end
  -- the client says it is there; the server checks before it counts (a client script is the player's own)
  local i = progress[pid]
  if not i then return end
  local px, py = GetPlayerPos(pid)
  local x, y = checkpoint(i)
  if not px or (px - x) ^ 2 + (py - y) ^ 2 > REACH ^ 2 then
    sendCheckpoint(pid)   -- not there: the same checkpoint again
    return
  end
  if i == #COURSE then
    laps[pid] = laps[pid] + 1
    progress[pid] = 1
    GameText(pid, fmt("Lap %d!", laps[pid]), 2500)
    SendClientMessageToAll(COLOR_SERVER, fmt("%s finished lap %d", GetPlayerName(pid), laps[pid]))
  else
    progress[pid] = i + 1
    GameText(pid, fmt("Checkpoint %d of %d", i, #COURSE), 1500)
  end
  sendCheckpoint(pid)
end

function OnPlayerCommandText(pid, cmd, args)
  if cmd == "help" then
    SendClientMessage(pid, COLOR_SERVER, "marker: /laps shows the score; the checkpoint is drawn by the client script this server sends")
    return false
  elseif cmd == "laps" then
    local lines = {}
    for _, other in ipairs(GetPlayers()) do
      lines[#lines + 1] = fmt("%s %d", GetPlayerName(other), laps[other] or 0)
    end
    SendClientMessage(pid, COLOR_SERVER, "laps: " .. (#lines > 0 and table.concat(lines, ", ") or "nobody yet"))
    return true
  end
  return false
end
