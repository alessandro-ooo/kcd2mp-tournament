-- Example: a scoreboard of your own, drawn by a web page, with columns the mode chooses.
--
-- ui/ui.toml gives the scoreboard to the frame "board" for every player and opens it in toggle mode (Tab opens it, Tab or Esc
-- closes it, and the page gets the mouse meanwhile). The mode adds three columns with SetScoreboardColumns; each cell is the
-- player state of the column's key (SetPlayerState), so the board changes by itself when the mode sets a new value.
--
-- Run it with [gamemode] script = "sdk/web/examples/scoreboard/scoreboard.lua", or copy this folder into gamemodes/.

SetGameModeText("scoreboard example")

local joinedAt = {}   -- pid -> GetServerTime() at the spawn

local function bump(pid, key)
  SetPlayerState(pid, key, (tonumber(GetPlayerState(pid, key)) or 0) + 1)
end

function OnGameModeInit()
  SetScoreboardColumns({
    { key = "kills", label = "Kills", align = "right", format = "number", width = 90 },
    { key = "deaths", label = "Deaths", align = "right", format = "number", width = 90 },
    { key = "played", label = "Played", align = "right", format = "time", width = 110 },
  })

  -- the time each player has been here, in seconds, once every ten seconds
  SetTimer(function()
    local now = GetServerTime()
    for pid, at in pairs(joinedAt) do
      SetPlayerState(pid, "played", math.floor((now - at) / 1000))
    end
  end, 10000, true)
end

function OnPlayerSpawn(pid)
  if joinedAt[pid] == nil then
    joinedAt[pid] = GetServerTime()
    SetPlayerState(pid, "kills", 0)
    SetPlayerState(pid, "deaths", 0)
    SetPlayerState(pid, "played", 0)
    SendClientMessage(pid, COLOR_SERVER, "Press Tab to open the scoreboard - it is a web page of this server.")
  end
end

function OnPlayerDeath(pid, attacker)
  bump(pid, "deaths")
  if attacker >= 0 and attacker ~= pid and IsPlayerConnected(attacker) then
    bump(attacker, "kills")
  end
end

function OnPlayerDisconnect(pid, reason)
  joinedAt[pid] = nil
end
