-- KCD:MP game mode: duel_arena.
--
-- Players queue with /duel; two at a time are healed, put on the two arena marks facing each
-- other and released after a countdown. Nobody else can be hurt: every hit outside the running
-- duel is cancelled in OnPlayerDamage. The first to die (a bleed-out counts) loses; the winner is
-- announced, scored and sent back to the lobby healed, the loser respawns there ([combat]
-- respawn_seconds). Run with `--gamemode gamemodes/duel_arena.lua` (or `[gamemode] script` in
-- server.toml); the API is documented at https://docs.kcd-mp.com.

SetGameModeText("duel_arena")

local spawnX, spawnY, spawnZ, spawnYaw = GetDefaultSpawn()
-- The arena: two marks 3 m either side of the server's spawn point, facing each other (yaw 0 =
-- facing +Y, counter-clockwise: 270 looks along +X, 90 along -X). Move them with /arena.
local ARENA = {
  a = {x = spawnX - 3, y = spawnY, z = spawnZ, yaw = 270},
  b = {x = spawnX + 3, y = spawnY, z = spawnZ, yaw = 90},
}
local LOBBY = {x = spawnX, y = spawnY + 8, z = spawnZ, yaw = 180}   -- where everyone waits and respawns
local COUNTDOWN = 3          -- seconds between the placement and "Fight!"
local DUEL_SECONDS = 180     -- a duel longer than this is a draw
local WINNER_STAYS = true    -- the winner is queued again at the front

-- Progression: the duelists stay as equal as they came - the XP the game awards a player (a kill, a hit, a book) counts
-- for nothing here. The rule - change it here:
local PROGRESS = {
  xp_rate = 0,   -- every XP the game awards a player counts this many times: 0 none, 1 as the game gives it, 2 double ...
}

-- The camera: duels stay in first person, so nobody has the view from behind. Set at every join. The rule - change it here:
local CAMERA = {
  third_person = "off",   -- "off": first person only; "allow": a player switches with their third-person key (F3, changeable in the launcher's options); "force": always third person
  in_fights = false,      -- false: first person while fighting with a sword, an axe or fists (only matters once third_person is changed to "allow" or "force")
  when_aiming = false,    -- false: first person while a bow, a crossbow or a gun is drawn (the same)
  crosshair = false,      -- false: no aiming dot in third person with a bow, a crossbow or a gun (the same; first person never has one)
}

local queue = {}             -- pids waiting, in order
local duel = nil             -- {a = pid, b = pid, startedAt = ms, live = bool, timer = id}
local scores = {}            -- pid -> {wins = n, losses = n}

local function fmt(...) return string.format(...) end

local function score(pid)
  scores[pid] = scores[pid] or {wins = 0, losses = 0}
  return scores[pid]
end

local function inQueue(pid)
  for i, p in ipairs(queue) do
    if p == pid then return i end
  end
  return nil
end

local function removeFromQueue(pid)
  local i = inQueue(pid)
  if i then table.remove(queue, i) end
end

local function lobbySpot(pid)
  return LOBBY.x + 1.5 * (pid % 8), LOBBY.y + 1.5 * (pid // 8), LOBBY.z, LOBBY.yaw
end

local function toLobby(pid)
  if IsPlayerInWorld(pid) and not IsPlayerDead(pid) then
    SetPlayerPos(pid, lobbySpot(pid))
  end
end

local function opponent(pid)
  if not duel then return nil end
  if duel.a == pid then return duel.b end
  if duel.b == pid then return duel.a end
  return nil
end

local function endDuel(winner, loser, how)
  if not duel then return end
  if duel.timer then KillTimer(duel.timer) end
  local finished = duel
  duel = nil
  EndFight(finished.a, finished.b)   -- the lock drops on both screens (a death ended it already)
  if winner then
    local w, l = score(winner), score(loser)
    w.wins, l.losses = w.wins + 1, l.losses + 1
    SendClientMessageToAll(COLOR_YELLOW, fmt("%s beat %s (%s). %s: %d-%d, %s: %d-%d",
      GetPlayerName(winner), GetPlayerName(loser), how, GetPlayerName(winner), w.wins, w.losses, GetPlayerName(loser), l.wins, l.losses))
    ShowObjectiveEventForAll("Duel", fmt("%s beat %s", GetPlayerName(winner), GetPlayerName(loser)), OBJECTIVE_DONE)   -- the game's own banner
    if IsPlayerConnected(winner) then
      HealPlayer(winner)
      toLobby(winner)
      if WINNER_STAYS then table.insert(queue, 1, winner) end
    end
  else
    SendClientMessageToAll(COLOR_YELLOW, fmt("%s and %s: a draw (%s)", GetPlayerName(finished.a) or "?", GetPlayerName(finished.b) or "?", how))
    ShowObjectiveEventForAll("Duel", "A draw", OBJECTIVE_FAILED)
    for _, pid in ipairs({finished.a, finished.b}) do
      if IsPlayerConnected(pid) then
        HealPlayer(pid)
        toLobby(pid)
      end
    end
  end
end

local function startDuel(a, b)
  duel = {a = a, b = b, startedAt = GetServerTime(), live = false}
  for pid, mark in pairs({[a] = ARENA.a, [b] = ARENA.b}) do
    HealPlayer(pid)
    SetPlayerPos(pid, mark.x, mark.y, mark.z, mark.yaw)
  end
  SendClientMessageToAll(COLOR_YELLOW, fmt("Duel: %s vs %s", GetPlayerName(a), GetPlayerName(b)))
  ShowObjectiveEventForAll("Duel", fmt("%s vs %s", GetPlayerName(a), GetPlayerName(b)), OBJECTIVE_NEW)   -- the game's own banner
  local left = COUNTDOWN
  duel.timer = SetTimer(function()
    if not duel then return end
    if left > 0 then
      ShowInfoText(a, tostring(left), 900, 2, true)   -- the countdown in the game's info line, not the chat
      ShowInfoText(b, tostring(left), 900, 2, true)
      left = left - 1
    else
      KillTimer(duel.timer)
      duel.timer = nil
      duel.live = true
      duel.startedAt = GetServerTime()
      StartFight(a, b)   -- both clients let the lock-on pick the other from here (tick() keeps it alive)
      ShowInfoText(a, "Fight!", 1500, 3, true)
      ShowInfoText(b, "Fight!", 1500, 3, true)
    end
  end, 1000, true)
end

-- Once a second: pair the queue's head when the arena is free, call time on a long duel.
local function tick()
  if duel then
    if duel.live and GetServerTime() - duel.startedAt > DUEL_SECONDS * 1000 then
      endDuel(nil, nil, "time")
    elseif duel.live then
      StartFight(duel.a, duel.b)   -- two duelists circling without a blow must not lose the lock to [combat] fight_timeout
    end
    return
  end
  while #queue >= 2 do
    local a, b = queue[1], queue[2]
    if not IsPlayerInWorld(a) or IsPlayerDead(a) then
      table.remove(queue, 1)
    elseif not IsPlayerInWorld(b) or IsPlayerDead(b) then
      table.remove(queue, 2)
    else
      table.remove(queue, 1)
      table.remove(queue, 1)
      startDuel(a, b)
      return
    end
  end
end

function OnGameModeInit()
  Log(fmt("duel_arena on %s: marks %.1f %.1f and %.1f %.1f, lobby %.1f %.1f", GetLevel(), ARENA.a.x, ARENA.a.y, ARENA.b.x, ARENA.b.y, LOBBY.x, LOBBY.y))
  SetStoryQuests(false)   -- the game's own quests stay asleep in the players' games; true lets them run (they can take a player's things)
  SetXPRate(PROGRESS.xp_rate)
  SetCarrying(false)      -- nobody grabs or carries a body here (the arena is for the duel); a mode's own orders would still work
  SetTimer(tick, 1000, true)
end

function OnPlayerConnect(pid)
  SetPlayerThirdPerson(pid, CAMERA.third_person, CAMERA.in_fights, CAMERA.when_aiming, CAMERA.crosshair)
  SendClientMessage(pid, COLOR_SERVER, fmt("Welcome to the duel arena, %s. /duel to queue, /leave to step out, /score for the tally, /help for the rest.", GetPlayerName(pid)))
  SendClientMessageToAll(COLOR_SERVER, GetPlayerName(pid) .. " joined")
end

function OnPlayerRequestSpawn(pid)
  SetSpawnInfo(pid, lobbySpot(pid))
  return true
end

function OnPlayerSpawn(pid)
  Log(fmt("%s spawned (%s)", GetPlayerName(pid), inQueue(pid) and "queued" or "lobby"))
end

function OnPlayerText(pid, text)
  return true
end

function OnPlayerCommandText(pid, cmd, args)
  if cmd == "help" then
    SendClientMessage(pid, COLOR_SERVER, "commands: /duel, /leave, /score, /queue, /arena [x y z yaw], /anim [name|stop] (the arena sets the fights: /fight and /peace are not needed)")
    return true
  elseif cmd == "anim" then
    -- /anim <name>: a bow before the bout, a cheer after it - what the wheel on G plays; /anim alone lists them, /anim stop
    -- ends a dance. The server's rules answer through PlayPlayerEmote's reason (no emote with a weapon out or in a fight)
    local name = args:match("^(%S+)")
    if not name then
      SendClientMessage(pid, COLOR_SERVER, "anims: " .. table.concat(GetEmotes(), ", ") .. " - /anim <name>, /anim stop")
    elseif name:lower() == "stop" then
      if not StopPlayerEmote(pid) then SendClientMessage(pid, COLOR_SERVER, "No animation is playing.") end
    else
      local ok, why = PlayPlayerEmote(pid, name)
      if not ok then SendClientMessage(pid, COLOR_RED, why) end
    end
    return true
  elseif cmd == "duel" then
    if opponent(pid) then
      SendClientMessage(pid, COLOR_RED, "you are in the arena")
    elseif inQueue(pid) then
      SendClientMessage(pid, COLOR_SERVER, fmt("you are number %d in the queue", inQueue(pid)))
    else
      queue[#queue + 1] = pid
      SendClientMessage(pid, COLOR_SERVER, fmt("queued (%d waiting)", #queue))
    end
    return true
  elseif cmd == "leave" then
    if opponent(pid) then
      endDuel(opponent(pid), pid, "forfeit")
    elseif inQueue(pid) then
      removeFromQueue(pid)
      SendClientMessage(pid, COLOR_SERVER, "left the queue")
    else
      SendClientMessage(pid, COLOR_SERVER, "you were not queued")
    end
    return true
  elseif cmd == "score" then
    local lines = {}
    for _, id in ipairs(GetPlayers()) do
      local s = scores[id]
      if s then lines[#lines + 1] = fmt("%s %d-%d", GetPlayerName(id), s.wins, s.losses) end
    end
    SendClientMessage(pid, COLOR_SERVER, #lines > 0 and table.concat(lines, ", ") or "no duels yet")
    return true
  elseif cmd == "queue" then
    local names = {}
    for _, id in ipairs(queue) do names[#names + 1] = GetPlayerName(id) end
    SendClientMessage(pid, COLOR_SERVER, fmt("%s%s", duel and fmt("fighting: %s vs %s; ", GetPlayerName(duel.a), GetPlayerName(duel.b)) or "",
      #names > 0 and "queue: " .. table.concat(names, ", ") or "queue empty"))
    return true
  elseif cmd == "arena" then
    -- moves the arena to a point (the marks 3 m either side of it along its facing); sscanf reads the three
    -- numbers and the optional yaw, or says what is wrong with them
    local x, y, z, yaw = sscanf(args, "ffff?")
    if x == false then
      SendClientMessage(pid, COLOR_SERVER, fmt("arena at %.1f %.1f (usage: /arena x y z [yaw])", (ARENA.a.x + ARENA.b.x) / 2, ARENA.a.y))
      return true
    end
    yaw = yaw or 0
    local r = math.rad(yaw)
    local dx, dy = -math.sin(r) * 3, math.cos(r) * 3   -- 3 m along the facing
    ARENA.a = {x = x - dx, y = y - dy, z = z, yaw = yaw}
    ARENA.b = {x = x + dx, y = y + dy, z = z, yaw = (yaw + 180) % 360}
    SendClientMessageToAll(COLOR_SERVER, fmt("%s moved the arena to %.1f %.1f", GetPlayerName(pid), x, y))
    return true
  end
  return false
end

-- Only the two in a live duel can hurt each other; everything else is cancelled.
function OnPlayerDamage(pid, attacker, damage, zone, part, weapon, dtype)
  if not duel or not duel.live then return 0 end
  if opponent(pid) ~= attacker then return 0 end
  return damage
end

function OnPlayerInjury(pid, attacker, part)
  SendClientMessage(pid, COLOR_RED, "your " .. (GetBodyPartName(part):gsub("_", " ")) .. " is injured")
end

function OnPlayerDeath(pid, attacker)
  local other = opponent(pid)
  if other then
    endDuel(other, pid, attacker == other and "a kill" or "bled out")
  end
end

function OnPlayerDisconnect(pid, reason)
  removeFromQueue(pid)
  local other = opponent(pid)
  if other then
    endDuel(other, pid, "left")
  end
  SendClientMessageToAll(COLOR_SERVER, fmt("%s left (%s)", GetPlayerName(pid), reason))
end
