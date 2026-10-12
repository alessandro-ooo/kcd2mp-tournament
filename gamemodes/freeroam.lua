-- KCD:MP flagship game mode: freeroam.
--
-- Everyone spawns around the server's spawn point in the configured outfit, chat is global; the
-- testing commands (/give, /tp, /horse ...) are the server's built-ins ([commands] in server.toml). Run with `KcdMp.Server --gamemode gamemodes/freeroam.lua` (or
-- `[gamemode] script = "gamemodes/freeroam.lua"` in server.toml). The API is documented at
-- https://docs.kcd-mp.com; the prelude embedded in the server defines every function used here.
-- Players gain XP as the game gives it; /skills shows their main level, stats and skills, an admin's /setlevel, /givexp,
-- /perk, /perkpoints and /xprate change them.

SetGameModeText("freeroam")

local spawnX, spawnY, spawnZ, spawnYaw = GetDefaultSpawn()
local ORPHAN_HORSE_SECONDS = 600   -- a horse nobody controls for this long is removed
local spawnZone                    -- a circle around the spawn: the greeting shows on entering it
local actorWalks                   -- /actor: the demo actors' patrol corners by entity id (made on the first one)

local function fmt(...) return string.format(...) end

-- The camera: players can look at themselves from behind, through the game's own chase camera (no camera mod needed). Set at
-- every join. The rule - change it here:
local CAMERA = {
  third_person = "allow",   -- "off": first person only; "allow": a player switches with their third-person key (F3, changeable in the launcher's options); "force": always third person
  in_fights = true,         -- false: first person while fighting with a sword, an axe or fists
  when_aiming = true,       -- false: first person while a bow, a crossbow or a gun is drawn
  crosshair = true,         -- false: no aiming dot in third person with a bow, a crossbow or a gun (first person never has one)
}

-- The voice levels: a player switches between them with the voice level key (left Ctrl, changeable in the launcher's options), in
-- this order, and the HUD shows the one they picked. As many as you like (16 at most); a level without a range carries as far
-- as the server's [voice] range (25 m). levels = {} turns the key off. The rule - change it here:
local VOICE = {
  levels = {
    { name = "Whisper", range = 3 },
    { name = "Normal" },
    { name = "Shout", range = 50 },
  },
  default = "Normal",   -- where every player starts (a name or a number)
  occlusion = 1.0,      -- how much walls muffle a voice: 0 = never, 1 = like the game's own sounds, up to 2
}

-- Accounts, when the owner connected a database ([gamemode.database] in server.toml): a player claims their name with
-- /register <password> and proves it with /login <password>; a logged-in player is put back where they left, and their
-- visits are counted. Everything about them lives in this mode's own table - the server itself remembers nobody.
-- Without a database the two commands say so and the mode runs on as it is.
local db = GetDatabase()
local accounts = {}   -- pid -> { registered = the name has a row, logged = proved this session }

local function accounts_init()
  if not db then Log("accounts: no [gamemode.database] on this server, /register and /login are off") return end
  SetSecretCommand("register")   -- the clients mask the password as it is typed and keep the line out of their history
  SetSecretCommand("login")
  local _, _, err = db:ExecuteSync([[
    CREATE TABLE IF NOT EXISTS freeroam_players (
      name VARCHAR(24) PRIMARY KEY,
      password VARCHAR(200) NOT NULL,
      visits INTEGER NOT NULL DEFAULT 0,
      x DOUBLE PRECISION, y DOUBLE PRECISION, z DOUBLE PRECISION, yaw DOUBLE PRECISION)]])
  if err then Log("accounts: the table could not be made: " .. err) db = nil return end
  Log("accounts: on (" .. db.driver .. ")")
end

local function accounts_connect(pid)
  if not db then return end
  accounts[pid] = { registered = false, logged = false }
  db:Query("SELECT visits FROM freeroam_players WHERE name = @n", { n = GetPlayerName(pid):lower() }, function(rows, err)
    if err or not IsPlayerConnected(pid) or not accounts[pid] then return end
    if #rows > 0 then
      accounts[pid].registered = true
      SendClientMessage(pid, COLOR_SERVER, fmt("This name is registered (visit %d): /login <password> to continue where you left.", rows[1].visits + 1))
    else
      SendClientMessage(pid, COLOR_SERVER, "/register <password> keeps this name yours on this server.")
    end
  end)
end

local function accounts_command(pid, cmd, password)
  if not db then SendClientMessage(pid, COLOR_SERVER, "This server keeps no accounts.") return true end
  local account = accounts[pid]
  if not account then return true end
  local name = GetPlayerName(pid):lower()
  if cmd == "register" then
    if account.registered then SendClientMessage(pid, COLOR_SERVER, "This name is registered already: /login <password>.") return true end
    if #password < 4 or password:find(" ") then SendClientMessage(pid, COLOR_SERVER, "Usage: /register <password> (4 characters or more, no spaces).") return true end
    account.registered = true   -- before the answer comes: a second /register in the same second is refused
    db:Execute("INSERT INTO freeroam_players (name, password, visits) VALUES (@n, @p, 1)", { n = name, p = HashPassword(password) }, function(_, _, err)
      if err then account.registered = false Log("accounts: register failed: " .. err) return end
      account.logged = true
      SendClientMessage(pid, COLOR_SERVER, "Registered: this name is yours now. Next time, /login <password>.")
    end)
  else
    if account.logged then SendClientMessage(pid, COLOR_SERVER, "You are logged in already.") return true end
    if not account.registered then SendClientMessage(pid, COLOR_SERVER, "This name is not registered: /register <password> claims it.") return true end
    for other, a in pairs(accounts) do   -- two players may share a name; its account is one player's at a time
      if other ~= pid and a.logged and GetPlayerName(other):lower() == name then
        SendClientMessage(pid, COLOR_SERVER, "Another player is logged in under this name.") return true
      end
    end
    db:Query("SELECT password, x, y, z, yaw FROM freeroam_players WHERE name = @n", { n = name }, function(rows, err)
      if err or not IsPlayerConnected(pid) then return end
      if #rows == 0 or not VerifyPassword(password, rows[1].password) then SendClientMessage(pid, COLOR_SERVER, "Wrong password.") return end
      account.logged = true
      local row = rows[1]
      db:Execute("UPDATE freeroam_players SET visits = visits + 1 WHERE name = @n", { n = name })
      if row.x and IsPlayerInWorld(pid) then SetPlayerPos(pid, row.x, row.y, row.z, row.yaw) end
      SendClientMessage(pid, COLOR_SERVER, "Logged in. Welcome back, " .. GetPlayerName(pid) .. ".")
    end)
  end
  return true
end

local function accounts_disconnect(pid)
  local account = accounts[pid]
  accounts[pid] = nil
  if not db or not account or not account.logged or not IsPlayerInWorld(pid) then return end
  local x, y, z = GetPlayerPos(pid)   -- read now: the write runs later, on another thread
  db:Execute("UPDATE freeroam_players SET x = @x, y = @y, z = @z, yaw = @yaw WHERE name = @n",
    { x = x, y = y, z = z, yaw = GetPlayerYaw(pid), n = GetPlayerName(pid):lower() })
end

-- Progression: the game reports each player's stats, skills, perks and the main level to the server (GetPlayerProgress); this
-- mode lets them gain XP as the game gives it and keeps nothing of it - a player starts over at every join (BasicRP saves
-- it with the character). The server gives nobody XP unless a mode allows it. The rule - change it here:
local PROGRESS = {
  xp_rate = 1,   -- every XP the game awards a player (a kill, a hit, a book, a distance walked) counts this many times: 0 none, 1 as the game gives it
}

-- Pulling a rider off a horse: the game's own take-down move (the "Pull down" prompt on a rider, for a player on foot with a
-- weapon's reach), played by the two games and seen by everyone around. OFF until you switch it on - here, or in the game with an
-- admin's /pulldowns on. The server checks the reach and the horse's pace, pvp, teams and parties; the chance it works is this
-- mode's. An admin's /pulldown <victim> [puller] does it on order, whatever the rules - the way to see it alone.
local PULLDOWN = {
  enabled = false,   -- true: every player may pull riders down (the prompt shows); false: nobody may
  chance = 1.0,      -- 0..1: the chance a pull-down throws the rider off (the failed pair plays otherwise and the rider stays up)
}

-- Carrying: the game's own grab, carry over the shoulder and put-down, seen by everyone - the "grab" prompt on a body that lies
-- down (a dead character's, a knocked-out player's or NPC's). OFF until you switch it on - here, or in the game with an admin's
-- /carrying on. The rules are this mode's; an admin's /ko knocks a player out, /wake wakes them, /carry <player> carries one on
-- order and /putdown puts what an admin carries down - the way to see it alone.
local CARRY = {
  enabled = false,   -- true: the "grab" prompt shows on bodies that lie down; false: nobody grabs
  range = 3,         -- metres a player may stand from the body when they reach for it
  speed = 2.4,       -- metres per second a carrier walks (at most 4)
  corpses = true,    -- the bodies of the dead - an NPC's, or a dead player's (the server's [combat] corpse_seconds keeps it) - can be carried
  players = true,    -- ... a knocked-out player
  actors = true,     -- ... a knocked-out NPC actor
}

-- Carry items: sacks, baskets, buckets and the like carried in the hands the way the game's own people carry them - the game's pickup,
-- its carry walk (no running) and its put-down (E), seen by everyone. A carry item lies in the world where an admin's /carryitem laid
-- it or where a player put it down; its "Pick up" prompt works while this table (or an admin's /carryitems on) allows it. Nothing lies
-- around until an admin lays something: /carryitem <kind> lays one in front of you, /carryitem <kind> <player> puts one in that
-- player's hands, /clearitems takes them all away. The kinds are the names below or any item name of the game's.
local ITEMS = {
  enabled = true,   -- true: the "Pick up" prompt shows on carry items; false: only the mode's orders (and /carryitem ... <player>) carry them
  range = 2.5,      -- metres a player may stand from the item when they reach for it
  kinds = {         -- /carryitem's short names for the game's items
    sack = "mlynaruvUcen_sackcarryable", flour = "mlynaruvUcen_sackcarryable", scrap = "kejkliri_sackcarryable",
    bucket = "waterBucket", milk = "milkBucket", basket = "basket_b_apples", bread = "basket_b_bread", hay = "basket_b_hay",
    coal = "basket_b_coal", stones = "basket_b_stones", sticks = "basket_full_sticks", firewood = "basket_full_wood",
    laundry = "laundryBasket", crate = "crate_with_silver",
    shovel = "shovel", axe = "lumberjack_axe", rod = "fishing_rod",
    hammer = "normalHammer", jug = "jug_pewter_small_copper", tankard = "wooden_tankard",   -- (held in the hand: E held puts them down)
    lantern = "lamp_tool", lamp = "lamp_toolFancy", torch = "torch_tool",                   -- (in the left hand: E held puts them down)
  },
}

-- Pickpocketing: the game's own "Rob" on another player's body - held E on the prompt, the charge, the tile game - played on the thief's
-- screen over a few things the victim carries and does not wear; what the minigame takes is moved by the server. OFF until you switch it
-- on - here, or in the game with an admin's /pickpocket on. The server checks the reach, who is busy, the cooldown and that nobody is
-- fighting; the rules below are this mode's - change them here. A robbed player is not told and a caught thief has no consequence here:
-- add an OnPlayerPickpocketEnd for that (BasicRP has one).
local POCKET = {
  enabled = false,     -- true: the "Rob" prompt shows on other players' bodies; false: nobody robs
  range = 3,           -- metres the thief may stand from the body
  cooldown = 30,       -- seconds before the same thief may rob the same player again
  max_items = 8,       -- stacks the pockets offer at most (the game's wheel shows 11 at most)
  max_stack = 5,       -- the most of one thing the pockets offer
  behind_only = false, -- true: only from behind (the game's own roll punishes the front anyway)
  money = false,       -- true: a tenth of the victim's purse (up to 100 Groschen) is in the pockets too
}

-- the names the game's menus show for the stats and skills whose own names differ
local LABELS = { mainlevel = "main level", storyprogress = "story progress", horse_riding = "horsemanship", fencing = "warfare",
  weapon_sword = "swords", weapon_large = "polearms", weapon_unarmed = "unarmed", weapon_shield = "shield", weapon_dagger = "dagger" }
local STAT_ORDER = { "strength", "agility", "vitality", "speech" }   -- /skills' stats line; the main level has a line of its own

local function label(name) return LABELS[name] or (name:gsub("_", " ")) end

-- "2 perk points" for points above 0, else nil
local function perk_points(points)
  points = tonumber(points) or 0
  if points <= 0 then return nil end
  return fmt("%d perk point%s", points, points == 1 and "" or "s")
end

-- a name the admin typed for the main level (the game works it out, so no command sets it)
local MAIN_LEVEL_NAMES = { mainlevel = true, main_level = true, main = true, level = true }
local function is_main_level(name) return MAIN_LEVEL_NAMES[(name:lower():gsub("[%s%-]", "_"))] == true end
-- warfare (the game's fencing) is worked out from the weapon skills too: set or give XP to those instead
local WARFARE_NAMES = { warfare = true, fencing = true }
local function is_warfare(name) return WARFARE_NAMES[(name:lower():gsub("[%s%-]", "_"))] == true end
local WARFARE_REFUSAL = "Warfare follows the weapon skills (swords, heavy weapons, polearms, unarmed, marksmanship) - set those. /perkpoints sets its points."

-- a command's arguments that would not parse: no such player, or the usage
local function bad_args(pid, reason, line)
  SendClientMessage(pid, COLOR_RED, tostring(reason):find("^no player") and "No such player." or "Usage: " .. line)
  return true
end

-- "warfare 8 (2 perk points)" for a stat or skill of GetPlayerProgress
local function progress_entry(name, v)
  local points = perk_points(v.points)
  return fmt("%s %d", label(name), v.level) .. (points and " (" .. points .. ")" or "")
end

-- /skills: the main level first, then the player's stats and skills as their game last reported them, the perk points not
-- spent yet beside the ones that have any; /skills <name> one of them with its XP
local function show_skills(pid, name)
  if name ~= "" then
    local level, xp, need = GetPlayerStat(pid, name), nil, nil
    if level > 0 then
      xp, need = GetPlayerStatXP(pid, name)
    else
      level = GetPlayerSkill(pid, name)
      if level > 0 then xp, need = GetPlayerSkillXP(pid, name) end
    end
    local points = perk_points(GetPlayerPerkPoints(pid, name))
    if level == 0 then
      SendClientMessage(pid, COLOR_RED, "No stat or skill of that name, or your game has not reported it yet: " .. name)
    elseif (need or 0) > 0 then
      SendClientMessage(pid, COLOR_SERVER, fmt("%s: level %d, %.0f of %.0f XP to the next", name, level, xp, need) .. (points and ", " .. points or ""))
    else
      SendClientMessage(pid, COLOR_SERVER, fmt("%s: level %d", name, level) .. (points and ", " .. points or ""))
    end
    return
  end
  local progress = GetPlayerProgress(pid)
  local main, stats, skills, names = progress and progress.stats.mainlevel, {}, {}, {}
  for _, stat in ipairs(STAT_ORDER) do
    local v = progress and progress.stats[stat]
    if v then stats[#stats + 1] = progress_entry(stat, v) end
  end
  for skill in pairs(progress and progress.skills or {}) do names[#names + 1] = skill end
  table.sort(names, function(a, b) return label(a) < label(b) end)
  for _, skill in ipairs(names) do skills[#skills + 1] = progress_entry(skill, progress.skills[skill]) end
  if not main and #stats == 0 and #skills == 0 then
    SendClientMessage(pid, COLOR_SERVER, "Your game has not reported your skills yet - it does a few seconds after you spawn.")
    return
  end
  if main then
    local points = perk_points(main.points)
    SendClientMessage(pid, COLOR_SERVER, fmt("Main level: %d", main.level) .. (points and " (" .. points .. ")" or ""))
  end
  if #stats > 0 then SendClientMessage(pid, COLOR_SERVER, "Stats: " .. table.concat(stats, ", ")) end
  for i = 1, #skills, 10 do   -- ten a line: the chat's width
    SendClientMessage(pid, COLOR_WHITE, (i == 1 and "Skills: " or "  ") .. table.concat(skills, ", ", i, math.min(i + 9, #skills)))
  end
end

-- /skills for everyone; the admin's /setlevel <player> <stat|skill> <level> [xp] (level and XP set as given, lowering too;
-- the main level is the game's own to work out and is refused), /givexp <player> <stat|skill> <xp> (the game's way: the
-- level-up notice, the perk points), /perk <player> add|remove <perk> (a GUID, or a name from the perks list of the scripting
-- docs), /perkpoints <player> <stat|skill|mainlevel> <n> (the perk points not spent yet) and /xprate [rate]. The server resolves
-- the names (warfare for fencing ...)
function ProgressCommand(pid, cmd, args)
  if cmd == "skills" then show_skills(pid, args:match("^%s*(.-)%s*$")) return true end
  if cmd ~= "setlevel" and cmd ~= "givexp" and cmd ~= "perk" and cmd ~= "perkpoints" and cmd ~= "xprate" then return false end
  if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/" .. cmd .. " is for admins") return true end
  if cmd == "setlevel" then
    local target, name, level, xp = sscanf(args, "usdf?")
    if target == false then return bad_args(pid, name, "/setlevel <player> <stat|skill> <level> [xp]") end
    if is_main_level(name) then
      SendClientMessage(pid, COLOR_RED, "The main level cannot be set - the game works it out from the stats and skills. Set those, or use /perkpoints for its points.")
      return true
    end
    if is_warfare(name) then SendClientMessage(pid, COLOR_RED, WARFARE_REFUSAL) return true end
    if not (SetPlayerStat(target, name, level, xp) or SetPlayerSkill(target, name, level, xp)) then
      SendClientMessage(pid, COLOR_RED, "Not a stat or skill, or not a level from 0 to 30 - /skills lists the names.")
      return true
    end
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s is level %d now.", GetPlayerName(target), name, level))
    if target ~= pid then SendClientMessage(target, COLOR_SERVER, fmt("%s set your %s to level %d.", GetPlayerName(pid), name, level)) end
  elseif cmd == "givexp" then
    local target, name, xp = sscanf(args, "usf")
    if target == false then return bad_args(pid, name, "/givexp <player> <stat|skill> <xp>") end
    if is_main_level(name) then
      SendClientMessage(pid, COLOR_RED, "The main level takes no XP of its own - give XP to a stat or a skill.")
      return true
    end
    if is_warfare(name) then SendClientMessage(pid, COLOR_RED, WARFARE_REFUSAL) return true end
    if xp <= 0 or xp > 100000 or not (AddPlayerStatXP(target, name, xp) or AddPlayerSkillXP(target, name, xp)) then
      SendClientMessage(pid, COLOR_RED, "Not a stat or skill, or not an XP amount above 0 and up to 100000 - /skills lists the names.")
      return true
    end
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: %g XP in %s.", GetPlayerName(target), xp, name))
  elseif cmd == "perk" then
    local target, how, perk = sscanf(args, "usz")
    if target == false then return bad_args(pid, how, "/perk <player> add|remove <perk>") end
    how = how:lower()
    if how ~= "add" and how ~= "remove" then return bad_args(pid, "", "/perk <player> add|remove <perk>") end
    local ok
    if how == "add" then ok = AddPlayerPerk(target, perk) else ok = RemovePlayerPerk(target, perk) end
    if not ok then
      SendClientMessage(pid, COLOR_RED, "No such perk: " .. perk .. " - a GUID, or a name from the list at docs.kcd-mp.com/reference/perks/")
      return true
    end
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s %s.", GetPlayerName(target), GetPerkName(perk) or perk, how == "add" and "added" or "taken away"))
  elseif cmd == "perkpoints" then
    local target, name, points = sscanf(args, "usd")
    if target == false then return bad_args(pid, name, "/perkpoints <player> <stat|skill|mainlevel> <points>") end
    if points < 0 or not SetPlayerPerkPoints(target, name, points) then
      SendClientMessage(pid, COLOR_RED, "Not a stat, a skill or mainlevel, or not a number of perk points the game takes (0 or more) - /skills lists the names.")
      return true
    end
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s has %d perk point%s now.", GetPlayerName(target), name, points, points == 1 and "" or "s"))
    if target ~= pid then SendClientMessage(target, COLOR_SERVER, fmt("%s set your %s perk points to %d.", GetPlayerName(pid), name, points)) end
  else
    local rate, why = sscanf(args, "f?")
    if rate == false then return bad_args(pid, why, "/xprate [rate from 0 to 100]") end
    if rate == nil then
      SendClientMessage(pid, COLOR_SERVER, fmt("The XP rate is %g - /xprate <rate from 0 to 100> changes it.", GetXPRate()))
      return true
    end
    if rate < 0 or rate > 100 then SendClientMessage(pid, COLOR_RED, "The XP rate is from 0 to 100.") return true end
    SetXPRate(rate)
    Log(fmt("freeroam: %s set the XP rate to %g", GetPlayerName(pid), rate))
    SendClientMessage(pid, COLOR_SERVER, fmt("The XP rate is %g now.", rate))
  end
  return true
end

function OnGameModeInit()
  Log(fmt("freeroam on %s: spawn %.1f %.1f %.1f yaw %.0f, %d slots", GetLevel(), spawnX, spawnY, spawnZ, spawnYaw, GetMaxPlayers()))
  SetStoryQuests(false)   -- the game's own quests stay asleep in the players' games; true lets them run (they can take a player's things)
  SetXPRate(PROGRESS.xp_rate)
  SetCarrying(CARRY.enabled, CARRY)   -- the grab off by default: the table above (or an admin's /carrying on) switches it on
  SetItemCarrying(ITEMS.enabled, ITEMS)   -- the "Pick up" prompt on carry items: the ITEMS table (or an admin's /carryitems on|off)
  SetPickpocketing(POCKET.enabled, POCKET)   -- pickpocketing off by default: the POCKET table (or an admin's /pickpocket on) switches it on
  SetVoiceLevels(VOICE.levels, VOICE.default)   -- whisper, normal, shout on the voice level key: the VOICE table above
  SetVoiceOcclusion(VOICE.occlusion)            -- a voice behind a wall is muffled
  -- A heartbeat every 5 minutes so an idle server's log shows it is alive.
  SetTimer(function()
    Log(fmt("%d player(s) online, tick %d", GetPlayerCount(), GetServerTick()))
  end, 300000, true)
  -- Horses left behind (their player gone) disappear after a while.
  SetTimer(function()
    for _, id in ipairs(GetEntities(ENTITY_HORSE)) do
      if GetEntityController(id) == nil and GetEntityIdleTime(id) > ORPHAN_HORSE_SECONDS then
        Log(fmt("horse %d stood alone for %d s, removed", id, ORPHAN_HORSE_SECONDS))
        DestroyEntity(id)
      end
    end
  end, 60000, true)
  -- The greeting zone at the spawn (the world clock at the top right is the client half's: freeroam/client/hud.lua
  -- draws it in the game's own typeface from the game's calendar, which the server keeps in step).
  spawnZone = CreateCircleZone(spawnX, spawnY, 12)
  accounts_init()   -- the accounts table, when there is a database (the sync calls are allowed here alone)
end

function OnPlayerEnterZone(pid, zone)
  if zone == spawnZone then GameText(pid, "The spawn", 1500, GAMETEXT_LOWER) end
end

function OnClientEvent(pid, name, payload)
  -- a client script's SendServerEvent lands here; "echo" answers with the same payload (a round trip test)
  if name == "echo" then SendClientEvent(pid, "echo", payload) end
end

-- Admins are the mode's: the server keeps no accounts and no list. This example takes the names from the
-- KCDMP_ADMINS environment variable ("Henry,Hans"); a real server keeps them in its own database next to
-- its accounts (see the accounts section below). Names are not unique - two players may join as "Henry" -
-- so a real server's list holds what GetPlayerUid returns, not names.
local admins = {}
for name in (os.getenv("KCDMP_ADMINS") or ""):gmatch("[^,%s]+") do admins[name:lower()] = true end

function OnPlayerConnect(pid)
  SetPlayerThirdPerson(pid, CAMERA.third_person, CAMERA.in_fights, CAMERA.when_aiming, CAMERA.crosshair)
  SendClientMessage(pid, COLOR_SERVER, fmt("Welcome to %s, %s. %d player(s) online. Type /help for commands.",
    GetLevelName(), GetPlayerName(pid), GetPlayerCount()))
  SendClientMessageToAll(COLOR_SERVER, GetPlayerName(pid) .. " joined")
  accounts_connect(pid)
  if admins[GetPlayerName(pid):lower()] then
    SetPlayerAdmin(pid, true)
    SendClientMessage(pid, COLOR_SERVER, "You are an admin on this server.")
  end
end

-- Everyone gets the spawn with a 1.5 m step per player id so arrivals do not stack inside each other
-- (the server remembers nobody: a mode that wants returning players where they left stores the position
-- itself, in its database, on the disconnect).
function OnPlayerRequestSpawn(pid)
  SetSpawnInfo(pid, spawnX + 1.5 * (pid % 16), spawnY + 1.5 * (pid // 16), spawnZ, spawnYaw)
  return true
end

function OnPlayerSpawn(pid)
  local x, y, z = GetPlayerPos(pid)
  Log(fmt("%s spawned at %.1f %.1f %.1f", GetPlayerName(pid), x, y, z))
  GameText(pid, GetLevelName(), 3000, GAMETEXT_CENTRE)
  SetPlayerPullDown(pid, PULLDOWN.enabled)   -- a right off by default: the table above (or /pulldowns) switches it on
end

-- a player on foot asked to pull a rider off a horse (the server has checked the reach, the pace and the rules): the chance it works
function OnPlayerPullDown(pid, victim, id)
  return PULLDOWN.chance
end

-- knocked out (an admin's /ko, or a mode's own rule) and up again: the player is told
function OnPlayerKnockedOut(pid)
  SendClientMessage(pid, COLOR_SERVER, "You were knocked out.")
end

function OnPlayerWake(pid, reason)
  if reason == "woke" or reason == "mode" then SendClientMessage(pid, COLOR_SERVER, "You come to.") end
end

function OnPlayerText(pid, text)
  return true   -- global chat, unfiltered
end

function OnPlayerCommandText(pid, cmd, args)
  -- This mode's own commands. Everything else - /give, /item, /items, /tp, /goto, /horse, /time, /rain,
  -- /kick, /kickban, /unban, /pos, /players, /uptime - is the server's built-in set ([commands] in
  -- server.toml: admins only unless listed public, off with builtin = false), answered when this
  -- function returns false; a mode that wants its own /give handles the name here and returns true.
  if cmd == "register" or cmd == "login" then
    return accounts_command(pid, cmd, args)   -- the mode's own accounts (a database behind them), see the top
  elseif cmd == "help" then
    SendClientMessage(pid, COLOR_SERVER, "freeroam: /anim [name|stop], /dice <name> [bet], /seat [n], /invite <name>, /accept, /decline, /leave, /pkick <name>, /leader <name>, /disband, /p <text>, /tag [text], /color [rrggbb], /team [n], /actor [soul|fists|brawl|clear|stop|come|sit|wave|bow|nod|pray|chop|sweep|smith|hostile|peace|hurt|heal|kill|label <text>|color <rrggbb>|ride|dismount|say <line>|bark [word]|talk [conversation]|use [kind]|unuse|pair [name]], /animal [kind|stop|come|kill|clear], /fx [effect], /sfx [trigger], /hurt [player] [amount], /kill [player], /throw [player] [plain], /pulldown <victim> [puller] [fail], /pulldowns on|off, /carrying on|off|status, /ko [player] [seconds], /wake [player], /carry <player>, /putdown (admin), /carryitem <kind> [player], /carryitems on|off|status, /clearitems (admin), /pickpocket on|off|status (admin); /los [name], /ground (the collision geometry); /skills [name]; /setlevel <player> <skill> <level> [xp], /givexp <player> <skill> <xp>, /perk <player> add|remove <perk>, /perkpoints <player> <skill> <points>, /xprate [rate] (admin)")
    return false   -- the server adds its own list
  elseif cmd == "anim" then
    -- /anim <name>: an emote for everyone around - what the wheel on G does (T is the point); /anim alone lists them,
    -- /anim stop ends a dance. The server's rules answer through PlayPlayerEmote's reason ("Stand still first." ...)
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
  elseif cmd == "seat" then
    -- /seat: who sits where in your cart; /seat <n> moves you there (a seat the mode locked is not yours to take)
    local cart, mine = GetPlayerCart(pid)
    local want = tonumber(args:match("^(%d+)"))
    if not cart then
      SendClientMessage(pid, COLOR_SERVER, "You sit in no cart.")
    elseif not want then
      local seats = {}
      for s = 0, GetCartSeatCount(cart) - 1 do
        local who = GetCartSeatPlayer(cart, s)
        seats[#seats + 1] = s .. " " .. (who and GetPlayerName(who) or IsCartSeatLocked(cart, s) and "locked" or "free")
      end
      SendClientMessage(pid, COLOR_SERVER, "seats: " .. table.concat(seats, ", ") .. " - /seat <n>")
    elseif want ~= mine and (IsCartSeatLocked(cart, want) or not SetPlayerCartSeat(pid, want)) then
      SendClientMessage(pid, COLOR_RED, "Not that seat: taken, locked, the reins of a route cart, or the cart is moving.")
    end
    return true
  elseif cmd == "fx" then
    -- one-shot effects: /fx [effect] puts a particle effect of the game's libraries 2 m ahead of the caller for
    -- everyone in range (the smithy's smoke without a name); the clients' logs say whether the game knew the name
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/fx is for admins") return true end
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    local name = args ~= "" and args or "WH_Particels.smokes.smithery"
    local got = SpawnEffect(name, px + 2, py, pz)
    SendClientMessage(pid, COLOR_SERVER, fmt("effect %s to %d player(s)", name, got))
    return true
  elseif cmd == "los" then
    -- the collision geometry (world data): /los <name> says whether the line from the caller's chest to the named player's is
    -- clear - stand behind a wall, a door, a tree; /los alone shoots 30 m ahead and names what is there
    if not HasCollision() then SendClientMessage(pid, COLOR_SERVER, "no collision geometry on this server") return true end
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    if args == "" then
      local yaw = math.rad(GetPlayerYaw(pid) or 0)
      local hit = RayCast(px, py, pz + 1.5, px - 30 * math.sin(yaw), py + 30 * math.cos(yaw), pz + 1.5)
      SendClientMessage(pid, COLOR_SERVER, hit and fmt("%.1f m ahead: %s (material %d)", hit.distance, hit.class ~= "" and (hit.class .. " " .. hit.name) or "the level", hit.material)
                                                    or "nothing within 30 m ahead")
      return true
    end
    local other, why = GetPlayerId(args)
    if not other then SendClientMessage(pid, COLOR_SERVER, why) return true end
    local ox, oy, oz = GetPlayerPos(other)
    if not ox then return true end
    local hit = RayCast(px, py, pz + 1.3, ox, oy, oz + 1.3)
    SendClientMessage(pid, COLOR_SERVER, hit and fmt("%s is behind %s, %.1f m along the line", GetPlayerName(other), hit.class ~= "" and (hit.class .. " " .. hit.name) or "the level", hit.distance)
                                                  or fmt("%s is in plain sight", GetPlayerName(other)))
    return true
  elseif cmd == "ground" then
    -- /ground: the floor under the caller by the collision geometry against the terrain's height - on a bridge or upstairs they differ
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    local floor, terrain = GetGroundZ(px, py, pz), GetTerrainHeight(px, py)
    SendClientMessage(pid, COLOR_SERVER, fmt("you at z %.2f; the floor %s, the terrain %s", pz, floor and fmt("%.2f", floor) or "nil", terrain and fmt("%.2f", terrain) or "nil"))
    return true
  elseif cmd == "sfx" then
    -- a sound at the caller's feet: /sfx [trigger] - an audio trigger of the game's Libs/GameAudio (a lightning strike without a name)
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/sfx is for admins") return true end
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    local name = args ~= "" and args or "lightning"
    SendClientMessage(pid, COLOR_SERVER, fmt("sound %s to %d player(s)", name, PlaySound(name, px, py, pz)))
    return true
  elseif cmd == "actor" then
    -- NPC actors: an admin's demo - a dressed body 4 m ahead that walks a 12 m square around the
    -- caller at a walk, run and sprint, one leg after another (OnActorArrive), for ever; /actor clear removes them all
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/actor is for admins") return true end
    if args == "clear" then
      local n = 0
      for _, id in ipairs(GetEntities(ENTITY_NPC)) do DestroyEntity(id) n = n + 1 end
      SendClientMessage(pid, COLOR_SERVER, fmt("%d actor(s) removed", n))
      return true
    end
    if args == "come" then
      -- the navmesh (world data): the first actor walks to the caller along the mesh - stand behind a wall or inside the
      -- cloister and watch it come round through the door; without a mesh it walks the straight line
      local id = GetEntities(ENTITY_NPC)[1]
      if not id then SendClientMessage(pid, COLOR_SERVER, "no actor") return true end
      local px, py, pz = GetPlayerPos(pid)
      if actorWalks then actorWalks[id] = nil end
      local ax, ay, az = GetEntityPos(id)
      local path = FindPath(ax, ay, az, px, py, pz)
      MoveActor(id, px, py, pz, 1.5)
      SendClientMessage(pid, COLOR_SERVER, fmt("%s comes: %s", GetEntityName(id),
        path and fmt("%d corners on the navmesh", #path) or (HasNavmesh() and "no way on the navmesh, the straight line" or "no navmesh, the straight line")))
      return true
    end
    if args == "stop" or ACTOR_ANIM[args] then
      -- the pose: /actor stop halts the square walk (a pose needs a standing actor), /actor sit | wave | bow | nod | pray | chop | sweep | smith
      local id = GetEntities(ENTITY_NPC)[1]
      if not id then SendClientMessage(pid, COLOR_SERVER, "no actor") return true end
      if args == "stop" then
        if actorWalks then actorWalks[id] = nil end
        StopActor(id)
        SendClientMessage(pid, COLOR_SERVER, fmt("%s stops", GetEntityName(id)))
      else
        SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s -> %s", GetEntityName(id), args, tostring(SetActorAnim(id, args))))
      end
      return true
    end
    local sub, who = args:match("^(%S+)%s*(.*)$")
    if sub == "ride" or sub == "dismount" or sub == "say" or sub == "bark" or sub == "talk" or sub == "use" or sub == "unuse" or sub == "pair" then
      -- actor life (2026-10-08): /actor ride puts the first actor on a horse made beside it (it then rides its square, a walk, a trot, a
      -- canter, a gallop), /actor dismount takes it off; /actor say <line id> | bark [word] - one of the game's lines in its voice;
      -- /actor talk [conversation] - the first two actors hold one of the game's conversations; /actor use [kind] - the first actor goes
      -- to the nearest free seat, bed or work spot of the level (a kind: sit, lie, work, lean, wait ...), /actor unuse gets it up;
      -- /actor pair [talk|dance|...] - the first two actors in one of the game's pair animations
      local actors = GetEntities(ENTITY_NPC)
      local id, other = actors[1], actors[2]
      if not id then SendClientMessage(pid, COLOR_SERVER, "no actor") return true end
      if actorWalks then actorWalks[id] = nil end
      local name = GetEntityName(id)
      if sub == "ride" then
        StopActor(id)
        local ax, ay, az = GetEntityPos(id)
        local horse = CreateHorse(ax + 2.5, ay, az, 0)
        local ok = horse and MountActor(id, horse)
        SendClientMessage(pid, COLOR_SERVER, fmt("%s %s", name, ok and "walks to its horse and mounts it" or "cannot mount (no horse)"))
      elseif sub == "dismount" then
        SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s", name, DismountActor(id) and "gets off" or "rides no horse"))
      elseif sub == "say" then
        local seconds = PlayActorVoice(id, who)
        SendClientMessage(pid, COLOR_SERVER, seconds > 0 and fmt("%s says \"%s\" (%.1f s)", name, GetVoiceLineText(who), seconds) or "no such line")
      elseif sub == "bark" then
        local line = PlayActorBark(id, who ~= "" and who or "greeting")
        SendClientMessage(pid, COLOR_SERVER, line ~= "" and fmt("%s: \"%s\"", name, GetVoiceLineText(line)) or "no such bark")
      elseif sub == "talk" then
        if not other then SendClientMessage(pid, COLOR_SERVER, "two actors needed (/actor twice)") return true end
        if actorWalks then actorWalks[other] = nil end
        StopActor(id) StopActor(other)
        local seconds = PlayActorConversation(id, other, who ~= "" and who or "gossip")
        SendClientMessage(pid, COLOR_SERVER, seconds > 0 and fmt("%s and %s talk (%.0f s)", name, GetEntityName(other), seconds) or "no such conversation")
      elseif sub == "use" then
        local ax, ay, az = GetEntityPos(id)
        local spot = GetNearestSmartObject(ax, ay, az, 40, who ~= "" and who or nil)
        local ok = spot and SetActorUse(id, spot.key)
        SendClientMessage(pid, COLOR_SERVER, ok and fmt("%s goes to %s (%s, %.0f m)", name, spot.key, spot.activity, spot.distance)
          or "no free seat or work spot within 40 m")
      elseif sub == "unuse" then
        SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s", name, StopActorUse(id) and "gets up" or "in no activity"))
      else
        if not other then SendClientMessage(pid, COLOR_SERVER, "two actors needed (/actor twice)") return true end
        if actorWalks then actorWalks[other] = nil end
        StopActor(id) StopActor(other)
        local ok = PlayActorPairAnim(id, other, who ~= "" and who or "talk")
        SendClientMessage(pid, COLOR_SERVER, ok and fmt("%s and %s: %s", name, GetEntityName(other), who ~= "" and who or "talk") or "no such pair")
      end
      return true
    end
    if sub == "label" or sub == "color" then
      -- the first actor's label: /actor label <text> ("" = its name again), /actor color rrggbb (none = the default gold)
      local id = GetEntities(ENTITY_NPC)[1]
      if not id then SendClientMessage(pid, COLOR_SERVER, "no actor") return true end
      if sub == "label" then
        SetActorNameplate(id, who)
      else
        local rgb = tonumber(who:match("^#?(%x%x%x%x%x%x)$") or "", 16)
        SetActorColor(id, rgb and (rgb * 256 + 255) or 0)
      end
      SendClientMessage(pid, COLOR_SERVER, fmt("%s: label \"%s\", color %08X", GetEntityName(id), GetActorNameplate(id), GetActorColor(id)))
      return true
    end
    if args == "brawl" then
      -- two armed actors 3 m ahead set on each other, a red label and a blue one: the server lands their blows, the
      -- blue answers the first (fight_back); /actor clear removes them
      local px, py, pz = GetPlayerPos(pid)
      if not px then return true end
      local count = #GetEntities(ENTITY_NPC)
      local red = CreateActor(nil, px + 3, py - 1, pz, 0, fmt("Red %d", count + 1))
      local blue = CreateActor(nil, px + 3, py + 1, pz, 180, fmt("Blue %d", count + 2))
      if not (red and blue) then SendClientMessage(pid, COLOR_SERVER, "no actors") return true end
      SetActorColor(red, 0xE04040FF)
      SetActorColor(blue, 0x4080FFFF)
      SetActorHostileToActor(red, blue, true)
      SendClientMessage(pid, COLOR_SERVER, fmt("actors %d and %d spawned and set on each other", red, blue))
      return true
    end
    if sub == "hostile" or sub == "peace" or sub == "kill" or sub == "hurt" or sub == "heal" then
      -- what an actor can be put through without a sword: /actor hostile [player] sets it on the caller - or on the
      -- player named, to watch a fight from the side (its square walk ends: it chases and swings), /actor peace
      -- stands it down, /actor hurt takes health off it, /actor heal makes a wounded one whole (the limp and the
      -- bleeding go on every screen), /actor kill ends it
      local id = GetEntities(ENTITY_NPC)[1]
      if not id then SendClientMessage(pid, COLOR_SERVER, "no actor to " .. sub) return true end
      local target = pid
      if who and who ~= "" then
        local why
        target, why = GetPlayerId(who)   -- a pid, a name or a fragment of one
        if not target then SendClientMessage(pid, COLOR_SERVER, why) return true end
      end
      args = sub
      if args == "hostile" then
        if actorWalks then actorWalks[id] = nil end
        StopActor(id)
        SetActorHostile(target, id, true)
      elseif args == "peace" then SetActorHostile(target, id, false)
      elseif args == "hurt" then SetActorHealth(id, GetActorHealth(id) - 30)
      elseif args == "heal" then HealActor(id)
      else SetActorHealth(id, 0) end
      local wounds = ""
      for _, part in ipairs(GetActorInjuries(id)) do wounds = wounds .. " " .. GetBodyPartName(part) end
      SendClientMessage(pid, COLOR_SERVER, fmt("%s: %s, health %.0f%s%s%s", GetEntityName(id), args, GetActorHealth(id),
        wounds ~= "" and (", injured:" .. wounds) or "", IsActorBleeding(id) and ", bleeding" or "", IsActorDead(id) and " (dead)" or ""))
      return true
    end
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    if args == "fists" then
      -- an unarmed brawler 3 m ahead, on the caller at once (the punches, the chase, the fight's end at a death)
      local id = CreateActor(nil, px + 3, py, pz, 180, fmt("Brawler %d", #GetEntities(ENTITY_NPC) + 1), nil, "none")
      if id then SetActorHostile(pid, id, true) end
      SendClientMessage(pid, COLOR_SERVER, id and fmt("actor %d spawned unarmed and set on you; /actor peace stands it down", id) or "no actor")
      return true
    end
    local soul = args ~= "" and args or nil
    local id = CreateActor(soul, px + 4, py, pz, 180, fmt("Actor %d", #GetEntities(ENTITY_NPC) + 1))
    if not id then SendClientMessage(pid, COLOR_SERVER, "no such soul (a name, id or GUID of the souls list: docs.kcd-mp.com/reference/souls)") return true end
    actorWalks = actorWalks or {}
    actorWalks[id] = {corners = {{px + 4, py + 6}, {px - 8, py + 6}, {px - 8, py - 6}, {px + 4, py - 6}}, leg = 0}
    local speeds = {1.5, 4, 6.5, 1.5}
    local w = actorWalks[id]
    w.leg = 1
    MoveActor(id, w.corners[1][1], w.corners[1][2], pz, speeds[1])
    SendClientMessage(pid, COLOR_SERVER, fmt("actor %d spawned: it walks a square around you (walk, run, sprint, walk); /actor clear removes it", id))
    return true
  elseif cmd == "animal" then
    -- animals: an admin's demo - /animal <kind> 4 m ahead walks the same square as /actor (walk, run, sprint, walk); /animal
    -- stop halts them, /animal come calls them to you, /animal kill ends them, /animal clear removes them all
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/animal is for admins") return true end
    local animals = GetEntities(ENTITY_ANIMAL)
    if args == "clear" or args == "stop" or args == "kill" or args == "come" then
      local px, py, pz = GetPlayerPos(pid)
      for i, id in ipairs(animals) do
        if actorWalks then actorWalks[id] = nil end
        if args == "clear" then DestroyEntity(id)
        elseif args == "stop" then StopActor(id)
        elseif args == "kill" then SetActorHealth(id, 0)
        elseif px then MoveActor(id, px + i, py, pz, 4) end
      end
      SendClientMessage(pid, COLOR_SERVER, fmt("/animal %s: %d animal(s)", args, #animals))
      return true
    end
    local px, py, pz = GetPlayerPos(pid)
    if not px then return true end
    local id = args ~= "" and CreateAnimal(args, px + 4, py, pz, 180) or nil
    if not id then
      SendClientMessage(pid, COLOR_SERVER, "usage: /animal <wolf|boar|wild dog|dog|red deer stag|red deer doe|roe deer buck|roe deer hind|hare|pig|sheep|ram|cow|bull|hen|raven>|stop|come|kill|clear")
      return true
    end
    actorWalks = actorWalks or {}
    actorWalks[id] = {corners = {{px + 4, py + 6}, {px - 8, py + 6}, {px - 8, py - 6}, {px + 4, py - 6}}, leg = 1}
    MoveActor(id, px + 4, py + 6, pz, 1.5)
    SendClientMessage(pid, COLOR_SERVER, fmt("animal %d (%s) spawned: it walks a square around you; /animal clear removes it", id, args))
    return true
  elseif cmd == "tag" then
    -- the label over your body ("" = your name again)
    SetPlayerNameplate(pid, args)
    SendClientMessage(pid, COLOR_SERVER, args == "" and "your nameplate is your name again" or ("your nameplate reads: " .. args))
    return true
  elseif cmd == "color" or cmd == "color" then
    local rgb = tonumber(args:match("^%s*#?(%x%x%x%x%x%x)%s*$") or "", 16)
    SetPlayerColor(pid, rgb and (rgb * 256 + 255) or 0)
    SendClientMessage(pid, COLOR_SERVER, rgb and fmt("your color is #%06x", rgb) or "your color is the default (usage: /color rrggbb)")
    return true
  elseif cmd == "team" then
    local team = tonumber(args)
    SetPlayerTeam(pid, team or NO_TEAM)
    SetPlayerState(pid, "team", team)   -- the state bag: every client's GetPlayerState(pid, "team") reads it
    SendClientMessage(pid, COLOR_SERVER, team and fmt("you are in team %d: its members cannot hurt each other", team) or "you are in no team")
    return true
  elseif cmd == "hurt" then
    -- /hurt [player] [amount]: the server takes `amount` health (30 by default) off a player without a blow - the
    -- wounded look on the other screens, and /heal after it puts them right again; admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/hurt is for admins") return true end
    -- sscanf: an optional player (a pid or a name fragment) and an optional amount; a bare number is the amount
    local target, amount
    if args:match("^%s*%d+%s*$") then amount = sscanf(args, "d") else target, amount = sscanf(args, "u?d?") end
    if target == false then SendClientMessage(pid, COLOR_SERVER, amount .. " (usage: /hurt [player] [amount])") return true end
    target = target or pid
    local health = GetPlayerHealth(target)
    if not health then SendClientMessage(pid, COLOR_SERVER, "not in the world") return true end
    local left = math.max(1, health - (amount or 30))
    SetPlayerHealth(target, left)
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: health %.0f -> %.0f", GetPlayerName(target), health, left))
    return true
  elseif cmd == "kill" then
    -- /kill [player]: the server's death without a blow (the ragdoll, the death screen on the victim's own game, the
    -- respawn after [combat] respawn_seconds); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/kill is for admins") return true end
    local target = sscanf(args, "u?")
    if target == false then SendClientMessage(pid, COLOR_SERVER, "usage: /kill [player]") return true end
    target = target or pid
    if not GetPlayerHealth(target) then SendClientMessage(pid, COLOR_SERVER, "not in the world") return true end
    SetPlayerHealth(target, 0)
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: killed", GetPlayerName(target)))
    return true
  elseif cmd == "throw" then
    -- /throw [player] [plain]: the rider's own game throws them off their horse (the game's fall and get-up, on every screen):
    -- flung backward off the rear, or "plain" = dropped where they sit, as a head hit on a low branch does; admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/throw is for admins") return true end
    local target, flung = pid, true
    if args:match("^%s*plain%s*$") then
      flung = false
    else
      local who, word = sscanf(args, "u?s?")
      if who == false then SendClientMessage(pid, COLOR_SERVER, "usage: /throw [player] [plain]") return true end
      target = who or pid
      flung = word ~= "plain"
    end
    local ok, why = ThrowPlayerFromHorse(target, flung)
    SendClientMessage(pid, COLOR_SERVER, ok and fmt("%s: ordered off the horse%s", GetPlayerName(target), flung and "" or " (plain)") or fmt("%s: %s", GetPlayerName(target), why))
    return true
  elseif cmd == "pulldown" then
    -- /pulldown <victim> [puller] [fail]: the puller (you, unless named) pulls the rider off their horse - the game's take-down on
    -- order, without the weapon's reach, the pace or the rules; "fail" plays the failed pair. Admins only: the way to see it alone
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/pulldown is for admins") return true end
    local fail = args:match("%f[%w]fail%s*$") ~= nil
    local rest = (args:gsub("%s*fail%s*$", ""))
    local victim, puller = sscanf(rest, "uu?")
    if victim == false then SendClientMessage(pid, COLOR_SERVER, "usage: /pulldown <victim> [puller] [fail]") return true end
    puller = puller or pid
    local ok, why = PullPlayerFromHorse(victim, puller, not fail)
    SendClientMessage(pid, COLOR_SERVER, ok and fmt("%s pulls %s off the horse%s", GetPlayerName(puller), GetPlayerName(victim), fail and " (and fails)" or "")
      or fmt("%s: %s", GetPlayerName(victim), why))
    return true
  elseif cmd == "pulldowns" then
    -- /pulldowns on|off: every player online may (not) pull riders down from now on - and every spawn after it (the PULLDOWN table's
    -- switch, flipped); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/pulldowns is for admins") return true end
    local word = args:match("^%s*(%a+)%s*$")
    if word ~= "on" and word ~= "off" then
      SendClientMessage(pid, COLOR_SERVER, fmt("pull-downs are %s - /pulldowns on|off", PULLDOWN.enabled and "on" or "off"))
      return true
    end
    PULLDOWN.enabled = word == "on"
    for _, id in ipairs(GetPlayers()) do SetPlayerPullDown(id, PULLDOWN.enabled) end
    SendClientMessage(pid, COLOR_SERVER, fmt("pull-downs are %s for everyone", word))
    return true
  elseif cmd == "carrying" then
    -- /carrying on|off|status: the players' own grab (the CARRY table's switch, flipped; a carry that runs goes on); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/carrying is for admins") return true end
    local word = args:match("^%s*(%a+)%s*$")
    if word == "on" or word == "off" then
      CARRY.enabled = word == "on"
      SetCarrying(CARRY.enabled, CARRY)
    end
    local on, rules = GetCarrying()
    SendClientMessage(pid, COLOR_SERVER, fmt("carrying is %s: range %.1f m, speed %.1f m/s, corpses %s, players %s, actors %s - /carrying on|off",
      on and "on" or "off", rules.range, rules.speed, tostring(rules.corpses), tostring(rules.players), tostring(rules.actors)))
    return true
  elseif cmd == "ko" then
    -- /ko [player] [seconds]: knocks a player out (you, unless named) - they drop, their screen goes dark, their health stays; for the
    -- seconds given, else until /wake; admins only. The grab can carry them while they lie there
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/ko is for admins") return true end
    local first, second = args:match("^%s*(%S*)%s*(%S*)")
    local target, seconds = pid, tonumber(second)
    if first ~= "" then
      local who = GetPlayerId(first)
      if who then target = who
      elseif tonumber(first) and second == "" then seconds = tonumber(first)
      else SendClientMessage(pid, COLOR_SERVER, "usage: /ko [player] [seconds]") return true end
    end
    local ok, why = SetPlayerKnockedOut(target, true, seconds)
    SendClientMessage(pid, COLOR_SERVER, ok and fmt("%s: knocked out%s", GetPlayerName(target), seconds and fmt(" for %g s", seconds) or "") or fmt("%s: %s", GetPlayerName(target), why))
    return true
  elseif cmd == "wake" then
    -- /wake [player]: wakes a knocked-out player (you, unless named); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/wake is for admins") return true end
    local target = sscanf(args, "u?")
    if target == false then SendClientMessage(pid, COLOR_SERVER, "usage: /wake [player]") return true end
    target = target or pid
    SetPlayerKnockedOut(target, false)
    SendClientMessage(pid, COLOR_SERVER, fmt("%s: awake", GetPlayerName(target)))
    return true
  elseif cmd == "carry" then
    -- /carry <player>: you carry that player over your shoulder - the game's own carry on order, whoever they are (they show knocked out
    -- for it and wake after, unless /ko keeps them down); /putdown puts them down. Admins only: the way to see it alone
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/carry is for admins") return true end
    local target = sscanf(args, "u")
    if target == false then SendClientMessage(pid, COLOR_SERVER, "usage: /carry <player>") return true end
    local ok, why = CarryPlayer(pid, target, CARRY.speed)
    SendClientMessage(pid, COLOR_SERVER, ok and fmt("you carry %s", GetPlayerName(target)) or fmt("%s: %s", GetPlayerName(target), why))
    return true
  elseif cmd == "putdown" then
    -- /putdown: what you carry is put down (the game's own put); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/putdown is for admins") return true end
    SendClientMessage(pid, COLOR_SERVER, IsPlayerCarrying(pid) and StopCarry(pid) and "putting it down" or "you carry nobody")   -- the carrier's: StopCarry alone takes the carried player's carry too
    return true
  elseif cmd == "carryitem" then
    -- /carryitem <kind> [player]: lays a carry item in front of you, or puts one in that player's hands (the game's pickup plays); the
    -- kinds are the ITEMS table's short names or any item name of the game's; admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/carryitem is for admins") return true end
    local kind, who = args:match("^%s*(%S+)%s*(%S*)%s*$")
    if not kind then
      local names = {}
      for name in pairs(ITEMS.kinds) do names[#names + 1] = name end
      table.sort(names)
      SendClientMessage(pid, COLOR_SERVER, "usage: /carryitem <kind> [player] - kinds: " .. table.concat(names, ", ") .. " (or an item name)")
      return true
    end
    local item = ITEMS.kinds[string.lower(kind)] or kind
    if who ~= "" then
      local target, why = GetPlayerId(who)
      if not target then SendClientMessage(pid, COLOR_SERVER, why) return true end
      local id, why = GivePlayerCarryItem(target, item)
      SendClientMessage(pid, COLOR_SERVER, id and fmt("%s picks up %s", GetPlayerName(target), item) or fmt("%s: %s", GetPlayerName(target), why))
      return true
    end
    local x, y, z = GetPlayerPos(pid)
    local yaw = GetPlayerYaw(pid)
    local rad = math.rad(yaw)
    local id = x and CreateCarryItem(item, x - math.sin(rad) * 1.2, y + math.cos(rad) * 1.2, z, yaw, GetPlayerVirtualWorld(pid))
    SendClientMessage(pid, COLOR_SERVER, id and fmt("%s laid in front of you (entity %d)", item, id) or fmt("there is no item called '%s'", item))
    return true
  elseif cmd == "carryitems" then
    -- /carryitems on|off|status: the "Pick up" prompt on carry items (the ITEMS table's switch, flipped; a carry that runs goes on); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/carryitems is for admins") return true end
    local word = args:match("^%s*(%a+)%s*$")
    if word == "on" or word == "off" then
      ITEMS.enabled = word == "on"
      SetItemCarrying(ITEMS.enabled, ITEMS)
    end
    local on, rules = GetItemCarrying()
    SendClientMessage(pid, COLOR_SERVER, fmt("carry items are %s: range %.1f m, %d in the world - /carryitems on|off", on and "on" or "off", rules.range,
      #GetEntities(ENTITY_CARRY)))
    return true
  elseif cmd == "clearitems" then
    -- /clearitems: every carry item goes (one in a player's hands too); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/clearitems is for admins") return true end
    local list = GetEntities(ENTITY_CARRY)
    for _, id in ipairs(list) do DestroyEntity(id) end
    SendClientMessage(pid, COLOR_SERVER, fmt("%d carry item(s) taken away", #list))
    return true
  elseif cmd == "pickpocket" then
    -- /pickpocket on|off|status: pickpocketing between players (the POCKET table's switch, flipped; a session that runs ends when it goes off); admins only
    if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_SERVER, "/pickpocket is for admins") return true end
    local word = args:match("^%s*(%a+)%s*$")
    if word == "on" or word == "off" then
      POCKET.enabled = word == "on"
      SetPickpocketing(POCKET.enabled, POCKET)
    end
    local on, rules = GetPickpocketing()
    SendClientMessage(pid, COLOR_SERVER, fmt("pickpocketing is %s: range %.1f m, every %g s, %d stack(s) of %d at most, behind only %s, money %s - /pickpocket on|off",
      on and "on" or "off", rules.range, rules.cooldown, rules.max_items, rules.max_stack, tostring(rules.behind_only), tostring(rules.money)))
    return true
  end
  if ProgressCommand(pid, cmd, args) then return true end
  if PartyCommand(pid, cmd, args) then return true end
  if DiceCommand(pid, cmd, args) then return true end
  return false   -- the server's built-ins, then "Unknown command"
end

-- Dice: the game's own dice game between two players at a dice table - each plays on their own screen, the server deals
-- every throw, checks every move and holds the stakes. /dice <name> [bet] challenges a player who stands with you at a
-- dice table, /dice accept or /dice decline answers, /dice quit gives a running game up (so does Esc in the game). The
-- challenger throws first. The rules are this mode's - change them here:
local DICE = {
  enabled = true,     -- false: /dice answers that dice are off
  game_type = 0,      -- the goal: 0 beggar (1500 points), 1 wagoner (2000), 5 craftsman (3000), 9 courtier (4000)
  turn_timeout = 90,  -- seconds a player may take for one move before losing the match (5 to 3600)
  range = 4,          -- metres: how far apart the two may stand at the table to start (0.5 to 8)
}
local dice_invites = {}   -- the challenged player -> {from, bet, at}
local DICE_INVITE_MS = 60000
local DICE_REASONS = {goal = "reached the goal", ["gave up"] = "the other gave up", left = "the other left", timeout = "a move took too long",
  died = "a player died", ["out of step"] = "the two games parted ways", failed = "no dice table here - stand at one together",
  ["the mode"] = "the server ended it", ["a fight"] = "a fight broke out", ["walked away"] = "a player walked away"}
function DiceCommand(pid, cmd, args)
  if cmd ~= "dice" then return false end
  local word, rest = args:match("^(%S*)%s*(.-)$")
  word = (word or ""):lower()
  if word == "" or word == "help" then
    SendClientMessage(pid, COLOR_SERVER, "dice: /dice <name> [bet] challenges a player at a dice table, /dice accept, /dice decline, /dice quit")
  elseif not DICE.enabled and word ~= "quit" then
    SendClientMessage(pid, COLOR_RED, "Dice are off on this server.")
  elseif word == "accept" then
    local invite = dice_invites[pid]
    dice_invites[pid] = nil
    if not invite or GetServerTime() - invite.at > DICE_INVITE_MS or not GetPlayerName(invite.from) then
      SendClientMessage(pid, COLOR_RED, "Nobody challenged you to dice.")
      return true
    end
    local id, why = StartDiceMatch(invite.from, pid, invite.bet, DICE.game_type, DICE.turn_timeout, DICE.range)
    if not id then
      SendClientMessage(pid, COLOR_RED, why)
      SendClientMessage(invite.from, COLOR_RED, why)
    end
  elseif word == "decline" then
    local invite = dice_invites[pid]
    dice_invites[pid] = nil
    if not invite then SendClientMessage(pid, COLOR_RED, "Nobody challenged you to dice.") return true end
    if GetPlayerName(invite.from) then SendClientMessage(invite.from, COLOR_SERVER, GetPlayerName(pid) .. " declined your game of dice.") end
  elseif word == "quit" then
    local info = GetDiceMatchInfo(GetPlayerDiceMatch(pid) or 0)
    if not info then SendClientMessage(pid, COLOR_RED, "You are not playing dice.") return true end
    EndDiceMatch(info.id, info.challenger == pid and info.opponent or info.challenger)
  else
    local target, why = GetPlayerId(word)
    local bet = math.floor(tonumber(rest) or 0)
    if not target then SendClientMessage(pid, COLOR_RED, why) return true end
    if target == pid then SendClientMessage(pid, COLOR_RED, "Not against yourself.") return true end
    if bet < 0 then SendClientMessage(pid, COLOR_RED, "The bet must be 0 or more Groschen.") return true end
    if GetPlayerDiceMatch(target) then SendClientMessage(pid, COLOR_RED, GetPlayerName(target) .. " is playing dice already.") return true end
    dice_invites[target] = {from = pid, bet = bet, at = GetServerTime()}
    local stake = bet > 0 and fmt(" for %d Groschen", bet) or ""
    SendClientMessage(target, COLOR_SERVER, fmt("%s challenges you to dice%s - /dice accept or /dice decline.", GetPlayerName(pid), stake))
    SendClientMessage(pid, COLOR_SERVER, fmt("You challenged %s to dice%s.", GetPlayerName(target), stake))
  end
  return true
end

function OnDiceMatchStart(id, challenger, opponent, bet, goal)
  local text = fmt("Dice: %s against %s, to %d points%s. %s throws first.", GetPlayerName(challenger), GetPlayerName(opponent), goal,
    bet > 0 and fmt(", %d Groschen each", bet) or "", GetPlayerName(challenger))
  SendClientMessage(challenger, COLOR_SERVER, text)
  SendClientMessage(opponent, COLOR_SERVER, text)
end

function OnDiceMatchEnd(id, challenger, opponent, winner, reason, bet)
  local why = DICE_REASONS[reason] or reason
  local text = winner >= 0 and fmt("%s won the game of dice%s (%s).", GetPlayerName(winner), bet > 0 and fmt(" and %d Groschen", 2 * bet) or "", why)
    or fmt("The game of dice is off: %s%s.", why, bet > 0 and " - the stakes went back" or "")
  for _, p in ipairs({challenger, opponent}) do
    if GetPlayerName(p) then SendClientMessage(p, COLOR_SERVER, text) end
  end
end

-- Parties: the server keeps the group, the invitation with its toast and the frames on screen; the commands and
-- the rules are the mode's - these are the plain ones. /invite <name>, /accept, /decline, /leave, /pkick <name>
-- (the server's own /kick is the admin's),
-- /leader <name>, /disband, /p <text>. Any member may invite here (leader-only is one line in OnPartyInvite).
function PartyCommand(pid, cmd, args)
  if cmd == "invite" then
    local target, why = GetPlayerId(args)
    if not target then SendClientMessage(pid, COLOR_RED, why) return true end
    local ok, reason = InviteToParty(pid, target)
    if ok then SendClientMessage(pid, COLOR_SERVER, "Invited " .. GetPlayerName(target) .. ".")
    else SendClientMessage(pid, COLOR_RED, "Cannot invite: " .. reason .. ".") end
    return true
  elseif cmd == "accept" then
    if not AcceptPartyInvite(pid) then SendClientMessage(pid, COLOR_RED, "Nobody invited you.") end
    return true
  elseif cmd == "decline" then
    if not DeclinePartyInvite(pid) then SendClientMessage(pid, COLOR_RED, "Nobody invited you.") end
    return true
  elseif cmd == "leave" then
    if not RemovePlayerFromParty(pid, "left") then SendClientMessage(pid, COLOR_RED, "You are in no party.") end
    return true
  elseif cmd == "pkick" or cmd == "leader" then
    local party = GetPlayerParty(pid)
    local target, why = GetPlayerId(args)
    if not party or GetPartyLeader(party) ~= pid then SendClientMessage(pid, COLOR_RED, "You lead no party.") return true end
    if not target then SendClientMessage(pid, COLOR_RED, why) return true end
    if GetPlayerParty(target) ~= party then SendClientMessage(pid, COLOR_RED, "Not in your party.") return true end
    if cmd == "pkick" then RemovePlayerFromParty(target, "kicked") else SetPartyLeader(party, target) end
    return true
  elseif cmd == "disband" then
    local party = GetPlayerParty(pid)
    if not party or GetPartyLeader(party) ~= pid then SendClientMessage(pid, COLOR_RED, "You lead no party.") return true end
    DisbandParty(party)
    return true
  elseif cmd == "p" then
    local party = GetPlayerParty(pid)
    if not party then SendClientMessage(pid, COLOR_RED, "You are in no party.") return true end
    if args == "" then SendClientMessage(pid, COLOR_RED, "Usage: /p <text>") return true end
    SendPartyMessage(party, 0x80C0FFFF, "[Party] " .. GetPlayerName(pid) .. ": " .. args)
    return true
  end
  return false
end

function OnPartyInvite(from, target)
  SendClientMessage(target, COLOR_SERVER, GetPlayerName(from) .. " invites you to a party - /accept or /decline.")
end

function OnPartyInviteResponse(from, target, answer)
  if answer ~= "accepted" then SendClientMessage(from, COLOR_SERVER, GetPlayerName(target) .. " " .. answer .. " the party invitation.") end
end

function OnPlayerJoinParty(party, pid, reason)
  SendPartyMessage(party, COLOR_SERVER, GetPlayerName(pid) .. " joined the party.")
end

function OnPlayerLeaveParty(party, pid, reason)
  if reason ~= "disband" then SendPartyMessage(party, COLOR_SERVER, GetPlayerName(pid) .. " left the party (" .. reason .. ").") end
end

function OnPartyLeaderChange(party, pid, previous)
  SendPartyMessage(party, COLOR_SERVER, GetPlayerName(pid) .. " leads the party now.")
end

-- the game's own whistle (X on foot) calls the player's horse from up to 300 m: it canters to them (2026-10-10)
function OnPlayerWhistle(pid)
  local x, y, z = GetPlayerPos(pid)
  if not x then return end
  PlaySound("v_horse_whistle", x, y, z + 1.6)
  local horse = GetPlayerHorse(pid)
  if not horse or GetPlayerMount(pid) == horse or GetHorseOwner(horse) ~= pid then return end
  local hx, hy = GetEntityPos(horse)
  local far = math.sqrt((hx - x) ^ 2 + (hy - y) ^ 2)
  if far > 3 and far < 300 then MoveActor(horse, x + (hx - x) / far * 1.5, y + (hy - y) / far * 1.5, -1, 6.5) end
end

-- the demo actors' square: the next corner, the next speed (walk, run, sprint, walk)
function OnActorArrive(id)
  local w = actorWalks and actorWalks[id]
  if not w then return end
  w.leg = w.leg % 4 + 1
  local speeds = w.speeds or {1.5, 4, 6.5, 1.5}
  local _, _, z = GetEntityPos(id)
  MoveActor(id, w.corners[w.leg][1], w.corners[w.leg][2], z or 0, speeds[w.leg])
end

-- actor life (2026-10-08): a demo actor on its horse rides a 30 m square around where it mounted - a walk, a trot, a canter, a gallop
function OnActorMount(id, horse)
  local x, y, z = GetEntityPos(id)
  actorWalks = actorWalks or {}
  actorWalks[id] = {corners = {{x, y + 30}, {x - 30, y + 30}, {x - 30, y}, {x, y}}, leg = 1, speeds = {1.8, 4, 7, 11}}
  MoveActor(id, x, y + 30, z or 0, 1.8)
end

function OnActorDismount(id, horse)
  if actorWalks then actorWalks[id] = nil end
end

-- a demo actor's wounds are announced like a player's would be
function OnActorInjury(id, attacker, part)
  SendClientMessageToAll(COLOR_SERVER, fmt("%s: %s injured%s", GetEntityName(id), GetBodyPartName(part),
    attacker >= 0 and (" by " .. GetPlayerName(attacker)) or ""))
end

-- a demo actor takes the hits like a player (the model's damage, no armour); dead, its corpse lies 20 s and goes
function OnActorDeath(id, attacker)
  if actorWalks then actorWalks[id] = nil end
  local name = GetEntityName(id)
  if not name or name == "" then name = GetEntityKind(id) == ENTITY_ANIMAL and "An animal" or "An actor" end
  SendClientMessageToAll(COLOR_SERVER, fmt("%s is dead%s", name, attacker >= 0 and (" - " .. GetPlayerName(attacker) .. " killed it") or ""))
  SetTimer(function() DestroyEntity(id) end, 20000)
end

function OnPlayerDisconnect(pid, reason)
  SendClientMessageToAll(COLOR_SERVER, fmt("%s left (%s)", GetPlayerName(pid), reason))
  accounts_disconnect(pid)   -- a logged-in player's place, kept for their next visit
end

function OnPlayerMount(pid, id)
  Log(fmt("%s mounted horse %d", GetPlayerName(pid), id))
end

function OnPlayerDismount(pid, id)
  Log(fmt("%s dismounted horse %d", GetPlayerName(pid), id))
end

function OnPlayerPickup(pid, id)
  Log(fmt("%s picked up %s (pickup %d)", GetPlayerName(pid), GetEntityTemplate(id) or "?", id))
  return true
end
