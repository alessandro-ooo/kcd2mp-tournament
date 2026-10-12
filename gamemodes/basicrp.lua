-- KCD:MP BasicRP: the start of a role-play mode on the server owner's own database.
--
-- Needs [gamemode.database] in server.toml (MySQL / MariaDB or PostgreSQL; docs.kcd-mp.com, "Connecting a database").
-- What it does so far: a joining player is held still at the spawn and greeted as role-play servers do it - a web page with
-- the realm's rules and a short test, holding the keyboard and the mouse (WELCOME below) - then meets a password box (the mode's
-- client half, gamemodes/basicrp/client/account.lua): a name without an account chooses a password there and then logs in with it, a registered name logs in;
-- Esc in the box leaves the server and closes the game. /register <password> and /login <password> do the same from the
-- chat. A logged-in player is put back where they left when they log in again, their place saved when they leave (and
-- every minute while they play, so a server that stops keeps it too). Without a database there are no accounts and no
-- box. The server itself remembers nobody: every row here is this mode's. The role-play chat: /me and /do in the
-- lavender every role-play server knows, heard
-- within 20 m, /ame over the speaker's head; the chat itself is local too (20 m), /s shouts across 40 m, /b is
-- the out-of-character line. A merchant stands at the spawn (a vendor nobody can hurt): walk up, press the use key.
-- The spawn is a town (TOWN below): a smith, a tailor and an apothecary sell from their stalls, the innkeeper talks and pours a
-- beer, the stable master trades a player's horse for one of another coat, a guard walks his rounds and townsfolk work - each
-- with a face of their own, a woman among them. The mode's web pages (gamemodes/basicrp/ui) are the welcome at the join, the
-- stable's offer, the notices in the corner and the menu (/menu or Insert: the commands, the town, the purse and the horse); a
-- player whose game draws no web pages gets the game's own dialogue and the chat instead.
-- Parties as in freeroam: /invite, /accept, /decline, /leave, /p to the party, the leader's /pkick, /leader, /disband.
-- The character: an account's first login without a look goes through a creator of the mode's own (its client half,
-- gamemodes/basicrp/client/creator.lua: a menu and a preview body only the player sees) - in a world of the player's own
-- at the spawn, so nobody sees a half-made character - and into the shared world at the spawn when it is done; /look
-- opens it again any time. The look is saved with the account and put back at every login.
-- /horse and /help are this mode's own: the server's built-ins of those names answer admins only, and a mode that
-- handles the name is asked first, so here they belong to every player - /horse brings one and mounts it, /help lists
-- what this mode offers and nothing else. The horse is the player's own and is saved with them - its breed, its gear and
-- what its saddlebags hold: it leaves the world with them and /horse brings it back after a relog or a restart.
-- /createcart opens a window of the mode's own (its client half, gamemodes/basicrp/client/cartmaker.lua): a wagon or a
-- two-wheeler with its body, wheels, load and horses picked on a cart in front of the player, which Space puts into the
-- world; one cart each, and it leaves the world with its maker.
-- The admin's boards: /board, /sign and /paint hang a web page of this mode's interface (a notice board, a sign, words
-- painted on the wall) on the wall the admin looks at; every player near one sees it, and the use key on the notice board
-- reads its notices (/post, /unpin). Kept while the server runs.
-- What the game gives a character - the levels and XP of the stats and skills, the perks, the main level, what they have
-- eaten and slept, and the perk points not spent yet - is saved with them and put back at the next login; a horse keeps the
-- stats an admin gave it. /skills shows a player their own, the main level first; the admin's /setlevel, /givexp, /perk,
-- /perkpoints, /xprate and /horsestat change them. A horse keeps its coat too (the one it first showed; the admin's /horsecoat
-- changes it).
-- What a character found - the named places and points of interest, the books read, the map's pin and legend, the parts of the map
-- uncovered - can be kept too: the DISCOVERY rules below
-- choose what (all off: the game's own map behaviour and nothing saved). A kept kind is saved with the character in
-- player_discovery (one row per level and kind) and put back at the next login.
-- The quests a character holds in the game's journal - the ones a script made with a key - are kept in player_quests (one row per
-- quest: its state and its objectives') and put back at the next login without a banner (the QUESTS rules below).
-- The database: players (one row per account, keyed by id; the purse, the place, the look, the nourishment and the energy),
-- player_items (one row per stack a player carries, what they wear marked), player_progress (one row per stat and skill:
-- its level, XP and unspent perk points, the main level's pool too) and player_perks (one row per perk), player_horses and
-- horse_items (a horse's gear and saddlebags, the same way) and horse_stats. A table from an older BasicRP is brought up to date at the first start: keyed by id, its text saves moved
-- into rows.
-- Everyone who joins is an admin (EVERYONE_ADMIN below).
-- Run with `--gamemode gamemodes/basicrp.lua` or `[gamemode] script = "gamemodes/basicrp.lua"`.

SetGameModeText("BasicRP")

local spawnX, spawnY, spawnZ, spawnYaw = GetDefaultSpawn()
local db = GetDatabase()
local players = {}   -- pid -> { name = the lower-case name, registered = a row exists, logged = proved this session }

local CHAT_RANGE, SHOUT_RANGE = 20, 40   -- metres: who hears a spoken line, a shout
local COLOR_OOC = 0xB0B0B0FF              -- the out-of-character line's grey
local COLOR_PARTY = 0x80C0FFFF            -- the party line's light blue
local START_MONEY, START_ITEMS = 3000, { "torch_weapon" }   -- what a new character starts with (once per session; the purse is saved with the place)
local CREATOR_WORLD = 1000                -- + the player id: the world of one a new character is made in
local MAX_TRIES = 5                       -- wrong passwords in a session before the player is kicked

-- The camera: players can look at themselves from behind, through the game's own chase camera (no camera mod needed). Set at
-- every join. The rule - change it here:
local CAMERA = {
  third_person = "allow",   -- "off": first person only; "allow": a player switches with their third-person key (F3, changeable in the launcher's options); "force": always third person
  in_fights = true,         -- false: first person while fighting with a sword, an axe or fists
  when_aiming = true,       -- false: first person while a bow, a crossbow or a gun is drawn
  crosshair = true,         -- false: no aiming dot in third person with a bow, a crossbow or a gun (first person never has one)
}

-- The horse whistle: the game's own whistle (X on foot) calls the player's own horse - it comes to them at a canter from wherever
-- it stands within the range, around the walls. The rule - change it here:
local WHISTLE = {
  enabled = true,
  range = 300,     -- metres: a horse farther away does not hear it
  speed = 6.5,     -- metres per second: 1.5 a walk, 3.5 a trot, 6.5 a canter, 9.5 a gallop
  sound = true,    -- the others hear the whistle too
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

-- The welcome: the way role-play servers greet a joining player - the server holds them still at the spawn, and a web page with
-- the realm's rules and a short test (the player types a word) has the keyboard and the mouse from the start, in front of the
-- password box; the password comes after it. A player whose game draws no web pages, or whose page did not load, reads the
-- rules in the chat and goes straight to the password. Only with accounts (a database). The rule - change it here:
local WELCOME = {
  enabled = true,   -- false: the password box alone, nobody held
  name = nil,       -- the realm's name on the page; nil = "BasicRP on <the level>"
  rules = {
    "Stay in character in the world - /ooc and /b are for anything else.",
    "Do not kill another player's character without a reason in the story.",
    "Treat the townspeople and the other players with respect.",
  },
  answer = "agree",   -- the word a player types to accept them
}

-- Admins are the mode's. Here everyone who joins is one, the moment they connect: the server's own tools - /give, /tp,
-- /time, /kick ... - answer every player. With EVERYONE_ADMIN = false only the names in the KCDMP_ADMINS environment
-- variable ("Henry,Hans") are, promoted when they prove the name - /login (or /register) - or on connect when the server
-- keeps no accounts.
local EVERYONE_ADMIN = true
local admins = {}
for name in (os.getenv("KCDMP_ADMINS") or ""):gmatch("[^,%s]+") do admins[name:lower()] = true end

local function fmt(...) return string.format(...) end
local function say(pid, text) SendClientMessage(pid, COLOR_SERVER, text) end
local register, login, savePlace, savePlaces, makeMerchant, promote, horse, party, help, openCreator, saveLook   -- defined below
local askPassword, stageCreator, leaveCreator, unstuck
local greet, skipWelcome, rulesFirst, releaseHold, welcomeEvent   -- the welcome, defined below
local cartMaker, cartMakerEvent, closeCartMaker, dropCarts, despawnCart
local boardCommand, boardSpot   -- the admin's boards (web pages in the world), defined below
local PROGRESS   -- the progression rules, set in its section below
local DISCOVERY  -- the discovery rules, set in the section after it
local PULLDOWN   -- the pull-down rules, set beside the dice's below (OnPlayerSpawn hands the right out)
local pullReady, pullSafe = {}, {}   -- puller pid -> the server ms they may pull again; rider pid -> the server ms they are protected until
local CARRY       -- the carrying rules, set beside the pull-down's below (OnGameModeInit switches the grab on from them)
local carryCommand   -- /carry, /putdown and the admin's /carrying, /ko, /wake, defined below
local PICKPOCKET   -- the pickpocketing rules, set beside the carrying ones below (OnGameModeInit switches it on from them)
local pocketCommand, pocketRights   -- the admin's /pickpocket, and who may be robbed, defined below
local ITEMS        -- the carry items' rules, set beside the carrying ones below (OnGameModeInit switches the prompt on from them)
local itemsCommand   -- the admin's /carryitem, /carryitems, /clearitems, defined below

-- where a player stands at the spawn: the map's spawn point, a metre and a half apart per player id
local function spawnSpot(pid) return spawnX + 1.5 * (pid % 16), spawnY + 1.5 * (pid // 16), spawnZ, spawnYaw end

function promote(pid)
  local p = players[pid]
  if p and p.admin then return end
  if EVERYONE_ADMIN or admins[(GetPlayerName(pid) or ""):lower()] then
    if p then p.admin = true end
    SetPlayerAdmin(pid, true)
    say(pid, "You are an admin on this server.")
  end
end

-- a line to everyone within range of the speaker (the speaker included): the role-play "nearby" chat
local function sayNearby(pid, range, color, text)
  local x, y, z = GetPlayerPos(pid)
  -- one line to everyone in range, sent once (a loop of SendClientMessage cost a crowd's chat burst 50-120 ms ticks);
  -- a speaker not in the world yet still sees their own line
  if not x or SendClientMessageInRange(x, y, z, range, color, text, GetPlayerVirtualWorld(pid)) == 0 then SendClientMessage(pid, color, text) end
end

-- ------------------------------------------------------------------ the tables
-- players (one row per account, keyed by id; the name unique), player_items (one row per stack a player carries - what
-- they wear with worn = 1), player_horses (one row per horse a player owns: its breed and coat; active = the one /horse brings)
-- and horse_items (one row per stack in a horse's saddlebags, its gear with worn = 1). Plain SQL can then answer "who owns
-- this sword" (SELECT player_id FROM player_items WHERE item = ...); deleting a player deletes their items and horses. A tagged
-- item's row keeps its tag (item_id, tag_name, tag_text, tag_weight, tag_price, tag_model; NULL on a plain item).
-- player_progress (one row per stat and skill: its level, the XP toward the next and the perk points not spent yet; the
-- main level is a row of its own, "mainlevel", whose points are the pool), player_perks (one row per perk the character
-- holds), horse_stats (one row per stat an admin gave a horse) and player_outfits (one row per item each of the game's three
-- outfits wears; players.outfit is the one worn) follow the same way, as does player_quests (one row per keyed quest a character
-- holds: its state and its objectives' states, "done,active,hidden").
local ADDED_COLUMNS = {                   -- the columns added since the table's first version, for a table made before them
  { "money", "DOUBLE PRECISION" },        -- the purse
  { "level", "VARCHAR(32)" },             -- the level of the place (a klaster place is no good on kutnohorsko)
  { "look", "TEXT" },                     -- the character's look (LookToString's one line)
  { "nourishment", "DOUBLE PRECISION" },  -- how well fed the character is (the game's hunger state)
  { "energy", "DOUBLE PRECISION" },       -- how rested the character is (the game's exhaustion state)
  { "outfit", "SMALLINT" },               -- the outfit the character wears (1..3: the game's outfits A, B, C - player_outfits)
}
local COLUMNS_SQL = {                     -- a table's columns as each engine lists them (%s = the table)
  mysql = "SELECT column_name AS c FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = '%s'",
  postgres = "SELECT column_name::text AS c FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = '%s'",
  sqlite = "SELECT name AS c FROM pragma_table_info('%s')",   -- the tests' engine: a server offers a mode MySQL / MariaDB or PostgreSQL
}
local HORSE_COLUMNS = {                   -- player_horses' columns added since its first version
  { "coat", "VARCHAR(16)" },              -- the coat (GetHorseCoats), so the horse comes back the same colour
}
local STACK_COLUMNS = [[slot SMALLINT NOT NULL, item VARCHAR(36) NOT NULL, item_name VARCHAR(64), amount INT NOT NULL,
      health SMALLINT NOT NULL DEFAULT 100, worn SMALLINT NOT NULL DEFAULT 0]]
-- a tagged item's own id, name, text, weight and price (GivePlayerTaggedItem, SetPlayerItemWeight / Price) on its row of
-- player_items / horse_items, so a named prize or a quest key comes back as itself; NULL on a plain item. MySQL / MariaDB keep
-- the texts in utf8mb4 whatever the table's own character set (a name in any language).
local function tagColumns()
  local utf8 = db.driver == "mysql" and " CHARACTER SET utf8mb4" or ""
  return {
    { "item_id", "VARCHAR(255)" .. utf8 },
    { "tag_name", "VARCHAR(128)" .. utf8 },
    { "tag_text", "TEXT" .. utf8 },
    { "tag_weight", "DOUBLE PRECISION" },
    { "tag_price", "DOUBLE PRECISION" },
    { "tag_model", "VARCHAR(64)" },         -- the item class GUID whose model it shows (SetPlayerItemModel)
  }
end
local tagsSaved = {}   -- the stack tables that have the tag columns (a table the engine could not add them to saves plain rows)

local function columnsSql(list)
  local parts = {}
  for _, column in ipairs(list) do parts[#parts + 1] = column[1] .. " " .. column[2] end
  return table.concat(parts, ", ")
end

local function autoId()                   -- the engines' own words for a numbered key
  if db.driver == "postgres" then return "id SERIAL PRIMARY KEY" end
  if db.driver == "sqlite" then return "id INTEGER PRIMARY KEY AUTOINCREMENT" end
  return "id INT NOT NULL AUTO_INCREMENT PRIMARY KEY"
end

local function execInit(sql, what)
  local _, _, err = db:ExecuteSync(sql)
  if err then Log("BasicRP: " .. what .. " failed: " .. err) end
  return err == nil
end

-- the columns of `list` the table lacks added to it -> the set of its columns. Only the missing ones, so a start logs no
-- "Duplicate column" failures; when the engine cannot list them, every one is tried and the failures of those already there
-- are nothing.
local function addColumns(tableName, list)
  local have = {}
  for _, row in ipairs(db:QuerySync(string.format(COLUMNS_SQL[db.driver] or COLUMNS_SQL.mysql, tableName)) or {}) do
    if row.c then have[string.lower(row.c)] = true end
  end
  for _, column in ipairs(list) do
    if not have[column[1]] then
      local _, _, failed = db:ExecuteSync("ALTER TABLE " .. tableName .. " ADD COLUMN " .. column[1] .. " " .. column[2])
      if not failed then
        Log("BasicRP: added the column '" .. column[1] .. "' to the " .. tableName .. " table")
        have[column[1]] = true
      end
    end
  end
  return have
end

-- A table from before 2026-09-25 was keyed by the name: it gets an id and the name stays unique. MySQL / MariaDB and
-- PostgreSQL number the rows as the column is added; SQLite (the tests) cannot change a key and copies the table instead.
local function keyPlayersById(have)
  if db.driver == "mysql" then
    return execInit("ALTER TABLE players DROP PRIMARY KEY, ADD COLUMN id INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST, " ..
      "ADD UNIQUE KEY players_name (name)", "keying the players table by id")
  elseif db.driver == "postgres" then
    return execInit("ALTER TABLE players DROP CONSTRAINT IF EXISTS players_pkey", "dropping the name key")
      and execInit("ALTER TABLE players ADD COLUMN id SERIAL PRIMARY KEY", "keying the players table by id")
      and execInit("ALTER TABLE players ADD CONSTRAINT players_name_key UNIQUE (name)", "keeping the names unique")
  end
  local columns = {}
  for _, c in ipairs({ "name", "password", "visits", "x", "y", "z", "yaw", "money", "level", "inventory", "look", "horse", "last_seen",
    "nourishment", "energy", "outfit" }) do
    if have[c] then columns[#columns + 1] = c end
  end
  local list = table.concat(columns, ", ")
  return execInit([[CREATE TABLE players_new (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(24) NOT NULL UNIQUE,
      password VARCHAR(200) NOT NULL, visits INTEGER NOT NULL DEFAULT 0, x DOUBLE PRECISION, y DOUBLE PRECISION,
      z DOUBLE PRECISION, yaw DOUBLE PRECISION, money DOUBLE PRECISION, level VARCHAR(32), inventory TEXT, look TEXT, horse TEXT,
      last_seen VARCHAR(32), nourishment DOUBLE PRECISION, energy DOUBLE PRECISION, outfit SMALLINT)]], "copying the players table")
    and execInit("INSERT INTO players_new (" .. list .. ") SELECT " .. list .. " FROM players", "copying the players")
    and execInit("DROP TABLE players", "dropping the old players table")
    and execInit("ALTER TABLE players_new RENAME TO players", "renaming the players table")
end

-- a row's new id: MySQL / MariaDB hand it back, PostgreSQL and SQLite answer RETURNING (init: now; later: in cb)
local function insertIdSync(sql, params)
  if db.driver == "mysql" then
    local _, id, err = db:ExecuteSync(sql, params)
    return not err and id or nil, err
  end
  local rows, err = db:QuerySync(sql .. " RETURNING id", params)
  return rows and rows[1] and rows[1].id, err
end

function insertId(sql, params, cb)
  if db.driver == "mysql" then
    db:Execute(sql, params, function(_, id, err) cb(not err and id or nil, err) end)
  else
    db:Scalar(sql .. " RETURNING id", params, cb)
  end
end

-- the saves before the tables: the bags as "class:amount[:worn];..." and the horse as "breed|gear,...|class:amount:health;..."
local function oldBags(packed)
  local items = {}
  for entry in (packed or ""):gmatch("[^;]+") do
    local class, amount, worn = entry:match("^([^:]+):(%d+):?(%d*)$")
    amount, worn = tonumber(amount), tonumber(worn) or 0
    if class and amount and amount > 0 then
      for _ = 1, math.min(worn, amount) do items[#items + 1] = { class = class, amount = 1, health = 100, worn = true } end
      if amount > worn then items[#items + 1] = { class = class, amount = amount - worn, health = 100 } end
    end
  end
  return items
end

local function oldHorse(line)
  local breed, gear, bags = (line or ""):match("^([^|]*)|([^|]*)|(.*)$")
  if not breed then return nil end
  local items = {}
  for class in gear:gmatch("[^,]+") do items[#items + 1] = { class = class, amount = 1, health = 100, worn = true } end
  for class, amount, health in bags:gmatch("([^:;]+):(%d+):(%d+)") do
    items[#items + 1] = { class = class, amount = tonumber(amount), health = tonumber(health) }
  end
  return breed, items
end

-- the first start after the tables came: every account's text saves become rows, the old columns emptied
local function moveOldSaves(have)
  if not (have.inventory or have.horse) then return end
  local cols = (have.inventory and "inventory" or "NULL AS inventory") .. ", " .. (have.horse and "horse" or "NULL AS horse")
  local where = {}
  if have.inventory then where[#where + 1] = "(inventory IS NOT NULL AND inventory <> '')" end
  if have.horse then where[#where + 1] = "(horse IS NOT NULL AND horse <> '')" end
  local rows, err = db:QuerySync("SELECT id, " .. cols .. " FROM players WHERE " .. table.concat(where, " OR "))
  if err then Log("BasicRP: the old saves could not be read: " .. err) return end
  local moved = 0
  for _, row in ipairs(rows or {}) do
    for slot, it in ipairs(oldBags(row.inventory)) do
      db:ExecuteSync("INSERT INTO player_items (player_id, slot, item, item_name, amount, health, worn) VALUES (@p, @s, @i, @n, @a, @h, @w)",
        { p = row.id, s = slot, i = it.class, n = itemName(it.class), a = it.amount, h = it.health, w = it.worn and 1 or 0 })
    end
    local breed, items = oldHorse(row.horse)
    if breed then
      local horseId = insertIdSync("INSERT INTO player_horses (player_id, soul, active, created_at) VALUES (@p, @s, 1, @t)",
        { p = row.id, s = breed ~= "" and breed or DB_NULL, t = os.date("!%Y-%m-%dT%H:%M:%SZ") })
      for slot, it in ipairs(horseId and items or {}) do
        db:ExecuteSync("INSERT INTO horse_items (horse_id, slot, item, item_name, amount, health, worn) VALUES (@hid, @s, @i, @n, @a, @h, @w)",
          { hid = horseId, s = slot, i = it.class, n = itemName(it.class), a = it.amount, h = it.health, w = it.worn and 1 or 0 })
      end
    end
    local sets = {}
    if have.inventory then sets[#sets + 1] = "inventory = NULL" end
    if have.horse then sets[#sets + 1] = "horse = NULL" end
    db:ExecuteSync("UPDATE players SET " .. table.concat(sets, ", ") .. " WHERE id = @p", { p = row.id })
    moved = moved + 1
  end
  if moved > 0 then Log(fmt("BasicRP: %d account(s)' saved bags and horses moved into the tables", moved)) end
end

function OnGameModeInit()
  Log(fmt("BasicRP on %s: spawn %.1f %.1f %.1f, %d slots", GetLevel(), spawnX, spawnY, spawnZ, GetMaxPlayers()))
  SetStoryQuests(false)   -- the game's own quests stay asleep in the players' games; true lets them run (they can take a player's things)
  SetXPRate(PROGRESS.xp_rate)
  SetCarrying(CARRY.enabled, CARRY)   -- the grab off by default: the CARRY table below (or an admin's /carrying on) switches it on
  SetPickpocketing(PICKPOCKET.enabled, PICKPOCKET)   -- off by default: the PICKPOCKET table below (or an admin's /pickpocket on) switches it on
  SetItemCarrying(ITEMS.enabled, ITEMS)   -- the "Pick up" prompt on carry items: the ITEMS table below (or an admin's /carryitems on|off)
  SetVoiceLevels(VOICE.levels, VOICE.default)   -- whisper, normal, shout on the voice level key: the VOICE table above
  SetVoiceOcclusion(VOICE.occlusion)            -- a voice behind a wall is muffled
  if TOWN.enabled then RegisterKeyBinding("basicrp.menu", "Open or close the BasicRP menu", TOWN.menu_key) end
  if not db then
    Log("BasicRP: no [gamemode.database] in server.toml - accounts are off until the owner connects one")
    return
  end
  SetSecretCommand("register")   -- the clients mask the password as it is typed, the line stays out of their history
  SetSecretCommand("login")
  local _, _, err = db:ExecuteSync("CREATE TABLE IF NOT EXISTS players (" .. autoId() .. [[,
      name VARCHAR(24) NOT NULL UNIQUE,
      password VARCHAR(200) NOT NULL,
      visits INTEGER NOT NULL DEFAULT 0,
      x DOUBLE PRECISION, y DOUBLE PRECISION, z DOUBLE PRECISION, yaw DOUBLE PRECISION,
      money DOUBLE PRECISION,
      level VARCHAR(32),
      look TEXT,
      nourishment DOUBLE PRECISION,
      energy DOUBLE PRECISION,
      outfit SMALLINT,
      last_seen VARCHAR(32))]])
  if err then
    Log("BasicRP: the players table could not be made: " .. err)
    db = nil
    return
  end
  local have = addColumns("players", ADDED_COLUMNS)
  if next(have) and not have.id then
    if not keyPlayersById(have) then db = nil return end
    Log("BasicRP: the players table is keyed by id now (the names stay unique)")
  end
  local inline = db.driver == "mysql"   -- MySQL / MariaDB index inside CREATE TABLE; the others after it
  -- the foreign keys at the table's end: MySQL ignores one written on the column
  local tags = columnsSql(tagColumns())
  local ok = execInit("CREATE TABLE IF NOT EXISTS player_items (player_id INT NOT NULL, " .. STACK_COLUMNS .. ", " .. tags ..
      ", PRIMARY KEY (player_id, slot)" .. (inline and ", KEY player_items_item (item)" or "") ..
      ", FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_items table")
    and execInit("CREATE TABLE IF NOT EXISTS player_horses (" .. autoId() .. ", player_id INT NOT NULL, soul VARCHAR(64), " ..
      "active SMALLINT NOT NULL DEFAULT 0, created_at VARCHAR(32), coat VARCHAR(16), " ..
      "FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_horses table")
    and execInit("CREATE TABLE IF NOT EXISTS horse_items (horse_id INT NOT NULL, " .. STACK_COLUMNS .. ", " .. tags ..
      ", PRIMARY KEY (horse_id, slot)" .. (inline and ", KEY horse_items_item (item)" or "") ..
      ", FOREIGN KEY (horse_id) REFERENCES player_horses(id) ON DELETE CASCADE)", "the horse_items table")
    and execInit("CREATE TABLE IF NOT EXISTS player_progress (player_id INT NOT NULL, kind VARCHAR(8) NOT NULL, name VARCHAR(32) NOT NULL, " ..
      "level SMALLINT NOT NULL, xp DOUBLE PRECISION NOT NULL, points SMALLINT NOT NULL DEFAULT 0, PRIMARY KEY (player_id, kind, name)" ..
      (inline and ", KEY player_progress_name (name)" or "") ..
      ", FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_progress table")
    and execInit("CREATE TABLE IF NOT EXISTS player_perks (player_id INT NOT NULL, perk VARCHAR(36) NOT NULL, PRIMARY KEY (player_id, perk)" ..
      (inline and ", KEY player_perks_perk (perk)" or "") ..
      ", FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_perks table")
    and execInit("CREATE TABLE IF NOT EXISTS horse_stats (horse_id INT NOT NULL, stat VARCHAR(16) NOT NULL, level SMALLINT NOT NULL, " ..
      "PRIMARY KEY (horse_id, stat), FOREIGN KEY (horse_id) REFERENCES player_horses(id) ON DELETE CASCADE)", "the horse_stats table")
    and execInit("CREATE TABLE IF NOT EXISTS player_outfits (player_id INT NOT NULL, outfit SMALLINT NOT NULL, slot SMALLINT NOT NULL, " ..
      "item VARCHAR(36) NOT NULL, item_name VARCHAR(64), PRIMARY KEY (player_id, outfit, slot), " ..
      "FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_outfits table")
  if ok and not inline then
    execInit("CREATE INDEX IF NOT EXISTS player_items_item ON player_items (item)", "the player_items index")
    execInit("CREATE INDEX IF NOT EXISTS player_horses_player ON player_horses (player_id)", "the player_horses index")
    execInit("CREATE INDEX IF NOT EXISTS horse_items_item ON horse_items (item)", "the horse_items index")
    execInit("CREATE INDEX IF NOT EXISTS player_progress_name ON player_progress (name)", "the player_progress index")
    execInit("CREATE INDEX IF NOT EXISTS player_perks_perk ON player_perks (perk)", "the player_perks index")
  end
  if not ok then db = nil return end
  addColumns("player_horses", HORSE_COLUMNS)   -- a table made before the coat
  for _, tbl in ipairs({ "player_items", "horse_items" }) do   -- tables made before the tagged items' columns
    local have = addColumns(tbl, tagColumns())
    tagsSaved[tbl] = have.item_id and have.tag_name and have.tag_text and have.tag_weight and have.tag_price and have.tag_model or false
    if not tagsSaved[tbl] then Log("BasicRP: the " .. tbl .. " table has no tag columns - tagged items are saved as plain ones") end
  end
  moveOldSaves(have)
  setupDiscovery()   -- the discovery table and what to track, only when a DISCOVERY rule is on
  setupQuests()      -- the quests table, when QUESTS.keep
  Log("BasicRP: accounts on (" .. db.driver .. ")")
  SetTimer(savePlaces, 60000, true)   -- every minute: a server that stops keeps everyone's place
end

-- ------------------------------------------------------------------ the merchant at the spawn
-- A vendor (CreateVendor: an NPC actor nobody can hurt with a shop on it); the use key opens the game's own trade screen.
-- The shop sells a few useful things, buys anything the catalogue prices at half its worth but papers, and has 500
-- Groschen to pay with (SetShopMoney tops it up; nil = bottomless).
local merchant, store
-- where he stands: a known spot per level (klaster: the monastery yard by the spawn; kutnohorsko: the Suchdol fortress
-- yard, by the spawn, on the ground), else 4 m from the spawn on the ground (z below 0: the server's world data finds it)
local MERCHANT_SPOT = { klaster = {1278.1, 1088.8, 26.0}, kutnohorsko = {749.0, 3349.0, -1} }

function makeMerchant()
  store = CreateShop("General store", 0.5, 500)
  if not store then Log("BasicRP: no shop could be made") return end
  SetShopItem(store, "torch_weapon", 5)                  -- unlimited
  SetShopItem(store, "arrow_normal", 0.5, 200)
  SetShopItem(store, "bandage_classic", 12, 20)
  SetShopItem(store, "shortswordBroad", 90, 3)
  SetShopItem(store, "GambesonLong01_m01_C3", 60, 2)
  SetShopBuyCategories(store, {"-Document"})              -- never papers: the trade screen does not even offer them
  local spot = MERCHANT_SPOT[GetLevel()] or {spawnX + 4, spawnY + 4, -1}   -- z below 0 = on the ground (the server's world data finds it)
  local mx, my, mz = spot[1], spot[2], spot[3]
  local yaw = math.deg(math.atan(-(spawnX - mx), spawnY - my)) % 360   -- facing the spawn point
  merchant = CreateVendor(store, nil, mx, my, mz, yaw, "Merchant")
  if not merchant then Log("BasicRP: no merchant could be made") return end
  SetEntityData(merchant, "role", "merchant")
  Log(fmt("BasicRP: the merchant stands at %.1f %.1f %.1f with shop %d", mx, my, mz, store))
end

makeMerchant()

-- ------------------------------------------------------------------ the town: its people, three more shops and the stable
-- A role-play server's spawn is a town the server owns, and this one is too: a smith, a tailor and an apothecary sell from
-- their stalls, an innkeeper and a stable master talk (the game's own dialogue page; the stable master's offer is a web page of
-- this mode's - gamemodes/basicrp/ui/stable - or the dialogue for a player whose game draws no web pages), a guard walks his
-- rounds, another keeps watch with a torch, and townsfolk go about their work. Every one has a face of their own
-- (SetActorLook) - a woman among them - and the stable's horses each wear their own coat: the people and horses real servers
-- fill their towns with, so a test round here meets what players meet there. TOWN.enabled = false leaves the merchant alone.
-- The people stand around the level's town centre (TOWN_CENTRE, else the spawn), each row's `at` metres east and north of it.
TOWN = {
  enabled = true,
  stable_price = 300,   -- Groschen for trading your horse for one of another coat (its gear and saddlebags stay yours)
  beer_price = 3,       -- Groschen for the innkeeper's beer
  guard_speed = 1.3,    -- m/s on the rounds (a walk)
  guard_pause = 6,      -- seconds the guard stands at each corner of his rounds
  menu_key = "insert",  -- the key the menu starts on (a player can bind another); /menu opens it too
}
local TOWN_CENTRE = { klaster = {1280.0, 1088.0}, kutnohorsko = {752.0, 3346.0} }
-- shop: {title, what it pays for what it buys (0 = buys nothing), its purse, {item, price, stock (nil = unlimited)} ...}
local TOWN_PEOPLE = {
  { role = "smith", name = "Smith", at = {-8, -4}, anim = "smith",
    look = "body=m_body_tan_05;head=m_head_050;hair=m_hair_014_dark_brown;beard=m_beard_00",
    shop = { "Smithy", 0.5, 600, { {"shortswordBroad", 90, 3}, {"daggerCommon", 25, 5}, {"axeWork01", 30, 4}, {"arrow_normal", 0.5, 200} } } },
  { role = "tailor", name = "Tailor", at = {-8, 3},
    look = "body=m_body_pale_02;head=m_head_074;hair=m_hair_018_light_brown;beard=m_beard_00",
    shop = { "Tailor", 0.4, 400, { {"TunicLong01_m01_C", 35, 4}, {"HoseJoined01_m01_C", 100, 3}, {"BootsAnkle01_m01_C", 45, 3}, {"Cap17_m02_C", 55, 2},
      {"GambesonLong01_m01_C3", 60, 2} } } },
  { role = "apothecary", name = "Apothecary", at = {6, 5},
    look = "body=m_body_pale_old_01;head=m_head_026;hair=m_hair_003_grey;beard=m_beard_17",
    shop = { "Apothecary", 0.4, 300, { {"bandage_classic", 12, 20}, {"herb_chamomile", 1, 30}, {"herb_comfrey", 3, 20}, {"potion_aesop", 40, 5} } } },
  { role = "innkeeper", name = "Innkeeper", at = {4, -5}, prompt = "Talk",
    look = "body=m_body_tan_old_06;head=m_head_042;hair=m_hair_005_blonde;beard=m_beard_18" },
  { role = "maid", name = "Barmaid", at = {1, -5}, anim = "sweep",
    look = "gender=female;body=f_body_pale_01;head=f_head_013;hair=f_hair_004_blonde" },
  { role = "stable", name = "Stable master", at = {-3, 9}, prompt = "Talk",
    look = "body=m_body_tan_02;head=m_head_030;hair=m_hair_003_ginger;beard=m_beard_14" },
  { role = "guard", name = "Guard", at = {0, -8}, patrol = { {-6, -8}, {6, -8}, {6, 8}, {-6, 8} },
    look = "body=m_body_roma_02;head=m_head_033;hair=m_hair_013_ginger;beard=m_beard_13" },
  { role = "watch", name = "Watchman", at = {3, 11}, torch = true,
    look = "body=m_body_pale_04;head=m_head_062;hair=m_hair_010_black;beard=m_beard_00" },
  { role = "woodcutter", name = "Woodcutter", at = {-10, 8}, anim = "chop",
    look = "body=m_body_tan_03;head=m_head_048;hair=m_hair_009_white;beard=m_beard_03" },
  { role = "pilgrim", name = "Pilgrim", at = {10, 2}, anim = "pray",
    look = "body=m_body_roma_04;head=m_head_079;hair=m_hair_011_light_brown;beard=m_beard_18" },
}
local STABLE_HORSES = { { coat = "palomino", at = {-6, 11}, yaw = 90 }, { coat = "seal_brown", at = {-1, 12}, yaw = 270 } }
local INN_NEWS = {
  "They say the roads north of here are thick with robbers again. Ride in company.",
  "The smith swears his blades hold an edge longer than the ones from Kuttenberg. Ask him.",
  "A merchant paid in bad coin last week. Count your groschen twice.",
  "The stable master has a palomino he will not stop talking about.",
  "The pilgrim by the well has walked all the way from Prague, or so he says.",
}
local DIALOGUE_INN, DIALOGUE_INN_NEWS, DIALOGUE_STABLE = 501, 502, 511   -- this mode's dialogue page numbers
local MENU = "menu"                                                    -- the web frames of gamemodes/basicrp/ui
local town = { people = {}, centre = nil }   -- role -> actor id; the centre {x, y}
local stableOffer = {}                       -- pid -> the dialogue's page of coats (1 or 2) while it is open
local stableOpen = {}                        -- pid -> true while the stable's web page is up

local function townPoint(at)
  return town.centre[1] + at[1], town.centre[2] + at[2]
end
local function faceCentre(x, y)
  return math.deg(math.atan(-(town.centre[1] - x), town.centre[2] - y)) % 360
end

-- a guard's rounds: the next corner, a pause at each (OnActorArrive)
local function walkOn(id, row)
  local corner = (tonumber(GetEntityData(id, "corner")) or 0) % #row.patrol + 1
  SetEntityData(id, "corner", corner)
  local x, y = townPoint(row.patrol[corner])
  local _, _, z = GetEntityPos(id)
  MoveActor(id, x, y, z or -1, TOWN.guard_speed)
end

local function makeTown()
  if not TOWN.enabled then return end
  town.centre = TOWN_CENTRE[GetLevel()] or {spawnX, spawnY}
  local made = 0
  for _, row in ipairs(TOWN_PEOPLE) do
    local x, y = townPoint(row.at)
    local yaw = faceCentre(x, y)
    local id
    if row.shop then
      local shop = CreateShop(row.shop[1], row.shop[2], row.shop[3])
      if shop then
        for _, item in ipairs(row.shop[4]) do
          if not SetShopItem(shop, item[1], item[2], item[3]) then Log(fmt("BasicRP: the %s has no %s to sell", row.name, item[1])) end
        end
        if row.shop[2] > 0 then SetShopBuyCategories(shop, {"-Document"}) end
        id = CreateVendor(shop, nil, x, y, -1, yaw, row.name)   -- z below 0: on the ground
      end
    else
      id = CreateActor("", x, y, -1, yaw, row.name)
      if id then SetActorInvulnerable(id, true) end
    end
    if id then
      made = made + 1
      town.people[row.role] = id
      SetEntityData(id, "role", row.role)
      local ok, why = SetActorLook(id, row.look)
      if not ok then Log(fmt("BasicRP: the %s's look was refused: %s", row.name, tostring(why))) end
      if row.prompt then SetActorPrompt(id, row.prompt) end
      if row.anim then SetActorAnim(id, row.anim) end
      if row.torch then SetActorTorch(id, true) end
      if row.patrol then walkOn(id, row) end
    else
      Log(fmt("BasicRP: the %s could not be made", row.name))
    end
  end
  -- the stable's horses, on the ground beside the stable master (a horse is not put on the ground by the server: GetGroundZ)
  local mz   -- the stable master's height, where the server put him on the ground
  if town.people.stable then mz = select(3, GetEntityPos(town.people.stable)) end
  for _, h in ipairs(STABLE_HORSES) do
    local x, y = townPoint(h.at)
    local z = mz and mz > 0 and (GetGroundZ(x, y, mz + 1.5) or mz) or nil
    local horse = z and CreateHorse(x, y, z, h.yaw, -1, nil, nil, h.coat)
    if horse then
      SetHorseInvulnerable(horse, true)
      SetEntityData(horse, "role", "stable_horse")
    else
      Log("BasicRP: a stable horse could not be made (no ground found at " .. fmt("%.1f %.1f", x, y) .. ")")
    end
  end
  Log(fmt("BasicRP: the town at %.1f %.1f - %d of %d people", town.centre[1], town.centre[2], made, #TOWN_PEOPLE))
end

makeTown()

-- ------------------------------------------------------------------ the town's life (actor life, 2026-10-08)
-- The town's people live a little: the pilgrim sits on the nearest bench and the woodcutter debarks logs at the nearest trestle of the
-- level (the game's own animations), a courier rides his rounds on horseback, two carters stand talking, the innkeeper and the
-- barmaid gossip now and then, the smith grumbles at his anvil, the guard mutters on his rounds and the innkeeper greets whoever
-- comes to talk - the game's own lines, heard from the actor. Only while players are near (nobody hears an empty town). The lines
-- and the level's seats come from the server's tables export of this version: without it the people keep their old poses.
-- TOWN_LIFE.enabled = false leaves the town as it was.
TOWN_LIFE = {
  enabled = true,
  near = 25,                 -- metres: a player this close to someone makes them talk
  gossip_every = 150,        -- seconds between the innkeeper's and the barmaid's gossip
  bark_every = 45,           -- seconds between the smith's grumbles and the merchant's cries
  courier_speed = 4,         -- m/s: the courier's trot
  courier_pause = 20,        -- seconds he waits at each end of his round
}
local COURIER_ROUTE = { klaster = { {-30, -25}, {35, 20} }, kutnohorsko = { {-30, -25}, {-1, 5} } }   -- metres from the town centre (kutnohorsko: the pond outside, the yard)
local life = {}   -- courier, courierHorse, courierLeg, carters {a, b}

-- the courier rides to the other end of his round
local function courierRide(id)
  local x, y = townPoint(COURIER_ROUTE[GetLevel()][life.courierLeg % 2 + 1])
  MoveActor(id, x, y, -1, TOWN_LIFE.courier_speed)
end

local function playersNear(id, radius)
  local x, y, z = GetEntityPos(id)
  return x ~= nil and #GetPlayersInRange(x, y, z, radius) > 0
end

-- the nearest free seat or work spot of the level for one of the town's people (its old pose stays when there is none)
local function useNearest(id, kind, radius)
  local x, y, z = GetEntityPos(id)
  local spot = x and GetNearestSmartObject(x, y, z, radius, kind)
  if spot and SetActorUse(id, spot.key) then
    Log(fmt("BasicRP: %s goes to %s (%s, %.0f m)", GetEntityName(id), spot.key, spot.activity, spot.distance))
    return true
  end
  return false
end

local function makeTownLife()
  if not TOWN.enabled or not TOWN_LIFE.enabled or not town.centre then return end
  if town.people.pilgrim then useNearest(town.people.pilgrim, "sit", 20) end
  if town.people.woodcutter then useNearest(town.people.woodcutter, "debarkingWood", 40) end   -- a trestle near him, else he keeps chopping
  -- two carters talking by the road
  local ax, ay = townPoint({2, 3})
  local a = CreateActor("", ax, ay, -1, 0, "Carter")
  local b = a and CreateActor("", ax + 0.5, ay + 1.5, -1, 180, "Miller")
  if a and b then
    SetActorInvulnerable(a, true) SetActorInvulnerable(b, true)
    SetActorLook(a, "body=m_body_tan_04;head=m_head_012;hair=m_hair_012_dark_brown;beard=m_beard_05")
    SetActorLook(b, "body=m_body_pale_03;head=m_head_057;hair=m_hair_011_light_brown;beard=m_beard_11")
    life.carters = {a, b}
    PlayActorPairAnim(a, b, "talk")
  end
  -- the courier on his horse
  local route = COURIER_ROUTE[GetLevel()]
  if route then
    local cx, cy = townPoint(route[1])
    local courier = CreateActor("", cx, cy, -1, 90, "Courier")
    if courier then
      SetActorInvulnerable(courier, true)
      SetActorLook(courier, "body=m_body_tan_01;head=m_head_011;hair=m_hair_002_black;beard=m_beard_02")
      local _, _, cz = GetEntityPos(courier)
      local horse = CreateHorse(cx + 1.5, cy, cz or -1, 90, -1, nil, nil, "black")
      if horse then
        SetHorseInvulnerable(horse, true)
        SetEntityData(horse, "role", "courier_horse")
        life.courier, life.courierHorse, life.courierLeg = courier, horse, 1
        if MountActor(courier, horse, true) then courierRide(courier) end   -- seated at once (the callbacks are not up while the mode loads)
      end
    end
  end
  -- the talk: the gossip at the inn, the smith's grumbles and the merchant's cries, while players are near
  SetTimer(function()
    local inn, maid = town.people.innkeeper, town.people.maid
    if inn and maid and playersNear(inn, TOWN_LIFE.near) and not IsActorSpeaking(inn) then PlayActorConversation(inn, maid, "gossip") end
    if life.carters and playersNear(life.carters[1], TOWN_LIFE.near) and not IsActorSpeaking(life.carters[1]) then
      PlayActorConversation(life.carters[1], life.carters[2], "gossip")   -- they talk over their pair: the gestures from the waist up
    end
  end, TOWN_LIFE.gossip_every * 1000, true)
  SetTimer(function()
    local smith = town.people.smith
    if smith and playersNear(smith, 15) then PlayActorBark(smith, "smith_work") end
    if merchant and playersNear(merchant, TOWN_LIFE.near) then PlayActorBark(merchant, "market_call") end
  end, TOWN_LIFE.bark_every * 1000, true)
  Log("BasicRP: the town's life - seats, work, the courier's rounds, the carters' talk, the gossip")
end

makeTownLife()

function OnActorMount(id, horse)
  if id == life.courier then courierRide(id) end   -- back in the saddle (a mode that mounts him again): off on his round
end

function OnActorArrive(id)
  if id == life.courier then
    -- at one end of his round: he waits, greets whoever is near, and rides back
    life.courierLeg = life.courierLeg % 2 + 1
    if playersNear(id, TOWN_LIFE.near) then PlayActorBark(id, "greeting") end
    SetTimer(function() if GetEntityKind(id) and IsActorMounted(id) then courierRide(id) end end, TOWN_LIFE.courier_pause * 1000)
    return
  end
  if GetEntityData(id, "role") ~= "guard" then return end
  if TOWN_LIFE.enabled and math.random() < 0.3 and playersNear(id, TOWN_LIFE.near) then PlayActorBark(id, "guard_mutter") end
  for _, row in ipairs(TOWN_PEOPLE) do
    if row.role == "guard" and row.patrol then
      SetTimer(function() if GetEntityKind(id) then walkOn(id, row) end end, TOWN.guard_pause * 1000)
      return
    end
  end
end

-- the notices: a short line in the corner of the screen (the web frame "notices"), the chat for a player whose game draws no pages
local function notify(pid, text)
  if IsPlayerWebReady(pid) then
    ShowPlayerWebFrame(pid, "notices")
    SendPlayerWebMessage(pid, "notices", { text = text })
  else
    say(pid, text)
  end
end

local function coatName(coat) return (coat or "?"):gsub("_", " ") end

-- the stable: trade the player's horse for one of another coat. The horse keeps its row, gear and saddlebags - only its coat
-- changes, at once if it is out and for good in player_horses (the admin's /horsecoat does the same for free).
local function buyCoat(pid, coat)
  local p = players[pid]
  local mount = ownHorse(pid)
  local id = mount and tonumber(GetEntityData(mount, "db_id")) or (p and p.savedHorse and p.savedHorse.dbId)
  if not mount and not id then notify(pid, "You have no horse to trade - /horse brings you your first one.") return false end
  if mount and not id and db and p and p.logged then notify(pid, "Your horse is not in the books yet - try again in a moment.") return false end
  if (GetPlayerMoney(pid) or 0) < TOWN.stable_price then
    notify(pid, fmt("A horse of another coat costs %d groschen - you have %d.", TOWN.stable_price, math.floor(GetPlayerMoney(pid) or 0)))
    return false
  end
  if mount and not SetHorseCoat(mount, coat) then notify(pid, "The stable has no such horse.") return false end
  coat = mount and GetHorseCoat(mount) or coat
  GivePlayerMoney(pid, -TOWN.stable_price)
  if id and db then
    db:Execute("UPDATE player_horses SET coat = @c WHERE id = @h", { c = coat, h = id }, function(_, _, err)
      if err then Log("BasicRP: the traded horse's coat was not saved: " .. tostring(err)) end
    end)
  end
  if p and p.savedHorse and p.savedHorse.dbId == id then p.savedHorse.coat = coat end
  notify(pid, fmt("Your horse is %s now - %d groschen to the stable master.", coatName(coat), TOWN.stable_price))
  Log(fmt("BasicRP: %s traded their horse for a %s one", GetPlayerName(pid), coat))
  return true
end

local function currentCoat(pid)
  local mount, p = ownHorse(pid), players[pid]
  return mount and GetHorseCoat(mount) or (p and p.savedHorse and p.savedHorse.coat) or nil
end

-- the stable master's offer as the game's dialogue: six coats a page, "More" and "Back" between the two
local function stableDialogue(pid, page)
  local coats, options = GetHorseCoats(), {}
  stableOffer[pid] = page
  local first = page == 1 and 1 or 7
  for i = first, math.min(first + 5, #coats) do
    options[#options + 1] = { text = fmt("A %s horse - %d groschen", coatName(coats[i]), TOWN.stable_price), enabled = coats[i] ~= currentCoat(pid) }
  end
  options[#options + 1] = page == 1 and "Show me the others" or "Back to the first ones"
  options[#options + 1] = "Nothing today"
  ShowPlayerDialogue(pid, DIALOGUE_STABLE, nil, fmt("Your horse for one of another coat, %d groschen - the saddle and the bags go with you. Which one?",
    TOWN.stable_price), options, town.people.stable)
end

local function openStable(pid)
  if IsPlayerWebReady(pid) then
    SendPlayerWebMessage(pid, "stable", { coats = GetHorseCoats(), current = currentCoat(pid), price = TOWN.stable_price,
      money = math.floor(GetPlayerMoney(pid) or 0), hasHorse = ownHorse(pid) ~= nil or (players[pid] and players[pid].savedHorse) ~= nil })
    stableOpen[pid] = true
    ShowPlayerWebFrame(pid, "stable")
    SetPlayerWebFocus(pid, "stable", false, true)   -- the mouse; the keys stay the game's
  else
    stableDialogue(pid, 1)
  end
end

local function innDialogue(pid)
  ShowPlayerDialogue(pid, DIALOGUE_INN, nil, "Welcome, traveller. Sit, drink, warm yourself. What will it be?",
    { fmt("A beer, please (%d groschen)", TOWN.beer_price), "What news?", "Nothing, thank you" }, town.people.innkeeper)
end

function OnPlayerInteractActor(pid, id)
  local role = GetEntityData(id, "role")
  if role == "innkeeper" then
    if TOWN_LIFE.enabled then PlayActorBark(id, "greet_player") end   -- the game's own greeting, heard by everyone around
    innDialogue(pid)
    return false
  end
  if role == "stable" then openStable(pid) return false end
  if role then SendClientMessage(pid, COLOR_PURPLE, fmt("* %s greets %s.", GetEntityName(id), GetPlayerName(pid))) end
  return true   -- a vendor's shop opens
end

function OnDialogueResponse(pid, dialogid, option, reason)
  if dialogid == DIALOGUE_INN then
    if option == 1 then
      if (GetPlayerMoney(pid) or 0) < TOWN.beer_price then
        ShowPlayerDialogue(pid, DIALOGUE_INN_NEWS, nil, "No coin, no beer. Come back when your purse is heavier.", { "Goodbye" }, town.people.innkeeper)
      else
        GivePlayerMoney(pid, -TOWN.beer_price)
        GivePlayerItem(pid, "beer")
        notify(pid, fmt("A beer from the innkeeper - %d groschen.", TOWN.beer_price))
      end
    elseif option == 2 then
      ShowPlayerDialogue(pid, DIALOGUE_INN_NEWS, nil, INN_NEWS[math.random(#INN_NEWS)], { "Anything else?", "Goodbye" }, town.people.innkeeper)
    end
  elseif dialogid == DIALOGUE_INN_NEWS then
    if option == 1 then innDialogue(pid) end
  elseif dialogid == DIALOGUE_STABLE then
    local page = stableOffer[pid] or 1
    stableOffer[pid] = nil
    local coats = GetHorseCoats()
    local shown = math.min(6, #coats - (page == 1 and 0 or 6))
    if option >= 1 and option <= shown then
      buyCoat(pid, coats[(page == 1 and 0 or 6) + option])
    elseif option == shown + 1 then
      stableDialogue(pid, page == 1 and 2 or 1)
    end
  end
end

-- the menu (the web frame "menu"): the help, the town and the player's own purse and horse; /menu or its key
local menuOpen = {}
local function menuData(pid)
  local lines = {}
  help(pid, lines)
  local people = { merchant and { name = "Merchant", shop = "General store" } or nil }
  for _, row in ipairs(TOWN_PEOPLE) do
    if town.people[row.role] then people[#people + 1] = { name = row.name, shop = row.shop and row.shop[1] or nil, talk = row.prompt ~= nil } end
  end
  return { help = lines, town = people, money = math.floor(GetPlayerMoney(pid) or 0), horse = currentCoat(pid) and coatName(currentCoat(pid)) or nil,
    name = GetPlayerName(pid), level = GetLevelName() }
end
local function toggleMenu(pid)
  if menuOpen[pid] then
    menuOpen[pid] = nil
    HidePlayerWebFrame(pid, MENU)
    return
  end
  if not IsPlayerWebReady(pid) then help(pid) return end   -- no web pages in this player's game: the chat's list
  menuOpen[pid] = true
  SendPlayerWebMessage(pid, MENU, menuData(pid))
  ShowPlayerWebFrame(pid, MENU)
  SetPlayerWebFocus(pid, MENU, false, true)
end
TOWN.toggleMenu = toggleMenu

-- what the pages send (OnClientEvent's fourth argument is the frame): checked like any input from a player
local function townWebEvent(pid, name, payload, source)
  if source == "stable" then
    if name == "stable.buy" then
      local order = JsonDecode(payload or "")
      local coat = type(order) == "table" and type(order.coat) == "string" and order.coat or nil
      local known = false
      for _, c in ipairs(GetHorseCoats()) do known = known or c == coat end
      if known and buyCoat(pid, coat) then stableOpen[pid] = nil HidePlayerWebFrame(pid, "stable") end
    elseif name == "stable.close" then
      stableOpen[pid] = nil
      HidePlayerWebFrame(pid, "stable")
    end
    return true
  end
  if source == MENU then
    if name == "menu.close" and menuOpen[pid] then toggleMenu(pid) end
    return true
  end
  if source == "notices" then return true end
  return false
end
TOWN.webEvent = townWebEvent

function OnPlayerKeyBinding(pid, name, pressed)
  if name == "basicrp.menu" and pressed then toggleMenu(pid) end
end

function OnPlayerWebStatus(pid, status, reason)
  if status ~= "ready" then menuOpen[pid], stableOpen[pid] = nil, nil end
  local p = players[pid]
  if p then p.webStatus = status end
  if status ~= "ready" and status ~= "starting" then skipWelcome(pid) end   -- no page will come: the rules in the chat
end

-- a page loaded: the windows stay hidden until they are asked for (a preloaded frame is drawn as soon as it loads on clients up to
-- 0.39 - the pages also draw nothing until their first message), the notices stay up (they are transparent but for a line)
function OnPlayerWebReady(pid, frame)
  if frame == MENU and not menuOpen[pid] then HidePlayerWebFrame(pid, MENU) end
  if frame == "stable" and not stableOpen[pid] then HidePlayerWebFrame(pid, "stable") end
  if frame == "notices" then ShowPlayerWebFrame(pid, "notices") end
  if frame == "welcome" and (not players[pid] or players[pid].rules ~= "pending") then HidePlayerWebFrame(pid, "welcome") end   -- late: the rules went to the chat
end

TOWN.forget = function(pid) menuOpen[pid], stableOffer[pid], stableOpen[pid] = nil, nil, nil end

function OnPlayerBuy(pid, shop, class, amount, price)
  local info = GetItemInfo(class)
  Log(fmt("BasicRP: %s buys %d x %s at %.1f", GetPlayerName(pid), amount, info and info.display or class, price))
  return true
end

function OnPlayerShopDeal(pid, shop, deal)
  if deal.cost > 0 and deal.proceeds > 0 then
    Log(fmt("BasicRP: %s trades - pays %.1f, gets %.1f", GetPlayerName(pid), deal.cost, deal.proceeds))
  end
  return true
end

function OnPlayerCloseShop(pid, shop, reason)
  if reason == "you walked away" then say(pid, "The merchant waves you goodbye.") end
end

-- ------------------------------------------------------------------ the players
local turnedAway = {}   -- pid -> true: a second player under a name already here, sent away at the door

function OnPlayerConnect(pid)
  local name = GetPlayerName(pid) or ""
  -- the server lets two players share a name; here a name is an account (and an admin), so the second one is turned away
  for _, other in ipairs(GetPlayers()) do
    if other ~= pid and (GetPlayerName(other) or ""):lower() == name:lower() then
      Log(fmt("BasicRP: a second %s turned away (player %d has the name)", name, other))
      turnedAway[pid] = true
      Kick(pid, fmt("the name %s is taken here - pick another name in the launcher", name))
      return
    end
  end
  SetPlayerThirdPerson(pid, CAMERA.third_person, CAMERA.in_fights, CAMERA.when_aiming, CAMERA.crosshair)
  say(pid, fmt("Welcome to BasicRP on %s, %s. %d player(s) online.", GetLevelName(), name, GetPlayerCount()))
  SendClientMessageToAll(COLOR_SERVER, name .. " joined")
  if not db then
    say(pid, "This server has no database: accounts are off.")
    players[pid] = { name = name:lower(), registered = false, logged = false }
    promote(pid)   -- without accounts the name is all there is
    return
  end
  players[pid] = { name = name:lower(), registered = false, logged = false, tries = 0 }
  if EVERYONE_ADMIN then promote(pid) end   -- from the door, logged in or not
  db:Query("SELECT visits FROM players WHERE name = @n", { n = name:lower() }, function(rows, err)
    if err then Log("BasicRP: " .. err) return end
    local p = players[pid]
    if not p or not IsPlayerConnected(pid) then return end
    p.registered = #rows > 0
    p.known = true   -- the box opens once the client half says it is up too (OnClientEvent "auth_ready")
    say(pid, p.registered and "This name has an account: log in with its password."
      or "This name has no account yet: choose a password to make it yours.")
    askPassword(pid)
  end)
end

function OnPlayerRequestSpawn(pid)
  SetSpawnInfo(pid, spawnSpot(pid))
  return true
end

-- the starting kit, once a session: the purse and a torch (a logged-in player's saved purse replaces the money)
function OnPlayerSpawn(pid)
  local p = players[pid]
  if not p then players[pid] = { name = (GetPlayerName(pid) or ""):lower(), registered = false, logged = false } p = players[pid] end
  greet(pid, p)   -- the session's first spawn before the login: held still, the welcome page with the keys (WELCOME)
  SetPlayerPullDown(pid, PULLDOWN.enabled)   -- the right to pull riders off their horses: the PULLDOWN table's switch (off by default)
  pocketRights(pid)   -- whose pockets may be picked: everybody's, but an admin's unless the PICKPOCKET table says so
  if p.outfitted then return end
  p.outfitted = true
  for _, item in ipairs(START_ITEMS) do GivePlayerItem(pid, item) end
  if p.savedMoney then
    GivePlayerMoney(pid, p.savedMoney - GetPlayerMoney(pid))   -- logged in before the spawn: the saved purse
  else
    GivePlayerMoney(pid, START_MONEY)
  end
  if p.savedItems then
    -- logged in before the spawn: the bags once the client has reported what the outfit and the kit gave
    local items = p.savedItems
    SetTimer(function() if IsPlayerInWorld(pid) and players[pid] == p then restoreInventory(pid, items) end end, 4000)
  end
end

function OnPlayerDisconnect(pid, reason)
  if turnedAway[pid] then turnedAway[pid] = nil return end   -- never joined here: nothing to say or save
  SendClientMessageToAll(COLOR_SERVER, fmt("%s left (%s)", GetPlayerName(pid), reason))
  markDiscovery(pid)   -- what they found in their last moments is saved with the rest, whether a change call announced it or not
  savePlace(pid)
  dropCarts(pid)   -- their cart (and one half made) leaves with them
  -- their horse leaves with them (saved above for an account; /horse brings it back): left behind it would be nobody's,
  -- its bags anyone's
  for _, horse in ipairs(GetPlayerHorses(pid)) do DestroyEntity(horse) end
  TOWN.forget(pid)
  players[pid] = nil
  pullReady[pid], pullSafe[pid] = nil, nil   -- the pull-down timers of the id (it is reused)
end

-- ------------------------------------------------------------------ the role-play chat
-- A plain line is spoken: those within 20 m hear "Name says: ..."; the line rides over the head as the chat bubble does.
function OnPlayerText(pid, text)
  sayNearby(pid, CHAT_RANGE, COLOR_WHITE, fmt("%s says: %s", GetPlayerName(pid), text))
  SetPlayerChatBubble(pid, text, COLOR_WHITE, CHAT_RANGE)
  return false   -- the server's own broadcast stays out: the line went where it belongs
end

local function usage(pid, line) SendClientMessage(pid, COLOR_RED, "Usage: " .. line) return true end

-- A player who lies knocked out, or is carried, only talks: no command that would free him (/putdown, /unstuck), move him (/horse,
-- /look, /createcart) or put something under him. DOWN_OK are the words that stay for a player; an admin keeps his tools (the server's
-- own and this mode's) but not these - DOWN_BLOCKED are the mode's own commands that free or move a player, for everyone.
local DOWN_OK = { register = true, login = true, me = true, ["do"] = true, ame = true, s = true, shout = true, b = true, ooc = true, p = true,
  help = true, skills = true }
local DOWN_BLOCKED = { horse = true, unstuck = true, seat = true, createcart = true, despawncart = true, look = true, dice = true, carry = true,
  putdown = true }

-- ------------------------------------------------------------------ the commands
function OnPlayerCommandText(pid, cmd, args)
  cmd = cmd:lower()
  if (IsPlayerKnockedOut(pid) or IsPlayerCarried(pid)) and (DOWN_BLOCKED[cmd] or (not DOWN_OK[cmd] and not IsPlayerAdmin(pid))) then
    say(pid, "Not while you are knocked out or carried.")
    return true
  end
  if cmd == "register" then return register(pid, args) end
  if cmd == "login" then return login(pid, args) end
  if cmd == "me" then                                    -- /me draws his sword: "* Name draws his sword" in lavender, nearby
    if #args == 0 then return usage(pid, "/me <action>") end
    sayNearby(pid, CHAT_RANGE, COLOR_PURPLE, fmt("* %s %s", GetPlayerName(pid), args))
    return true
  end
  if cmd == "do" then                                    -- /do The door is barred.: "The door is barred. ((Name))"
    if #args == 0 then return usage(pid, "/do <description>") end
    sayNearby(pid, CHAT_RANGE, COLOR_PURPLE, fmt("%s ((%s))", args, GetPlayerName(pid)))
    return true
  end
  if cmd == "ame" then                                   -- /ame nods: "* Name nods" over the head alone, in the same lavender
    if #args == 0 then return usage(pid, "/ame <action>") end
    local line = fmt("* %s %s", GetPlayerName(pid), args)
    SetPlayerChatBubble(pid, line, COLOR_PURPLE, CHAT_RANGE)
    SendClientMessage(pid, COLOR_PURPLE, line)         -- the speaker cannot see their own head: the line in their chat
    return true
  end
  if cmd == "s" or cmd == "shout" then                   -- /s Guards!: heard across 40 m
    if #args == 0 then return usage(pid, "/s <text>") end
    sayNearby(pid, SHOUT_RANGE, COLOR_WHITE, fmt("%s shouts: %s!", GetPlayerName(pid), args))
    SetPlayerChatBubble(pid, args .. "!", COLOR_WHITE, SHOUT_RANGE)
    return true
  end
  if cmd == "b" or cmd == "ooc" then                     -- /b brb: the out-of-character line, nearby, in grey
    if #args == 0 then return usage(pid, "/b <text>") end
    sayNearby(pid, CHAT_RANGE, COLOR_OOC, fmt("(( %s: %s ))", GetPlayerName(pid), args))
    return true
  end
  if cmd == "horse" then                                 -- everyone's, not the server's admin-only built-in
    return horse(pid)
  end
  if cmd == "unstuck" then                               -- /unstuck: wedged somewhere, back to the spawn
    return unstuck(pid)
  end
  if cmd == "seat" then                                  -- /seat 4: another seat in your cart (/seat alone: who sits where)
    return seat(pid, args)
  end
  if cmd == "createcart" then                            -- /createcart: a window to build your own cart, then it stands in front of you
    return cartMaker(pid)
  end
  if cmd == "despawncart" then                           -- /despawncart: your cart taken away, wherever it is
    return despawnCart(pid)
  end
  if cmd == "anim" then                                  -- /anim wave: the gesture for everyone around, as the wheel on G plays it
    return anim(pid, args)
  end
  if cmd == "board" or cmd == "sign" or cmd == "paint" or cmd == "post" or cmd == "unpin" or cmd == "clearboards" then
    return boardCommand(pid, cmd, args)                  -- the admin's boards: web pages hung on the wall they look at
  end
  if cmd == "look" then                                  -- /look: the creator again - the face, the hair, the beard, the skin
    openCreator(pid, false)
    return true
  end
  if cmd == "dice" then                                  -- /dice Hans 20: a game of dice at a dice table, the stakes on the server
    return dice(pid, args)
  end
  if cmd == "carry" or cmd == "putdown" or cmd == "carrying" or cmd == "ko" or cmd == "wake" then
    return carryCommand(pid, cmd, args)                  -- /carry Hans: a knocked-out player over your shoulder; /putdown; the admin's /carrying /ko /wake
  end
  if cmd == "pickpocket" then                            -- the admin's /pickpocket on|off|status, /pickpocket admins on|off (the way to rob is the game's prompt)
    return pocketCommand(pid, args)
  end
  if cmd == "carryitem" or cmd == "carryitems" or cmd == "clearitems" then
    return itemsCommand(pid, cmd, args)                  -- the admin's /carryitem sack (a sack to carry, laid in front of him), /carryitems, /clearitems
  end
  if progressCommand(pid, cmd, args) then return true end   -- /skills, and the admin's /setlevel /givexp /perk /perkpoints /xprate
  if cmd == "horsestat" then                             -- /horsestat courage 12: a stat of the horse the admin rides
    return horseStat(pid, args)
  end
  if cmd == "setenergy" or cmd == "setsleep" or cmd == "sethunger" then   -- /setenergy 40, /setsleep 10 Hans, /sethunger 80: the admin's levers
    return vitalCommand(pid, cmd, args)
  end
  if cmd == "horsecoat" then                             -- /horsecoat chestnut: the coat of the horse the admin rides
    return horseCoat(pid, args)
  end
  if cmd == "help" then
    help(pid)
    return true    -- this mode's list alone: the server's built-ins are admin tools, not a player's
  end
  if cmd == "menu" and TOWN.enabled then                 -- /menu: the server's menu page (the help, the town, your purse and horse)
    TOWN.toggleMenu(pid)
    return true
  end
  return party(pid, cmd, args)
end

-- Pulling a rider off a horse: the game's own take-down move - a player on foot, weapon drawn (or bare hands), beside a rider's
-- horse gets the game's "Pull down" prompt on the rider; the two games play the pair and everyone around sees the rider thrown
-- off (or the pull fail). There is no command: the prompt is the way. OFF until enabled here. The server checks the weapon's
-- reach and the horse's pace, pvp, teams and parties; the rules below are this mode's - change them here:
PULLDOWN = {
  enabled = false,        -- true: players may pull riders down (the prompt shows); false: nobody may
  chance = 0.7,           -- 0..1: the chance a pull throws the rider off (the failed pair plays otherwise and the rider stays up)
  cooldown = 20,          -- seconds a player must wait between two of their pulls
  protect_seconds = 30,   -- seconds a rider who was pulled off cannot be pulled down again
  damage = 0,             -- health the fall takes off the rider (0 = none; never below 1)
}

-- the ask of a player on foot (the server has checked the reach, the pace and pvp): the cooldown, the protection and the chance
function OnPlayerPullDown(pid, victim, id)
  if not PULLDOWN.enabled then return false end
  local now = GetServerTime()
  if (pullReady[pid] or 0) > now then
    say(pid, fmt("You cannot pull anyone down for another %d seconds.", math.ceil((pullReady[pid] - now) / 1000)))
    return false
  end
  if (pullSafe[victim] or 0) > now then
    say(pid, fmt("%s was pulled off a horse a moment ago and cannot be again yet.", GetPlayerName(victim)))
    return false
  end
  pullReady[pid] = now + PULLDOWN.cooldown * 1000
  return PULLDOWN.chance
end

-- how it ended: the rider thrown off (protected for a while, hurt if the rules say so) or the pull failed
function OnPlayerPulledDown(pid, victim, id, success)
  if not success then
    say(pid, fmt("%s stayed in the saddle.", GetPlayerName(victim)))
    return
  end
  pullSafe[victim] = GetServerTime() + PULLDOWN.protect_seconds * 1000
  if PULLDOWN.damage > 0 then
    local health = GetPlayerHealth(victim)
    if health then SetPlayerHealth(victim, math.max(1, health - PULLDOWN.damage)) end
  end
  say(victim, fmt("%s pulled you off your horse!", GetPlayerName(pid)))
end

-- Carrying: the game's own grab, carry over the shoulder and put-down, seen by everyone - the game's "grab" prompt on a body that lies
-- down (a dead character's, a knocked-out player's or NPC's), or /carry <name> on a knocked-out player; /putdown puts what you carry
-- down. OFF until enabled here. The server checks the reach and that nobody else has the body; the rules below are this mode's - change
-- them here. An admin's /ko knocks a player out (they drop, their screen goes dark, their health stays), /wake wakes them, /carrying
-- on|off switches the grab, and an admin's /carry takes any player, knocked out or not (they show knocked out for the carry).
CARRY = {
  enabled = false,     -- true: the grab prompt shows on bodies that lie down and /carry works for everyone; false: only an admin carries
  range = 3,           -- metres a player may stand from the body when they reach for it
  speed = 2.4,         -- metres per second a carrier walks (at most 4)
  corpses = true,      -- the bodies of the dead - an NPC's, or a dead player's (the server's [combat] corpse_seconds keeps it) - can be carried
  players = true,      -- ... a knocked-out player
  actors = true,       -- ... a knocked-out NPC
  ko_seconds = 120,    -- how long an admin's /ko keeps a player down when it names no time (0 = until /wake)
}

-- /carry <name> (a knocked-out player in reach, or any for an admin), /putdown, and the admin's /carrying on|off|status, /ko [name] [seconds], /wake [name]
function carryCommand(pid, cmd, args)
  local admin = IsPlayerAdmin(pid)
  if cmd == "carry" then
    if not CARRY.enabled and not admin then say(pid, "Carrying is not allowed here.") return true end
    local target = sscanf(args, "u")
    if target == false then return usage(pid, "/carry <name>") end
    if not admin then
      -- the rules' reach and kinds apply to the command as they do to the prompt; one answer for "not down" and "not near", so the command
      -- never tells where a player is or whether he lies knocked out out of sight
      local x, y, z = GetPlayerPos(pid)
      local tx, ty, tz = GetPlayerPos(target)
      local near = x and tx and (x - tx) ^ 2 + (y - ty) ^ 2 + (z - tz) ^ 2 <= (CARRY.range + 1) ^ 2
      if not (CARRY.players and near and IsPlayerKnockedOut(target)) then
        say(pid, fmt("%s cannot be carried.", GetPlayerName(target)))
        return true
      end
    end
    local ok, why = CarryPlayer(pid, target, CARRY.speed)
    if not ok then say(pid, admin and why or fmt("You cannot carry %s now.", GetPlayerName(target))) end
    return true
  elseif cmd == "putdown" then
    if not CARRY.enabled and not admin then say(pid, "Carrying is not allowed here.") return true end
    -- StopCarry takes either party of a carry: only the one who carries puts down - the carried player does not end his own carry
    if not IsPlayerCarrying(pid) or not StopCarry(pid) then say(pid, "You carry nobody.") end
    return true
  end
  if not admin then say(pid, "/" .. cmd .. " is for admins") return true end
  if cmd == "carrying" then
    local word = args:match("^%s*(%a+)%s*$")
    if word == "on" or word == "off" then
      CARRY.enabled = word == "on"
      SetCarrying(CARRY.enabled, CARRY)
    end
    say(pid, fmt("carrying is %s - /carrying on|off", CARRY.enabled and "on" or "off"))
    return true
  elseif cmd == "ko" then
    local first, second = args:match("^%s*(%S*)%s*(%S*)")
    local target, seconds = pid, tonumber(second) or CARRY.ko_seconds
    if first ~= "" then
      local who = GetPlayerId(first)
      if who then target = who
      elseif tonumber(first) and second == "" then seconds = tonumber(first)
      else return usage(pid, "/ko [name] [seconds]") end
    end
    local ok, why = SetPlayerKnockedOut(target, true, seconds)
    say(pid, ok and fmt("%s is knocked out%s.", GetPlayerName(target), seconds > 0 and fmt(" for %g seconds", seconds) or "") or fmt("%s: %s", GetPlayerName(target), why))
    return true
  end
  local target = sscanf(args, "u?")   -- /wake [name]
  if target == false then return usage(pid, "/wake [name]") end
  target = target or pid
  SetPlayerKnockedOut(target, false)
  say(pid, fmt("%s is awake.", GetPlayerName(target)))
  return true
end

-- Carry items: sacks, baskets, buckets and the like carried in the hands the way the game's own people carry them - the game's pickup, its
-- carry walk (no running) and its put-down (E), seen by everyone. Nothing lies around until an admin lays something: /carryitem <kind> lays
-- one in front of him, /carryitem <kind> <name> puts one in that player's hands, /clearitems takes them all away, /carryitems on|off switches
-- the players' own "Pick up" prompt. They are not kept: a restart clears them. The kinds are the names below or any item name of the game's.
ITEMS = {
  enabled = true,   -- true: the "Pick up" prompt shows on carry items; false: only an admin's /carryitem ... <name> hands them out
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

-- the admin's /carryitem <kind> [name], /carryitems on|off|status, /clearitems
function itemsCommand(pid, cmd, args)
  if not IsPlayerAdmin(pid) then say(pid, "/" .. cmd .. " is for admins") return true end
  if cmd == "carryitems" then
    local word = args:match("^%s*(%a+)%s*$")
    if word == "on" or word == "off" then
      ITEMS.enabled = word == "on"
      SetItemCarrying(ITEMS.enabled, ITEMS)
    end
    say(pid, fmt("carry items are %s, %d in the world - /carryitems on|off", ITEMS.enabled and "on" or "off", #GetEntities(ENTITY_CARRY)))
    return true
  elseif cmd == "clearitems" then
    local list = GetEntities(ENTITY_CARRY)
    for _, id in ipairs(list) do DestroyEntity(id) end
    say(pid, fmt("%d carry item(s) taken away", #list))
    return true
  end
  local kind, who = args:match("^%s*(%S+)%s*(%S*)%s*$")
  if not kind then
    local names = {}
    for name in pairs(ITEMS.kinds) do names[#names + 1] = name end
    table.sort(names)
    return usage(pid, "/carryitem <kind> [name] - kinds: " .. table.concat(names, ", ") .. " (or an item name)")
  end
  local item = ITEMS.kinds[kind:lower()] or kind
  if who ~= "" then
    local target = GetPlayerId(who)
    if not target then say(pid, fmt("Nobody called %s is here.", who)) return true end
    local id, why = GivePlayerCarryItem(target, item)
    say(pid, id and fmt("%s picks up %s.", GetPlayerName(target), item) or fmt("%s: %s", GetPlayerName(target), why))
    return true
  end
  local x, y, z = GetPlayerPos(pid)
  local yaw = GetPlayerYaw(pid)
  local rad = math.rad(yaw)
  local id = x and CreateCarryItem(item, x - math.sin(rad) * 1.2, y + math.cos(rad) * 1.2, z, yaw, GetPlayerVirtualWorld(pid))
  say(pid, id and fmt("%s laid in front of you.", item) or fmt("There is no item called '%s'.", item))
  return true
end

-- knocked out and up again: the player is told
function OnPlayerKnockedOut(pid) say(pid, "You were knocked out.") end

function OnPlayerWake(pid, reason)
  if reason == "woke" or reason == "mode" then say(pid, "You come to.") end
end

-- Pickpocketing: the game's own "Rob" on another player's body - hold E at the prompt, then the charge and the tile game - played on the
-- thief's screen over a few things the victim carries and does not wear; the server moves what the minigame takes. There is no command to rob:
-- the prompt is the way. OFF until enabled here (or by an admin's /pickpocket on). The server checks the reach, who is busy, the cooldown and
-- that nobody is fighting; the rules below are this mode's - change them here. An admin cannot be robbed unless admins_robbable says so - and
-- EVERYONE_ADMIN above makes everybody one, so a server that means to use pickpocketing turns that off (or sets admins_robbable, or uses
-- /pickpocket admins on to try it alone).
PICKPOCKET = {
  enabled = false,          -- true: the Rob prompt shows on other players' bodies; false: nobody robs
  range = 3,                -- metres the thief may stand from the body
  cooldown = 30,            -- seconds before the same thief may rob the same player again
  max_items = 8,            -- stacks the pockets offer at most (the game's wheel shows 11 at most)
  max_stack = 5,            -- the most of one thing the pockets offer
  behind_only = true,       -- true: only from behind
  money = false,            -- true: a tenth of the victim's purse (up to 100 Groschen) is in the pockets too
  admins_robbable = false,  -- true: an admin's pockets can be picked too
  on_robbed = "none",       -- a player who was robbed: "notify" tells them, "none" leaves them to find out
  on_caught = "notify",     -- a thief the victim noticed: "notify" tells both, "fight" starts a fight between them as well (needs [combat] pvp), "none" says nothing
}

-- whose pockets may be picked: everybody's, but an admin's unless the table says so (told to the clients as a state, so the prompt only shows on a body that may be robbed)
function pocketRights(pid)
  SetPlayerPickpocketable(pid, PICKPOCKET.admins_robbable or not IsPlayerAdmin(pid))
end

-- /pickpocket on|off|status and /pickpocket admins on|off: the switch, and whether an admin can be robbed; admins only
function pocketCommand(pid, args)
  if not IsPlayerAdmin(pid) then say(pid, "/pickpocket is for admins") return true end
  local first, second = args:match("^%s*(%a*)%s*(%a*)")
  if first == "on" or first == "off" then
    PICKPOCKET.enabled = first == "on"
    SetPickpocketing(PICKPOCKET.enabled, PICKPOCKET)
  elseif first == "admins" and (second == "on" or second == "off") then
    PICKPOCKET.admins_robbable = second == "on"
    for _, id in ipairs(GetPlayers()) do pocketRights(id) end
  end
  say(pid, fmt("pickpocketing is %s%s - /pickpocket on|off, /pickpocket admins on|off", PICKPOCKET.enabled and "on" or "off",
    PICKPOCKET.admins_robbable and ", admins can be robbed too" or ""))
  return true
end

-- how a robbery ended: the victim told when they were robbed or the thief was caught, a fight if the table says so (an NPC's pockets: nobody to tell)
function OnPlayerPickpocketEnd(pid, victim, actor, outcome, reason, taken)
  if victim < 0 then return end
  if outcome == "took" then
    if PICKPOCKET.on_robbed == "notify" then say(victim, "Your pockets feel lighter - someone has been at them.") end
  elseif outcome == "caught" and (reason == "detected" or reason == "seen") and PICKPOCKET.on_caught ~= "none" then
    say(victim, fmt("You catch %s with a hand in your pocket!", GetPlayerName(pid)))
    say(pid, fmt("%s caught you!", GetPlayerName(victim)))
    if PICKPOCKET.on_caught == "fight" then StartFight(pid, victim) end
  end
end

-- Dice: the game's own dice game between two players standing together at a dice table (the taverns have them) - each
-- plays on their own screen against a stand-in with the other's face, the server deals every throw and holds the stakes;
-- what a player wins or loses is in their purse at once (saved as any change of what they carry). /dice <name> [bet]
-- challenges, /dice accept or /dice decline answers within a minute, /dice quit gives a running game up (Esc does too).
-- The rules are this mode's - change them here:
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
  ["the mode"] = "the game was ended", ["a fight"] = "a fight broke out", ["walked away"] = "a player walked away"}
function dice(pid, args)
  local word, rest = args:match("^(%S*)%s*(.-)$")
  word = (word or ""):lower()
  if word == "" then return usage(pid, "/dice <name> [bet], /dice accept, /dice decline, /dice quit") end
  if not DICE.enabled and word ~= "quit" then
    SendClientMessage(pid, COLOR_RED, "Dice are off on this server.")
  elseif word == "accept" then
    local invite = dice_invites[pid]
    dice_invites[pid] = nil
    if not invite or GetServerTime() - invite.at > DICE_INVITE_MS or not GetPlayerName(invite.from) then
      say(pid, "Nobody challenged you to dice.")
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
    if not invite then say(pid, "Nobody challenged you to dice.") return true end
    if GetPlayerName(invite.from) then say(invite.from, GetPlayerName(pid) .. " declined your game of dice.") end
  elseif word == "quit" then
    local info = GetDiceMatchInfo(GetPlayerDiceMatch(pid) or 0)
    if not info then say(pid, "You are not playing dice.") return true end
    EndDiceMatch(info.id, info.challenger == pid and info.opponent or info.challenger)
  else
    local target = GetPlayerId(word)
    local bet = math.floor(tonumber(rest) or 0)
    if not target then SendClientMessage(pid, COLOR_RED, "No such player.") return true end
    if target == pid then SendClientMessage(pid, COLOR_RED, "Not against yourself.") return true end
    if bet < 0 then SendClientMessage(pid, COLOR_RED, "The bet must be 0 or more Groschen.") return true end
    if GetPlayerDiceMatch(target) then say(pid, GetPlayerName(target) .. " is playing dice already.") return true end
    dice_invites[target] = {from = pid, bet = bet, at = GetServerTime()}
    local stake = bet > 0 and fmt(" for %d Groschen", bet) or ""
    say(target, fmt("%s challenges you to dice%s - /dice accept or /dice decline.", GetPlayerName(pid), stake))
    say(pid, fmt("You challenged %s to dice%s.", GetPlayerName(target), stake))
  end
  return true
end

function OnDiceMatchStart(id, challenger, opponent, bet, goal)
  local text = fmt("Dice: %s against %s, to %d points%s. %s throws first.", GetPlayerName(challenger), GetPlayerName(opponent), goal,
    bet > 0 and fmt(", %d Groschen each", bet) or "", GetPlayerName(challenger))
  say(challenger, text)
  say(opponent, text)
end

function OnDiceMatchEnd(id, challenger, opponent, winner, reason, bet)
  local why = DICE_REASONS[reason] or reason
  local text = winner >= 0 and fmt("%s won the game of dice%s (%s).", GetPlayerName(winner), bet > 0 and fmt(" and %d Groschen", 2 * bet) or "", why)
    or fmt("The game of dice is off: %s%s.", why, bet > 0 and " - the stakes went back" or "")
  for _, p in ipairs({challenger, opponent}) do
    if GetPlayerName(p) then say(p, text) end
  end
end

-- /anim <name>: an emote for everyone around - the wheel on G (and T, the point) plays them without a command; /anim alone
-- lists them, /anim stop ends a dance. The server's rules answer through PlayPlayerEmote's reason ("Stand still first." ...).
function anim(pid, args)
  local name = args:match("^(%S+)")
  if not name then
    say(pid, "Animations: " .. table.concat(GetEmotes(), ", ") .. " - /anim <name>, /anim stop")
  elseif name:lower() == "stop" then
    if not StopPlayerEmote(pid) then say(pid, "No animation is playing.") end
  else
    local ok, why = PlayPlayerEmote(pid, name)
    if not ok then SendClientMessage(pid, COLOR_RED, why) end
  end
  return true
end

-- /seat: who sits where in the player's cart; /seat <n> moves them there - 0 the reins (a free cart's), then a wagon's 1
-- beside them and 2-5 the back, a two-wheeler's 1-2 its side rails. Between the bench and the back they climb down and up
-- again, so the cart must stand; a seat the mode locked is not a player's to take.
local SEAT_NAMES = {
  wagon = { [0] = "the reins", "the bench", "back right", "back left", "middle right", "middle left" },
  cart = { [0] = "the reins", "right side", "left side" },
}
function seat(pid, args)
  local cart, mine = GetPlayerCart(pid)
  if not cart then say(pid, "You sit in no cart.") return true end
  local want = tonumber(args:match("^(%d+)"))
  if not want then
    local seats, names = {}, SEAT_NAMES[GetEntityTemplate(cart)] or {}
    for s = 0, GetCartSeatCount(cart) - 1 do
      local who = GetCartSeatPlayer(cart, s)
      seats[#seats + 1] = fmt("%d %s: %s", s, names[s] or "", who and GetPlayerName(who) or IsCartSeatLocked(cart, s) and "kept" or "free")
    end
    say(pid, table.concat(seats, ", ") .. " - /seat <n> moves you")
  elseif want ~= mine then
    if GetCartSeatPlayer(cart, want) then
      say(pid, "Someone sits there.")
    elseif IsCartSeatLocked(cart, want) or not SetPlayerCartSeat(pid, want) then
      say(pid, "Not that seat now - the reins of a wagoner's cart are his, and nobody climbs about a moving cart.")
    end
  end
  return true
end

-- The game's own whistle (WHISTLE above): the player's horse comes to their side. It walks the way the server's people do (around
-- the walls); mounting it on the way or a second whistle sends it on again.
function OnPlayerWhistle(pid)
  if not WHISTLE.enabled then return end
  local x, y, z = GetPlayerPos(pid)
  if not x then return end
  if WHISTLE.sound then PlaySound("v_horse_whistle", x, y, z + 1.6) end
  local mount = ownHorse(pid)
  if not mount or GetPlayerMount(pid) == mount then return end
  local hx, hy = GetEntityPos(mount)
  local dx, dy = hx - x, hy - y
  local far = math.sqrt(dx * dx + dy * dy)
  if far > WHISTLE.range then return end
  if far < 3 then return end
  -- to the player's side, a metre and a half short of them along the way it comes
  MoveActor(mount, x + dx / far * 1.5, y + dy / far * 1.5, -1, WHISTLE.speed)
end

-- /horse: the player's own horse in front of them, and up into the saddle. The server's built-in of
-- the same name is an admin tool; handling the name here answers it for everyone before the built-in
-- is reached. A horse the player already has is brought over instead of a second one being made.
function horse(pid)
  if GetPlayerMount(pid) then say(pid, "You are in the saddle already - X gets you off.") return true end
  local x, y, z = GetPlayerPos(pid)
  if not x then return true end
  local yaw = GetPlayerYaw(pid) or 0
  local rad = math.rad(yaw)
  local hx, hy = x - math.sin(rad) * 2.5, y + math.cos(rad) * 2.5   -- 2.5 m in front, as the built-in places one
  local mount = ownHorse(pid)   -- their own only: a loose horse they happen to simulate is somebody else's
  if mount then
    SetEntityPos(mount, hx, hy, z, yaw)
  else
    local p = players[pid]
    local saved = p and p.savedHorse
    mount = CreateHorse(hx, hy, z, yaw, pid, nil, saved and saved.breed, saved and saved.coat)
    if not mount and saved and saved.coat then
      mount = CreateHorse(hx, hy, z, yaw, pid, nil, saved.breed)   -- a coat this server does not know (an edited row): a pick
      saved.coat = nil
    end
    if mount and saved then
      if not saved.coat and db then
        -- a horse saved before the coat was: the one it shows now is kept, so it never changes again
        saved.coat = GetHorseCoat(mount)
        db:Execute("UPDATE player_horses SET coat = @c WHERE id = @h", { c = saved.coat, h = saved.dbId }, function(_, _, err)
          if err then Log("BasicRP: the horse's coat was not saved: " .. tostring(err)) end
        end)
      end
      -- the horse they left with: its row's id kept on it, dressed first, then its bags (they go with its Spawn to the
      -- owner's game)
      local gear, items = {}, {}
      for _, it in ipairs(saved.stacks) do
        if it.worn then gear[#gear + 1] = it.class else items[#items + 1] = it end
      end
      SetEntityData(mount, "db_id", saved.dbId)
      if #gear > 0 then SetHorseGear(mount, gear) end
      SetHorseItems(mount, items)
      for stat, level in pairs(p.horseStats and p.horseStats[saved.dbId] or {}) do SetHorseStat(mount, stat, level) end   -- what an admin gave it
      p.horseKeys = p.horseKeys or {}
      p.horseKeys[saved.dbId] = stacksKey(saved.stacks)
      Log(fmt("BasicRP: %s's horse back (%d pieces of gear, %d stacks in the saddlebags)", GetPlayerName(pid), #gear, #items))
    elseif mount and db and p and p.logged and p.id then
      -- a first horse: its row, then its gear and bags as the owner's game reports them (OnHorseItemsChange)
      local breed, coat = GetEntityTemplate(mount), GetHorseCoat(mount)   -- the coat it shows now is its coat for good
      insertId("INSERT INTO player_horses (player_id, soul, active, created_at, coat) VALUES (@p, @s, 1, @t, @c)",
        { p = p.id, s = breed or DB_NULL, t = os.date("!%Y-%m-%dT%H:%M:%SZ"), c = coat or DB_NULL }, function(id, err)
          if not id then Log("BasicRP: the horse of " .. p.name .. " was not saved: " .. tostring(err)) return end
          p.savedHorse = { dbId = tonumber(id), breed = breed, coat = coat, stacks = {} }
          if GetHorseOwner(mount) == pid then
            SetEntityData(mount, "db_id", tonumber(id))
            local batch = {}
            saveHorse(pid, mount, batch)
            flush(batch, "the horse of " .. p.name)
          end
        end)
    end
  end
  if not mount then say(pid, "There is no room for another horse here.") return true end
  if not MountPlayer(pid, mount) then say(pid, "That horse will not have you.") end
  return true
end

-- /unstuck: a player wedged somewhere they cannot walk out of (a stable, a rock) goes back to the spawn - on kutnohorsko
-- the Suchdol fortress's yard, the server's [spawn] of the level - a horse under them with them. Not in a fight (it is no
-- way out of one), not in a cart (the seat is no trap), not while dead or making a character; once every UNSTUCK_COOLDOWN
-- seconds. The place is saved as any other (the minute's round, the disconnect).
local UNSTUCK_COOLDOWN = 300
function unstuck(pid)
  local p = players[pid]
  if not p or p.staged or not IsPlayerInWorld(pid) then return true end
  if IsPlayerDead(pid) then say(pid, "Not while you are dead.") return true end
  if (p.fights or 0) > 0 then SendClientMessage(pid, COLOR_RED, "Not in a fight.") return true end
  if GetPlayerCart(pid) then say(pid, "Get off the cart first.") return true end
  local now = GetServerTime()
  if p.unstuckAt and now - p.unstuckAt < UNSTUCK_COOLDOWN * 1000 then
    say(pid, fmt("You can use /unstuck again in %d s.", math.ceil((UNSTUCK_COOLDOWN * 1000 - (now - p.unstuckAt)) / 1000)))
    return true
  end
  p.unstuckAt = now
  local x, y = GetPlayerPos(pid)
  SetPlayerPos(pid, spawnSpot(pid))
  say(pid, "Back at the spawn.")
  Log(fmt("BasicRP: %s unstuck from %.1f %.1f", GetPlayerName(pid), x or 0, y or 0))
  return true
end

-- The fights each player is in (for /unstuck): the server starts and ends them, the mode only counts.
function OnFightStart(a, b)
  for _, id in ipairs({ a, b }) do
    local p = players[id]
    if p then p.fights = (p.fights or 0) + 1 end
  end
end

function OnFightEnd(a, b)
  for _, id in ipairs({ a, b }) do
    local p = players[id]
    if p then p.fights = math.max(0, (p.fights or 0) - 1) end
  end
end

-- ------------------------------------------------------------------ the cart maker
-- /createcart: a cart of the player's own, made in a window of this mode's client half (gamemodes/basicrp/client/
-- cartmaker.lua). The player goes into a world of their own (CART_WORLD + the id: nobody watches a cart being made, and
-- it stands where they look) with a real cart ahead of them; every choice in the window - a wagon or a two-wheeler, the
-- body, the wheels, the load, the horses' coats, a turn - is made on that cart at once, so they see each change as they
-- pick it. Space brings the cart into the shared world where it stands, and the player with it; Esc takes it away. A
-- player has one cart: a new one takes the old one's place (the window starts from it), and it leaves the world with them
-- as their horse does. The client half says "cartmaker_shown" when the window is up, then "cartmaker_kind" "<kind>;<parts>",
-- "cartmaker_set" "<parts>", "cartmaker_turn" "<degrees>", "cartmaker_done" or "cartmaker_cancel"; the parts go as
-- "slot=part,slot=part".
local CART_WORLD = 2000                        -- + the player id: the world of one a cart is made in
local CART_KINDS = { "wagon", "cart" }         -- the window's order
local CART_AHEAD = { wagon = 9, cart = 6 }     -- metres from the player to the cart's middle: the whole cart in view
local CART_MIDDLE = { wagon = 0, cart = 1 }    -- metres from a cart's point (a wagon's front axle, a two-wheeler's horse) back to its middle
local CART_REACH = 4.6                         -- metres from a wagon's middle to its ends: the room it needs to turn
local CART_TURN = 65                           -- degrees off the player's heading: side-on, its tail turned a little towards them
local cartCatalogue                            -- the payload of "cartmaker_parts", built once

local function groundAt(x, y, z) return GetGroundZ(x, y, z + 3) or GetTerrainHeight(x, y) or z end

-- every kind's slots and parts: "wagon:body=a,b,...;axle=b,b_covered;...|cart:..." (each slot's default first)
local function buildCartCatalogue()
  local kinds = {}
  for _, kind in ipairs(CART_KINDS) do
    local slots = {}
    for _, slot in ipairs(GetCartPartSlots(kind)) do
      slots[#slots + 1] = slot .. "=" .. table.concat(GetCartPartNames(slot, kind), ",")
    end
    if #slots > 0 then kinds[#kinds + 1] = kind .. ":" .. table.concat(slots, ";") end
  end
  return table.concat(kinds, "|")
end

local function partsText(parts)
  local out = {}
  for slot, part in pairs(parts) do out[#out + 1] = slot .. "=" .. part end
  table.sort(out)
  return table.concat(out, ",")
end

local function partsFrom(text)
  local parts = {}
  for slot, part in (text or ""):gmatch("([%w_]+)=([%w_]+)") do parts[slot] = part end
  return parts
end

-- the player's cart, while it is still theirs (an admin's /cart remove takes it away, and the id may be another's since)
local function ownCart(p, pid)
  local id = p and p.cart
  if id and GetEntityKind(id) == ENTITY_CART and tonumber(GetEntityData(id, "cart_owner")) == pid then return id end
  return nil
end

-- the cart's middle, ahead of the player
local function cartMiddle(m)
  local r = math.rad(m.yaw)
  local d = CART_AHEAD[m.kind]
  local x, y = m.x - math.sin(r) * d, m.y + math.cos(r) * d
  return x, y, groundAt(x, y, m.z)
end

-- where the cart's point goes and the way it faces: turned about its middle by the window's turn
local function cartPoint(m)
  local mx, my = cartMiddle(m)
  local yaw = (m.yaw + CART_TURN + m.turn) % 360
  local r = math.rad(yaw)
  local x, y = mx - math.sin(r) * CART_MIDDLE[m.kind], my + math.cos(r) * CART_MIDDLE[m.kind]
  return x, y, groundAt(x, y, m.z), yaw
end

-- nothing of the level's in the way (a wall, a tree - with the collision export; without it always true): from the eyes to
-- a wagon's middle, its ends at either hand and beyond it, where any turn could take them
local function roomForCart(m)
  local r = math.rad(m.yaw)
  local fx, fy, rx, ry = -math.sin(r), math.cos(r), math.cos(r), math.sin(r)
  local mx, my = m.x + fx * CART_AHEAD.wagon, m.y + fy * CART_AHEAD.wagon
  for _, o in ipairs({ {0, 0}, {rx, ry}, {-rx, -ry}, {fx, fy} }) do
    local x, y = mx + o[1] * CART_REACH, my + o[2] * CART_REACH
    if not IsLineOfSight(m.x, m.y, m.z + 1.6, x, y, groundAt(x, y, m.z) + 1) then return false end
  end
  return true
end

-- the window's cart, made again (the first, another kind)
local function makePreview(pid, m)
  if m.cart then DestroyEntity(m.cart) m.cart = nil end
  local x, y, z, yaw = cartPoint(m)
  m.cart = CreateCart(m.kind, x, y, z, yaw, CART_WORLD + pid, m.parts[m.kind])
  return m.cart ~= nil
end

local function sendCartMaker(pid, m)
  local x, y, z = cartMiddle(m)
  SendClientEvent(pid, "cartmaker_parts", cartCatalogue)   -- every time: a /reload of the scripts forgets it
  SendClientEvent(pid, "cartmaker", fmt("open;%s;%s;%.2f;%.2f;%.2f", m.kind, partsText(GetCartParts(m.cart)), x, y, z))
end

function cartMaker(pid)
  local p = players[pid]
  if not p or not IsPlayerInWorld(pid) then return true end
  if db and not p.logged then say(pid, "Log in first.") return true end
  if p.staged or p.creating then say(pid, "Finish your character first.") return true end
  if p.maker then sendCartMaker(pid, p.maker) return true end   -- the window went (the scripts reloaded): up again on the same cart
  if GetPlayerMount(pid) then say(pid, "Get off your horse first - X.") return true end
  if GetPlayerCart(pid) then say(pid, "Get down from the cart first.") return true end
  if GetPlayerDiceMatch(pid) then say(pid, "Finish your game of dice first.") return true end
  local x, y, z = GetPlayerPos(pid)
  if not x then return true end
  local m = { x = x, y = y, z = z, yaw = GetPlayerYaw(pid) or 0, turn = 0, kind = CART_KINDS[1], parts = {} }
  local old = ownCart(p, pid)
  if old and CART_AHEAD[GetEntityTemplate(old)] then   -- the window starts from the cart they have
    m.kind = GetEntityTemplate(old)
    m.parts[m.kind] = GetCartParts(old)
  end
  if not roomForCart(m) then
    SendClientMessage(pid, COLOR_RED, "There is no room for a cart here - stand facing open ground.")
    return true
  end
  cartCatalogue = cartCatalogue or buildCartCatalogue()
  SetPlayerVirtualWorld(pid, CART_WORLD + pid)
  if cartCatalogue == "" or not makePreview(pid, m) then
    SetPlayerVirtualWorld(pid, 0)
    SendClientMessage(pid, COLOR_RED, "Carts are off on this server.")
    return true
  end
  p.maker = m
  sendCartMaker(pid, m)
  -- the window says it is up; a game without this mode's scripts never does, and the player is not left in a world of one
  SetTimer(function()
    if players[pid] == p and p.maker == m and not m.shown then
      closeCartMaker(pid)
      SendClientMessage(pid, COLOR_RED, "Your game did not open the cart window - join the server again to get its scripts.")
    end
  end, 6000)
  return true
end

-- out of the window, back in the shared world: the cart kept (there with them, theirs - their old one gone) or taken away;
-- true when a cart was kept
function closeCartMaker(pid, keep)
  local p = players[pid]
  local m = p and p.maker
  if not m then return false end
  p.maker = nil
  local kept = m.cart and keep
  if kept then
    local old = ownCart(p, pid)
    if old then DestroyEntity(old) end
    SetEntityData(m.cart, "cart_owner", pid)
    SetEntityVirtualWorld(m.cart, 0)
    p.cart = m.cart
    Log(fmt("BasicRP: %s made a %s (%s)", GetPlayerName(pid), m.kind, partsText(GetCartParts(m.cart))))
  elseif m.cart then
    DestroyEntity(m.cart)
  end
  SetPlayerVirtualWorld(pid, 0)
  SendClientEvent(pid, "cartmaker", "close")
  return kept == true
end

function cartMakerEvent(pid, p, name, payload)
  local m = p.maker
  if not m then return end
  if name == "cartmaker_shown" then
    m.shown = true
  elseif name == "cartmaker_kind" then
    local kind, parts = payload:match("^([%w_]+);?(.*)$")
    if kind and CART_AHEAD[kind] and kind ~= m.kind then
      m.kind = kind
      m.parts[kind] = partsFrom(parts)
      if makePreview(pid, m) then
        -- the new cart as it is, the slots the player never set too (a cart's own pair of horses): the window shows those
        SendClientEvent(pid, "cartmaker", "parts;" .. kind .. ";" .. partsText(GetCartParts(m.cart)))
      else
        closeCartMaker(pid)
        SendClientMessage(pid, COLOR_RED, "No cart could be made here.")
      end
    end
  elseif name == "cartmaker_set" and m.cart then
    local parts = m.parts[m.kind] or {}
    for slot, part in pairs(partsFrom(payload)) do
      if SetCartPart(m.cart, slot, part) then parts[slot] = part end
    end
    m.parts[m.kind] = parts
  elseif name == "cartmaker_turn" and m.cart then
    local by = tonumber(payload)
    if by then
      m.turn = (m.turn + math.max(-90, math.min(90, by))) % 360
      SetEntityPos(m.cart, cartPoint(m))
    end
  elseif name == "cartmaker_done" then
    if closeCartMaker(pid, true) then
      say(pid, "Your cart stands in front of you - take the reins at its bench with the use key. /createcart builds another in its place.")
    end
  elseif name == "cartmaker_cancel" then
    closeCartMaker(pid)
  end
end

-- the window goes with a death (the player is not left in a world of one)
function OnPlayerDeath(pid, killer)
  if players[pid] and players[pid].maker then closeCartMaker(pid) end
end

function dropCarts(pid)
  local p = players[pid]
  if not p then return end
  if p.maker and p.maker.cart then DestroyEntity(p.maker.cart) end
  p.maker = nil
  local cart = ownCart(p, pid)
  if cart then DestroyEntity(cart) end
end

-- /despawncart: the player's one cart taken away, wherever it stands (whoever sits in it gets off first)
function despawnCart(pid)
  local p = players[pid]
  local cart = ownCart(p, pid)
  if not cart then say(pid, "You have no cart - /createcart builds one.") return true end
  DestroyEntity(cart)
  p.cart = nil
  say(pid, "Your cart is gone. /createcart builds a new one.")
  return true
end

-- Parties: the server keeps the group, the invitation with its toast and the frames on screen; the commands and
-- the rules are the mode's, the same plain ones as freeroam's - any member invites, the leader removes a member,
-- hands the lead over or disbands. False when the name is none of them (the server's built-ins answer next).
function party(pid, cmd, args)
  if cmd == "invite" then
    if #args == 0 then return usage(pid, "/invite <name>") end
    local target = GetPlayerId(args)
    if not target then SendClientMessage(pid, COLOR_RED, "No such player.") return true end
    local ok, reason = InviteToParty(pid, target)
    if ok then say(pid, "Invited " .. GetPlayerName(target) .. ".")
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
    if #args == 0 then return usage(pid, "/" .. cmd .. " <name>") end
    local group, target = GetPlayerParty(pid), GetPlayerId(args)
    if not group or GetPartyLeader(group) ~= pid then SendClientMessage(pid, COLOR_RED, "You lead no party.") return true end
    if not target or GetPlayerParty(target) ~= group then SendClientMessage(pid, COLOR_RED, "Not in your party.") return true end
    if cmd == "pkick" then RemovePlayerFromParty(target, "kicked") else SetPartyLeader(group, target) end
    return true
  elseif cmd == "disband" then
    local group = GetPlayerParty(pid)
    if not group or GetPartyLeader(group) ~= pid then SendClientMessage(pid, COLOR_RED, "You lead no party.") return true end
    DisbandParty(group)
    return true
  elseif cmd == "p" then                                 -- /p Meet at the gate.: the line to the party alone, wherever they are
    local group = GetPlayerParty(pid)
    if not group then SendClientMessage(pid, COLOR_RED, "You are in no party.") return true end
    if #args == 0 then return usage(pid, "/p <text>") end
    SendPartyMessage(group, COLOR_PARTY, "[Party] " .. GetPlayerName(pid) .. ": " .. args)
    return true
  end
  return false
end

function OnPartyInvite(from, target)
  SendClientMessage(target, COLOR_SERVER, GetPlayerName(from) .. " invites you to a party - /accept or /decline.")
end

function OnPartyInviteResponse(from, target, answer)
  if answer ~= "accepted" then say(from, GetPlayerName(target) .. " " .. answer .. " the party invitation.") end
end

function OnPlayerJoinParty(group, pid, reason)
  SendPartyMessage(group, COLOR_SERVER, GetPlayerName(pid) .. " joined the party.")
end

function OnPlayerLeaveParty(group, pid, reason)
  if reason ~= "disband" then SendPartyMessage(group, COLOR_SERVER, GetPlayerName(pid) .. " left the party (" .. reason .. ").") end
end

function OnPartyLeaderChange(group, pid, previous)
  SendPartyMessage(group, COLOR_SERVER, GetPlayerName(pid) .. " leads the party now.")
end

-- /help: what this mode offers, and nothing else. One heading per subject, the commands under it, so a
-- new player can read it in the five lines the chat keeps on screen.
function help(pid, into)   -- into: a table that collects the lines ({color, text}) instead of the chat - the web menu's help
  local function line(color, text) if into then into[#into + 1] = { color = color, text = text } else SendClientMessage(pid, color, text) end end
  line(COLOR_GOLD, "---- BasicRP ----")
  if db then
    line(COLOR_SERVER, "Your name:")
    line(COLOR_WHITE, "  a box asks for its password when you join (Esc there leaves the game)")
    line(COLOR_WHITE, "  /register <password>   /login <password>   the same from the chat")
  end
  line(COLOR_WHITE, "  /look                  your character's face, hair, beard and skin")
  line(COLOR_SERVER, "Speaking (heard within " .. CHAT_RANGE .. " m):")
  line(COLOR_WHITE, "  /me <action>           * Henry draws his sword")
  line(COLOR_WHITE, "  /do <description>      The door is barred. ((Henry))")
  line(COLOR_WHITE, "  /ame <action>          the same, over your head alone")
  line(COLOR_WHITE, "  /s <text>              shout, heard across " .. SHOUT_RANGE .. " m")
  line(COLOR_WHITE, "  /b <text>              out of character, in grey")
  line(COLOR_SERVER, "Gestures:")
  line(COLOR_WHITE, "  hold G                 the wheel: wave, bow, dance ...; T points")
  line(COLOR_WHITE, "  /anim <name>           the same by name (/anim lists them, /anim stop)")
  line(COLOR_SERVER, "Getting about:")
  line(COLOR_WHITE, "  /horse                 a horse in front of you; X gets you off")
  line(COLOR_WHITE, "  /unstuck               stuck somewhere? back to the spawn (every " .. UNSTUCK_COOLDOWN // 60 .. " minutes)")
  line(COLOR_WHITE, "  /createcart            build a cart of your own - it stands in front of you")
  line(COLOR_WHITE, "  /despawncart           your cart taken away")
  line(COLOR_WHITE, "  /seat [n]              in a cart: who sits where, or another seat")
  if PULLDOWN.enabled then
    line(COLOR_WHITE, "  on foot beside a rider's horse, the game's Pull down prompt takes them off it (every " .. PULLDOWN.cooldown .. " seconds at most)")
  end
  if CARRY.enabled then
    line(COLOR_WHITE, "  at a body that lies down, the game's grab prompt carries it; /carry <name> a knocked-out player, /putdown puts it down")
  end
  if PICKPOCKET.enabled then
    line(COLOR_WHITE, "  at another player's back" .. (PICKPOCKET.behind_only and "" or " (or front, at a risk)") .. ", hold E at the game's Rob prompt to pick their pockets (once per " .. PICKPOCKET.cooldown .. " seconds per person)")
  end
  line(COLOR_WHITE, "  the merchant at the spawn trades - walk up and use him")
  if TOWN.enabled then
    line(COLOR_SERVER, "The town (around the spawn):")
    line(COLOR_WHITE, "  the smith, the tailor and the apothecary sell from their stalls - use them")
    line(COLOR_WHITE, "  the innkeeper talks, pours a beer (" .. TOWN.beer_price .. " gr) and knows the news")
    line(COLOR_WHITE, "  the stable master trades your horse for one of another coat (" .. TOWN.stable_price .. " gr; its gear and bags stay yours)")
    line(COLOR_WHITE, "  /menu or " .. TOWN.menu_key:upper() .. "           this server's menu: these lines, the town, your purse and horse")
  end
  line(COLOR_SERVER, "Skills:")
  line(COLOR_WHITE, "  /skills [name]         your stats and skills, or one of them with its XP")
  line(COLOR_SERVER, "Dice (at a dice table, together):")
  line(COLOR_WHITE, "  /dice <name> [bet]     challenge   /dice accept  /dice decline  /dice quit")
  line(COLOR_SERVER, "Party:")
  line(COLOR_WHITE, "  /invite <name>  /accept  /decline  /leave")
  line(COLOR_WHITE, "  /p <text>              to your party, wherever they are")
  line(COLOR_WHITE, "  the leader: /pkick <name>  /leader <name>  /disband")
  if IsPlayerAdmin(pid) then
    line(COLOR_OOC, "  (admin: the server's own tools answer too - /give, /tp, /time, /kick ...)")
    line(COLOR_OOC, "  (admin: /setlevel <name> <skill> <level> [xp]  /givexp <name> <skill> <xp>  /perk <name> add|remove <perk>)")
    line(COLOR_OOC, "  (admin: /perkpoints <name> <skill> <points>  /xprate <rate>  /horsestat <stat> <level>  /horsecoat <coat>)")
    line(COLOR_OOC, "  (admin: /setenergy <stamina> [name]  /setsleep <rest 0-100> [name]  /sethunger <0-100> [name])")
    line(COLOR_OOC, "  (admin: /carrying on|off  /ko [name] [seconds]  /wake [name]  /carry <name> carries anyone)")
    line(COLOR_OOC, "  (admin: /pickpocket on|off|status  /pickpocket admins on|off - whether an admin can be robbed too)")
    line(COLOR_OOC, "  (admin: /carryitem <kind> [name] a sack, basket or bucket to carry  /carryitems on|off  /clearitems)")
    line(COLOR_OOC, "  (admin, at a wall: /board  /sign [name]  /paint [words]  then /post <text>  /unpin  /clearboards)")
  end
end

-- ------------------------------------------------------------------ the boards
-- The admin's boards: web pages of this mode's interface (ui/board, ui/sign, ui/painted) drawn on boards in the world - every
-- player's game near one draws its own copy. /board hangs a notice board on the wall the admin looks at, /sign [name] a sign,
-- /paint [words] words painted on the wall (a see-through board: the page draws the letters alone, the wall shows between them).
-- The client half (client/boards.lua) answers where its player looks (GetLookTarget): the board's middle goes 3 cm out from that
-- point, facing the way the wall does (in front of the admin when they look at no wall), and the chat shows the CreateWebSurface
-- line that makes the same board. /post <text> pins a notice on every notice board, /unpin takes the oldest down, /clearboards
-- takes every board away. The boards and the notices last while the server runs.
local BOARD_SHAPES = {   -- each page's board: its size in metres (the page's shape), its options, where it goes without a wall
  board = { w = 1.5, h = 1.0, ahead = 2.5, up = 1.5, options = { prompt = "Read the notices" } },
  sign = { w = 1.2, h = 0.6, ahead = 3, up = 2.2, options = {}, pitch = -10 },
  painted = { w = 3.2, h = 0.8, ahead = 3, up = 2.4, options = { transparent = true } },
}
local BOARD_NOTICES_MAX = 6
local boards = {}         -- surface id -> {page, name, line}: what each board shows
local boardNotices = {}   -- {title, text}: the notice boards' notices, the oldest first
local boardAsked = {}     -- pid -> {name, line}: the words of the sign or paint the admin asked for, until their game answers

local function boardList() return { notices = boardNotices } end

local function boardOptionsText(options)
  local keys = {}
  for k in pairs(options) do keys[#keys + 1] = k end
  table.sort(keys)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = options[k]
    parts[#parts + 1] = k .. " = " .. (type(v) == "string" and fmt("%q", v) or type(v) == "number" and fmt("%g", v) or tostring(v))
  end
  if #parts == 0 then return "{}" end
  return "{ " .. table.concat(parts, ", ") .. " }"
end

-- the admin's game answered "board.look": "<page> x y z nx ny nz" (the point on the wall and the way it faces) or "<page> none"
function boardSpot(pid, payload)
  local asked = boardAsked[pid]
  boardAsked[pid] = nil
  if not IsPlayerAdmin(pid) or not asked then return end
  local page, spot = payload:match("^(%a+) (.*)$")
  local shape = page and BOARD_SHAPES[page]
  if not shape or page ~= asked.page then return end
  local x, y, z, nx, ny, nz = spot:match("^(%S+) (%S+) (%S+) (%S+) (%S+) (%S+)$")
  x, y, z, nx, ny, nz = tonumber(x), tonumber(y), tonumber(z), tonumber(nx), tonumber(ny), tonumber(nz)
  local px, py, pz = GetPlayerPos(pid)
  if not px then return end
  local yaw, pitch
  -- trust the answer no further than any input: a point near the admin, on a surface that stands up
  local onWall = x and nz and math.abs(nz) < 0.85 and (x - px) ^ 2 + (y - py) ^ 2 + (z - pz) ^ 2 < 12 ^ 2
  if onWall then
    yaw = math.deg(math.atan(-nx, ny))                 -- a board's yaw is the way its face looks
    pitch = math.deg(math.asin(math.max(-1, math.min(1, nz))))
    x, y, z = x + nx * 0.03, y + ny * 0.03, z + nz * 0.03
  else
    local a = math.rad(GetPlayerYaw(pid))
    x, y, z, yaw = px - math.sin(a) * shape.ahead, py + math.cos(a) * shape.ahead, pz + shape.up, GetPlayerYaw(pid) + 180
    pitch = shape.pitch or 0
  end
  local function round(v, step) return math.floor(v / step + 0.5) * step end
  x, y, z, yaw, pitch = round(x, 0.01), round(y, 0.01), round(z, 0.01), round(yaw % 360, 0.1), round(pitch, 0.1)
  local options = {}
  for k, v in pairs(shape.options) do options[k] = v end
  if pitch ~= 0 then options.pitch = pitch end
  local id = CreateWebSurface(page, x, y, z, yaw, shape.w, shape.h, options)
  if not id then say(pid, "That board could not be made - the server log says why.") return end
  boards[id] = { page = page, name = asked.name, line = asked.line }
  say(pid, (onWall and "On the wall. " or "In front of you (no wall in sight). ") .. "The same board from a script:")
  say(pid, fmt('CreateWebSurface("%s", %.2f, %.2f, %.2f, %.1f, %g, %g, %s)', page, x, y, z, yaw, shape.w, shape.h, boardOptionsText(options)))
end

function boardCommand(pid, cmd, args)
  if not IsPlayerAdmin(pid) then say(pid, "/" .. cmd .. " is for admins") return true end
  if cmd == "board" or cmd == "sign" or cmd == "paint" then
    local page = cmd == "paint" and "painted" or cmd
    local words = args ~= "" and args:sub(1, 60) or nil
    boardAsked[pid] = { page = page, name = words or "The Pike and Perch", line = (cmd == "sign" and not words) and "Ale - Mead - Roast pike" or
      (cmd == "paint" and not words) and "Rooms - Ale - Stabling" or "" }
    SendClientEvent(pid, "board.look", page)   -- the answer comes back as "board.spot" (OnClientEvent)
    return true
  elseif cmd == "post" then
    if args == "" then return usage(pid, "/post <text>") end
    table.insert(boardNotices, { title = GetPlayerName(pid), text = args:sub(1, 200) })
    if #boardNotices > BOARD_NOTICES_MAX then table.remove(boardNotices, 1) end
  elseif cmd == "unpin" then
    if #boardNotices == 0 then say(pid, "No notice is pinned.") return true end
    table.remove(boardNotices, 1)
  elseif cmd == "clearboards" then
    local n = 0
    for id in pairs(boards) do DestroyEntity(id) n = n + 1 end
    boards = {}
    say(pid, fmt("%d board(s) taken away.", n))
    return true
  end
  for id, b in pairs(boards) do
    if b.page == "board" then SendWebSurfaceMessage(id, boardList()) end
  end
  say(pid, fmt("%d notice(s) on the boards.", #boardNotices))
  return true
end

-- a player's copy of a board's page is ready (they came near it, or its page loaded again): what it shows
function OnPlayerWebSurfaceReady(pid, id)
  local b = boards[id]
  if not b then return end
  if b.page == "board" then
    SendPlayerWebSurfaceMessage(pid, id, boardList())
  else
    SendPlayerWebSurfaceMessage(pid, id, { name = b.name, line = b.line })
  end
end

-- the notice board's page says which notice its player read (checked like any input: a number of a pinned notice)
function OnPlayerWebSurfaceEvent(pid, id, name, payload)
  if name ~= "board.read" or not boards[id] then return end
  local notice = boardNotices[tonumber(payload) or 0]
  if notice then say(pid, "You read the notice: " .. notice.title) end
end

-- ------------------------------------------------------------------ the account box
-- The mode's client half (gamemodes/basicrp/client/account.lua) draws a password box and holds the keyboard while it is
-- up: "auth" "register;<line>" asks a name without an account for a password, "login;<line>" asks for it to log in,
-- "close" takes the box down; the line under it says what went wrong. The box sends "auth_register" / "auth_login" with
-- the password (it goes nowhere else: never into a log, never into the chat); Esc in it closes the player's game.
local function box(pid, kind, line)
  SendClientEvent(pid, "auth", kind .. ";" .. (line or ""))
end

-- the box opens once both are known: whether the name has an account (the database's answer) and that the client half
-- is up to draw it (its "auth_ready" - it comes again after a /reload of the scripts)
function askPassword(pid, line)
  local p = players[pid]
  if not db or not p or p.logged or not p.known or not p.ready then return end
  box(pid, p.registered and "login" or "register", line)
end

-- ------------------------------------------------------------------ the welcome
-- At the session's first spawn (accounts on, WELCOME.enabled) the server holds the player still until the login, and the welcome
-- page comes up with the keyboard and the mouse (its focus policy is "open") - in front of the password box, which gets the keys
-- once the rules are accepted and the page hides. A real role-play server greets a player that way, and the labs see what its
-- players see: a page that takes the keys at the join beside a client script's box. p.rules: "pending" while the page asks,
-- "accepted", or "skipped" for a player whose game has no web layer or whose page never loaded (the rules go to the chat and
-- nothing waits for them). The password waits only for a page that is up and loaded (IsPlayerWebFrameReady): never for one
-- that is gone, failed or not there - nobody is stuck at the gate because a page did not draw.
local WELCOME_FRAME = "welcome"

local function rulesInChat(pid)
  say(pid, "The realm's rules:")
  for i, rule in ipairs(WELCOME.rules) do say(pid, fmt("  %d. %s", i, rule)) end
end

function greet(pid, p)
  if not db or not WELCOME.enabled or p.logged or p.greeted then return end
  p.greeted = true
  p.held = true
  TogglePlayerControllable(pid, false)   -- still at the spawn until the login
  if not IsPlayerWebReady(pid) and p.webStatus ~= "starting" then   -- no web pages in this player's game
    p.rules = "skipped"
    rulesInChat(pid)
    return
  end
  p.rules = "pending"
  SendPlayerWebMessage(pid, WELCOME_FRAME, { name = WELCOME.name or ("BasicRP on " .. GetLevelName()), rules = WELCOME.rules, answer = WELCOME.answer })
  ShowPlayerWebFrame(pid, WELCOME_FRAME)
  SetPlayerWebFocus(pid, WELCOME_FRAME, true, true)   -- the keyboard and the mouse at once
end

function skipWelcome(pid)
  local p = players[pid]
  if not p or p.rules ~= "pending" then return end
  p.rules = "skipped"
  HidePlayerWebFrame(pid, WELCOME_FRAME)
  rulesInChat(pid)
end

-- true while the password must wait: the rules are asked and their page is up and loaded; a page that is not ready by the time
-- the password comes is let go (it would take the keys from the box later)
function rulesFirst(pid, p)
  if p.rules ~= "pending" then return false end
  if IsPlayerWebFrameReady(pid, WELCOME_FRAME) then return true end
  skipWelcome(pid)
  return false
end

function welcomeEvent(pid, p, name)
  if name ~= "welcome.accept" or p.rules ~= "pending" then return end
  p.rules = "accepted"
  HidePlayerWebFrame(pid, WELCOME_FRAME)   -- its keys go back to the password box
  say(pid, p.logged and "Welcome to the realm." or "Welcome to the realm. Now your password, in the box.")
end

-- the login's last step: the hold goes (a new character's creator keeps the player still until it is done, leaveCreator)
function releaseHold(pid)
  local p = players[pid]
  if not p or not p.held then return end
  p.held = nil
  if not p.staged then TogglePlayerControllable(pid, true) end
end

-- The answers of register and login go where the password came from: the box, or the chat's /register and /login.
function register(pid, password, fromBox)
  if not db then say(pid, "This server keeps no accounts.") return true end
  local p = players[pid]
  if not p or p.logged then return true end
  local function answer(kind, text, chatText)
    if fromBox then box(pid, kind, text) else say(pid, chatText or text) end
  end
  if rulesFirst(pid, p) then
    answer("register", "Accept the realm's rules first - the page in front of you.")
    return true
  end
  if p.registered then
    answer("login", "This name has an account already - log in with its password.", "This name is registered already: /login <password>.")
    return true
  end
  local length = utf8.len(password) or #password   -- characters, not bytes (an umlaut is two)
  if length < 4 or length > 32 or password:find("%s") then
    answer("register", "A password is 4 to 32 characters, without spaces.", "Usage: /register <password> (4 to 32 characters, no spaces).")
    return true
  end
  p.registered = true   -- before the answer comes back: a second one meanwhile is refused
  db:Execute("INSERT INTO players (name, password, visits) VALUES (@n, @p, 0)", { n = p.name, p = HashPassword(password) }, function(_, _, err)
    if not IsPlayerConnected(pid) or players[pid] ~= p then return end
    if err then
      p.registered = false
      Log("BasicRP: register failed for " .. p.name .. ": " .. err)
      answer("register", "The account could not be made - try again in a moment.", "The registration failed; try again in a moment.")
      return
    end
    Log("BasicRP: " .. p.name .. " registered")
    answer("login", "Your account is made. Now log in with the password you chose.", "Registered: this name is yours now. Now /login <password>.")
  end)
  return true
end

function login(pid, password, fromBox)
  if not db then say(pid, "This server keeps no accounts.") return true end
  local p = players[pid]
  if not p then return true end
  if p.logged then if not fromBox then say(pid, "You are logged in already.") end return true end
  local function answer(kind, text, chatText)
    if fromBox then box(pid, kind, text) else say(pid, chatText or text) end
  end
  if rulesFirst(pid, p) then
    answer("login", "Accept the realm's rules first - the page in front of you.")
    return true
  end
  if not p.registered then
    answer("register", "This name has no account yet - choose a password to make it yours.", "This name is not registered: /register <password> makes it yours.")
    return true
  end
  if #password == 0 then answer("login", "Type your password first.", "Usage: /login <password>") return true end
  if p.checking then return true end   -- one check at a time: the database answers the first
  p.checking = true
  db:Query("SELECT id, password, x, y, z, yaw, money, level, look, nourishment, energy FROM players WHERE name = @n", { n = p.name }, function(rows, err)
    p.checking = false
    if err then Log("BasicRP: " .. err) return end
    if not IsPlayerConnected(pid) or players[pid] ~= p then return end
    if #rows == 0 or not VerifyPassword(password, rows[1].password) then
      p.tries = (p.tries or 0) + 1
      if p.tries >= MAX_TRIES then
        Log("BasicRP: " .. p.name .. " kicked after " .. p.tries .. " wrong passwords")
        Kick(pid, "Too many wrong passwords.")
        return
      end
      answer("login", fmt("Wrong password - %d of %d tries left.", MAX_TRIES - p.tries, MAX_TRIES), "Wrong password.")
      return
    end
    p.logged = true
    SendClientEvent(pid, "auth", "close")   -- the box goes, whichever way the password came
    local row = rows[1]
    db:Execute("UPDATE players SET visits = visits + 1 WHERE name = @n", { n = p.name })
    -- a row that never saved a purse or bags (an account made before this, or never played out) keeps the kit
    if row.money and row.money > 0 then
      p.savedMoney = row.money
      if p.outfitted then GivePlayerMoney(pid, row.money - GetPlayerMoney(pid)) end   -- the purse as they left it (the kit's 3000 replaced)
    end
    p.id = row.id
    loadSaves(pid, p)   -- the bags and the horse, from their tables
    loadProgress(pid, p, row)   -- the stats, skills, perks and states the character left with
    loadDiscovery(pid, p)       -- the places and books they found (when a DISCOVERY rule keeps them)
    loadQuests(pid, p)          -- the quests in their journal (the ones with a key)
    promote(pid)
    local place = row.x and row.level == GetLevel() and { row.x, row.y, row.z, row.yaw } or nil   -- the saved place, on this level
    -- the character's look as it was saved; an account without one (its first login, an account from before the looks, a
    -- part a game update removed) makes its character first, in a world of its own at the spawn
    if row.look and row.look ~= "" and SetPlayerLook(pid, row.look) then
      if place and IsPlayerInWorld(pid) then
        SetPlayerPos(pid, place[1], place[2], place[3], place[4])   -- back where they left
        say(pid, fmt("Logged in. Welcome back, %s - you are where you left.", GetPlayerName(pid)))
      else
        say(pid, fmt("Logged in. Welcome, %s.", GetPlayerName(pid)))
      end
    else
      say(pid, fmt("Logged in. Welcome, %s.", GetPlayerName(pid)))
      stageCreator(pid, place)
    end
    releaseHold(pid)   -- the welcome's hold goes (after stageCreator: a new character's creator keeps its own)
  end)
  return true
end

-- ------------------------------------------------------------------ the character's look
-- The creator is this mode's client half (gamemodes/basicrp/client/creator.lua): the mode sends the parts it offers -
-- the plain faces, every hair style with its colors (the barber's cuts too), the beards, the skins, and the same for a
-- woman (her faces, hair and skins; she has no beard) - and opens it with the player's look; the player picks a man or a
-- woman, turns the preview, picks, and the client asks for the look. OnPlayerLookChange takes it only while the creator is
-- open, and saves it with the account. A new character's creator has no cancel. A player who becomes a woman (or a man
-- again) is asked by their game to restart it once: the body loads with the level.
local creatorParts   -- the payload of "creator_parts", built once from the game's lists

-- one body's hair styles as "style:color,color;style:..." - the colors of each hair model (not a named character's:
-- m_hair_005_mIstvan), and the barber's cuts (one color each)
local function hairStyles(gender)
  local hair, order = {}, {}
  for _, part in ipairs(GetLookParts("hair", "", gender)) do
    if part.style ~= "" and part.generic and not part.name:find("%u") then
      if not hair[part.style] then hair[part.style] = {} order[#order + 1] = part.style end
      table.insert(hair[part.style], part.name)
    elseif part.name:find("^m_hair_barber_") then
      hair[part.name] = {part.name}
      order[#order + 1] = part.name
    end
  end
  local styles = {}
  for _, style in ipairs(order) do styles[#styles + 1] = style .. ":" .. table.concat(hair[style], ",") end
  return table.concat(styles, ";")
end

-- one body's plain faces (not their variants) and skin tones (the names that start with one of `tones`, not their groups)
local function facesAndSkins(gender, tones)
  local faces, skins = {}, {}
  for _, part in ipairs(GetLookParts("head", "generic", gender)) do
    if part.style == "" then faces[#faces + 1] = part.name end
  end
  for _, part in ipairs(GetLookParts("body", "generic", gender)) do
    for _, tone in ipairs(tones) do
      if part.name:sub(1, #tone) == tone then skins[#skins + 1] = part.name break end
    end
  end
  return faces, skins
end

local function buildCreatorParts()
  local faces, skins = facesAndSkins("", {"m_body_"})
  local herFaces, herSkins = facesAndSkins("female", {"f_body_", "f_roma_"})
  local beards = {"m_beard_00"}
  for _, part in ipairs(GetLookParts("beard")) do
    if (part.generic and part.name:find("^m_beard_") and part.name ~= "m_beard_00") or part.name:find("^UC_beard_barber_") then
      beards[#beards + 1] = part.name
    end
  end
  if #faces == 0 then return nil end   -- no tables export: nothing to offer
  local payload = "faces=" .. table.concat(faces, ",") .. "|hair=" .. hairStyles("") .. "|beards=" .. table.concat(beards, ",")
    .. "|skins=" .. table.concat(skins, ",")
  if #herFaces > 0 then
    payload = payload .. "|ffaces=" .. table.concat(herFaces, ",") .. "|fhair=" .. hairStyles("female") .. "|fskins=" .. table.concat(herSkins, ",")
  end
  return payload
end

-- true when the creator opened
function openCreator(pid, first)
  local p = players[pid]
  if not p or not IsPlayerInWorld(pid) then return false end
  creatorParts = creatorParts or buildCreatorParts()
  if not creatorParts then   -- a new character keeps the game's look without a word; /look says why
    if not first then say(pid, "This server has no list of faces and hair to choose from (the tables export is missing).") end
    return false
  end
  if not p.partsSent then
    SendClientEvent(pid, "creator_parts", creatorParts)
    p.partsSent = true
  end
  p.creating = true
  p.firstLook = first
  SendClientEvent(pid, "creator", (first and "new" or "edit") .. ";" .. LookToString(GetPlayerLook(pid)))
  if first then say(pid, "Make your character: the face, the hair, the beard, the skin.") end
  return true
end

-- An account's first login without a look: the player goes into a world of their own (CREATOR_WORLD + the id: nobody sees
-- a half-made character, and two new players do not stand inside each other) at the map's spawn point; the creator opens
-- a moment later (the move has landed: the preview stands where they look), and its "done" (leaveCreator) brings them
-- into the shared world - at the spawn, or at the place an account from before the looks had saved.
function stageCreator(pid, place)
  local p = players[pid]
  if not p or not IsPlayerInWorld(pid) then return end
  p.staged = place or { spawnSpot(pid) }   -- where the shared world takes them afterwards
  SetPlayerVirtualWorld(pid, CREATOR_WORLD + pid)
  SetPlayerPos(pid, spawnX, spawnY, spawnZ, spawnYaw)
  TogglePlayerControllable(pid, false)   -- nobody walks off before the creator opens (it turns the view onto the body itself)
  Log(fmt("BasicRP: %s makes a character in world %d", GetPlayerName(pid), CREATOR_WORLD + pid))
  SetTimer(function()
    if not IsPlayerConnected(pid) or players[pid] ~= p or not p.staged then return end
    if not openCreator(pid, true) then leaveCreator(pid) end   -- nothing to choose from (no tables export): straight in
  end, 1500)
end

function leaveCreator(pid)
  local p = players[pid]
  if not p or not p.staged then return end
  local to = p.staged
  p.staged = nil
  SetPlayerVirtualWorld(pid, 0)
  SetPlayerPos(pid, to[1], to[2], to[3], to[4])
  TogglePlayerControllable(pid, true)
  Log(fmt("BasicRP: %s joins the shared world at %.1f %.1f", GetPlayerName(pid), to[1], to[2]))
end

function saveLook(pid, look)
  local p = players[pid]
  if not db or not p or not p.logged then return end
  db:Execute("UPDATE players SET look = @l WHERE name = @n", { l = LookToString(look), n = p.name }, function(_, _, err)
    if err then Log("BasicRP: the look of " .. p.name .. " was not saved: " .. err) end
  end)
end

-- the creator's "done": the look is the player's while the creator is open, and saved with the account
function OnPlayerLookChange(pid, look)
  local p = players[pid]
  if not p or not p.creating then return false end
  p.creating = false
  saveLook(pid, look)
  SendClientEvent(pid, "creator", "close")
  say(pid, p.firstLook and "Your character is made. /look changes it later." or "Your new look suits you.")
  leaveCreator(pid)   -- a new character: out of its world of one, into the shared world (the look goes along)
  return true
end

function OnClientEvent(pid, name, payload, source)
  local p = players[pid]
  if not p then return end
  if source == "welcome" then welcomeEvent(pid, p, name) return end            -- the welcome page's test
  if source and TOWN.webEvent(pid, name, payload, source) then return end   -- the town's web pages (the stable, the menu)
  if name == "auth_ready" then            -- the client half is up: the password box can open
    p.ready = true
    askPassword(pid)
  elseif name == "auth_register" then
    register(pid, payload, true)
  elseif name == "auth_login" then
    login(pid, payload, true)
  elseif name == "creator_cancel" and p.creating and not p.firstLook then
    p.creating = false   -- the look stays as it was
  elseif name:sub(1, 10) == "cartmaker_" then
    cartMakerEvent(pid, p, name, payload)
  elseif name == "board.spot" then
    boardSpot(pid, payload)
  end
end

-- ------------------------------------------------------------------ the bags and the horse a player keeps
-- What the player carries is rows of player_items (the money apart: the purse is players.money), put back at the next login
-- with SetPlayerInventory - the missing given, the surplus taken, what they wore put on again - so the spawn's outfit and
-- the kit turn into the saved bags without a double. Their horse is a row of player_horses (the breed) with its gear and
-- its saddlebags as rows of horse_items. The server forgets every horse when it stops, and the horse leaves the world with
-- its owner (left behind it would be nobody's, its bags anyone's): /horse makes it again, as it was. A list is written
-- only when it changed since the last save, its old rows deleted and the new ones inserted in one transaction.
local MONEY_CLASS = "5ef63059-322e-4e1b-abe8-926e100c770e"

function itemName(class)                  -- the catalogue's name beside the GUID, for a person reading the rows
  local name = GetItemName(class)
  return name ~= "" and name or DB_NULL
end

function stacksKey(stacks)                -- a list as one text, to tell whether it changed
  local parts = {}
  for _, it in ipairs(stacks) do
    local key = fmt("%s:%d:%d:%d", it.class, it.amount, it.health or 100, it.worn and 1 or 0)
    if it.id and it.id ~= "" then   -- a tagged item: its tag too (a renamed or reweighed prize is a change)
      key = key .. fmt(":%s|%s|%s|%s|%s|%s", it.id, it.name or "", it.text or "", tostring(it.weight), tostring(it.price), it.model or "")
    end
    parts[#parts + 1] = key
  end
  return table.concat(parts, ";")
end

-- one list's rows into a batch: the old ones deleted, the new ones inserted (a tagged item with its tag, where the table keeps it)
local function stackStatements(batch, tbl, column, id, stacks)
  batch[#batch + 1] = { "DELETE FROM " .. tbl .. " WHERE " .. column .. " = @id", { id = id } }
  for slot, it in ipairs(stacks) do
    local values = { id = id, s = slot, i = it.class, n = itemName(it.class), a = it.amount, h = it.health or 100, w = it.worn and 1 or 0 }
    if tagsSaved[tbl] then
      local tagged = it.id ~= nil and it.id ~= "" and #it.id <= 255
      values.tid = tagged and it.id or DB_NULL
      values.tn = tagged and (it.name or "") or DB_NULL
      values.tt = tagged and (it.text or "") or DB_NULL
      values.tw = tagged and it.weight or DB_NULL
      values.tp = tagged and it.price or DB_NULL
      values.tm = tagged and it.model and #it.model <= 64 and it.model or DB_NULL
      batch[#batch + 1] = { "INSERT INTO " .. tbl .. " (" .. column .. ", slot, item, item_name, amount, health, worn, " ..
        "item_id, tag_name, tag_text, tag_weight, tag_price, tag_model) VALUES (@id, @s, @i, @n, @a, @h, @w, @tid, @tn, @tt, @tw, @tp, @tm)", values }
    else
      batch[#batch + 1] = { "INSERT INTO " .. tbl .. " (" .. column .. ", slot, item, item_name, amount, health, worn) " ..
        "VALUES (@id, @s, @i, @n, @a, @h, @w)", values }
    end
  end
end

function flush(batch, what)
  if #batch == 0 then return end
  db:Batch(batch, function(ok, err) if not ok then Log("BasicRP: " .. what .. " not saved: " .. tostring(err)) end end)
end

local function readStacks(rows)
  local stacks = {}
  for _, r in ipairs(rows or {}) do
    if r.item then
      local stack = { class = r.item, amount = tonumber(r.amount) or 1, health = tonumber(r.health) or 100, worn = tonumber(r.worn) == 1 }
      if r.item_id and r.item_id ~= "" then   -- a tagged item: SetPlayerInventory / SetHorseItems make it again with its tag
        stack.id, stack.name, stack.text = r.item_id, r.tag_name or "", r.tag_text or ""
        stack.weight, stack.price = tonumber(r.tag_weight), tonumber(r.tag_price)
        if r.tag_model and r.tag_model ~= "" then stack.model = r.tag_model end
      end
      stacks[#stacks + 1] = stack
    end
  end
  return stacks
end

local BAGS_WAIT = 120000   -- ms: how long the game has to report the restored bags back before the mode stops waiting for it

-- the classes of the restore the bags the player's game last reported hold in full (each at least as many as saved), the
-- number of classes the restore ordered, and the ones missing
local function bagsHeld(pid, want)
  local have, need = {}, {}
  for _, it in ipairs(GetPlayerInventory(pid)) do
    local class = it.class:lower()
    have[class] = (have[class] or 0) + it.amount
  end
  for _, it in ipairs(want) do
    local class = it.class:lower()
    need[class] = (need[class] or 0) + it.amount
  end
  local held, total, missing = 0, 0, {}
  for class, amount in pairs(need) do
    total = total + 1
    if (have[class] or 0) >= amount then
      held = held + 1
    else
      local name = GetItemName(class)
      missing[#missing + 1] = (name and name ~= "") and name or class
    end
  end
  return held, total, missing
end

-- true when the bags the player's game last reported hold every stack the restore ordered
local function bagsConfirmed(pid, want)
  local held, total = bagsHeld(pid, want)
  return held == total
end

function restoreInventory(pid, items)
  local p = players[pid]
  SetPlayerInventory(pid, items)
  if p then
    p.bagsRestored = true
    if p.savedOutfits then restoreOutfits(pid, p) end   -- after the bags: the outfits are dressed out of what they hold
    p.bagsKey = stacksKey(items)
    -- saved again once the game has reported the restore (bagsConfirmed, at a change): a save before that would write the
    -- bags it replaced. A game that never reports them leaves the saved bags as they are - not a slow start that a timer
    -- guesses at, which wrote the newcomer's bags over a character's whenever the restore was late.
    p.bagsWant = items
    p.bagsReady = false
    SetTimer(function()
      if players[pid] ~= p or p.bagsReady or not p.bagsWant then return end
      -- still not all there: a saved item the game no longer gives (an item a game update took away) would keep every change
      -- of the session from being saved. Bags that hold at least half of the restore's stacks show it landed: saved from
      -- here on, without the missing ones; bags that hold less are the ones the restore never reached - left unsaved.
      local held, total, missing = bagsHeld(pid, p.bagsWant)
      p.bagsWant = nil
      if held * 2 >= total then
        p.bagsReady = true
        if #missing > 0 then
          Log(fmt("BasicRP: %s's bags came back without %s - saved from here on as the game holds them", GetPlayerName(pid),
            table.concat(missing, ", ")))
        end
        saveCarried(pid)
      else
        Log(fmt("BasicRP: %s's bags were not reported back within %d s (%d of %d stacks) - they are not saved this session, the saved ones stay",
          GetPlayerName(pid), BAGS_WAIT // 1000, held, total))
      end
    end, BAGS_WAIT)
  end
  Log(fmt("BasicRP: %s's bags restored (%d stacks)", GetPlayerName(pid), #items))
end

-- the player's bags into the batch when they changed
function saveBags(pid, p, batch)
  if not p.bagsReady then return end
  local stacks = {}
  for _, it in ipairs(GetPlayerInventory(pid)) do
    if it.class ~= MONEY_CLASS then stacks[#stacks + 1] = it end
  end
  local key = stacksKey(stacks)
  if key == p.bagsKey then return end
  p.bagsKey = key
  stackStatements(batch, "player_items", "player_id", p.id, stacks)
end

function ownHorse(pid)
  local owned = GetPlayerHorses(pid)
  return owned[#owned]   -- the newest (this mode gives one)
end

-- the horse's rows: its gear first (worn), then what its saddlebags hold
local function horseStacks(horse)
  local stacks = {}
  for _, class in ipairs(GetHorseGear(horse) or {}) do stacks[#stacks + 1] = { class = class, amount = 1, health = 100, worn = true } end
  for _, it in ipairs(GetHorseItems(horse) or {}) do stacks[#stacks + 1] = it end
  return stacks
end

-- a horse of the player's into the batch when it changed
function saveHorse(pid, horse, batch)
  local p = players[pid]
  local id = horse and tonumber(GetEntityData(horse, "db_id"))
  if not (db and p and p.logged and id) then return end   -- a first horse's row is still being made: its callback saves it
  local stacks = horseStacks(horse)
  local key = stacksKey(stacks)
  p.horseKeys = p.horseKeys or {}
  if key == p.horseKeys[id] then return end
  p.horseKeys[id] = key
  if horse == ownHorse(pid) then p.savedHorse = { dbId = id, breed = GetEntityTemplate(horse), coat = GetHorseCoat(horse), stacks = stacks } end
  stackStatements(batch, "horse_items", "horse_id", id, stacks)
end

-- the purse into the batch when it changed
local function savePurse(pid, p, batch)
  local money = GetPlayerMoney(pid)
  if money == p.purseKey then return end
  p.purseKey = money
  batch[#batch + 1] = { "UPDATE players SET money = @m WHERE id = @id", { m = money, id = p.id } }
end

-- What the player carries - the bags, the purse, their horses - saved in one transaction, only what changed: an item that
-- moves between them (into the saddlebags, sold for money) is in one place in the database, never in two. It runs the
-- moment the server hears of a change (OnPlayerInventoryChange, OnHorseItemsChange), so what a player hands to a chest, the
-- ground or a shop - the server's at once - is gone from their saved bags within a second too; a crash can no longer give
-- it back.
function saveCarried(pid)
  local p = players[pid]
  if not (db and p and p.logged and p.id) or p.staged then return end
  local batch = {}
  saveBags(pid, p, batch)
  savePurse(pid, p, batch)
  for _, horse in ipairs(GetPlayerHorses(pid)) do saveHorse(pid, horse, batch) end
  flush(batch, "the things of " .. p.name)
end

function OnPlayerInventoryChange(pid)
  if not IsPlayerInWorld(pid) then return end
  local p = players[pid]
  if p and not p.bagsReady and p.bagsWant and bagsConfirmed(pid, p.bagsWant) then
    p.bagsReady = true   -- the game holds what the restore ordered: what it reports from here on is the character's
    p.bagsWant = nil
  end
  saveCarried(pid)
end

-- The game's three outfits (its inventory's flags A, B, C): which items each one wears, by class. The game keeps an outfit as the
-- items themselves and a login makes every item anew, so they are saved here (player_outfits, players.outfit = the one worn) and
-- handed back after the bags (SetPlayerOutfits): the player's game dresses each outfit again out of what they carry. Saved only once
-- the saved ones were handed back (p.outfitsReady) - the fresh game's empty outfits must not be written over the character's.
function outfitsKey(o)
  local parts = { tostring(o.current) }
  for k = 1, 3 do parts[#parts + 1] = table.concat(o[k] or {}, ",") end
  return table.concat(parts, ";")
end

function restoreOutfits(pid, p)
  local saved = p.savedOutfits
  p.savedOutfits = nil
  if SetPlayerOutfits(pid, saved) then
    p.outfitsKey = outfitsKey(saved)
    Log(fmt("BasicRP: %s's outfits restored (wearing %s)", GetPlayerName(pid), string.char(64 + saved.current)))
  end
  p.outfitsReady = true   -- what the game reports from here (after it dressed them) is the character's
end

function OnPlayerOutfitChange(pid)
  local p = players[pid]
  if not (db and p and p.logged and p.id) or not p.outfitsReady or p.staged then return end
  local o = GetPlayerOutfits(pid)
  if not o then return end
  local key = outfitsKey(o)
  if key == p.outfitsKey then return end
  p.outfitsKey = key
  local batch = { { "DELETE FROM player_outfits WHERE player_id = @id", { id = p.id } },
    { "UPDATE players SET outfit = @o WHERE id = @id", { o = o.current, id = p.id } } }
  for k = 1, 3 do
    for slot, class in ipairs(o[k] or {}) do
      batch[#batch + 1] = { "INSERT INTO player_outfits (player_id, outfit, slot, item, item_name) VALUES (@id, @k, @s, @i, @n)",
        { id = p.id, k = k, s = slot, i = class, n = itemName(class) } }
    end
  end
  flush(batch, "the outfits of " .. p.name)
end

function OnHorseItemsChange(id)
  local owner = GetHorseOwner(id)
  if owner then saveCarried(owner) end
end

-- at the login: the saved bags (put back now, or at the spawn) and the active horse (for /horse)
function loadSaves(pid, p)
  local tagCols = tagsSaved.player_items and ", item_id, tag_name, tag_text, tag_weight, tag_price, tag_model" or ""
  db:Query("SELECT item, amount, health, worn" .. tagCols .. " FROM player_items WHERE player_id = @p ORDER BY slot", { p = p.id }, function(rows, err)
    if err then Log("BasicRP: the bags of " .. p.name .. " could not be read: " .. err) return end
    if players[pid] ~= p then return end
    local items = readStacks(rows)
    if #items == 0 then
      p.bagsReady = true   -- nothing saved (a new account): the kit stays, and is saved from here
      p.bagsRestored = true
      if p.savedOutfits then restoreOutfits(pid, p) end
      return
    end
    p.savedItems = items
    if p.outfitted then restoreInventory(pid, items) end   -- spawned already; else OnPlayerSpawn puts them back
  end)
  -- the game's three outfits (player_outfits; players.outfit the one worn), handed back after the bags
  db:Query("SELECT p.outfit AS cur, o.outfit, o.item FROM players p LEFT JOIN player_outfits o ON o.player_id = p.id WHERE p.id = @p " ..
    "ORDER BY o.outfit, o.slot", { p = p.id }, function(rows, err)
      if err then Log("BasicRP: the outfits of " .. p.name .. " could not be read: " .. err) return end
      if players[pid] ~= p then return end
      local saved, any = { {}, {}, {} }, false
      for _, r in ipairs(rows) do
        saved.current = saved.current or tonumber(r.cur)
        local k = tonumber(r.outfit)
        if r.item and saved[k] then
          table.insert(saved[k], r.item)
          any = true
        end
      end
      if not any then
        p.outfitsReady = true   -- none saved: what the game reports from here is the character's
        return
      end
      saved.current = math.max(1, math.min(3, math.floor(saved.current or 1)))
      p.savedOutfits = saved
      if p.bagsRestored then restoreOutfits(pid, p) end
    end)
  local horseTagCols = tagsSaved.horse_items and ", i.item_id, i.tag_name, i.tag_text, i.tag_weight, i.tag_price, i.tag_model" or ""
  db:Query("SELECT h.id AS hid, h.soul, h.coat, i.item, i.amount, i.health, i.worn" .. horseTagCols ..
    " FROM player_horses h LEFT JOIN horse_items i ON i.horse_id = h.id " ..
    "WHERE h.player_id = @p AND h.active = 1 ORDER BY h.id DESC, i.slot", { p = p.id }, function(rows, err)
    if err then Log("BasicRP: the horse of " .. p.name .. " could not be read: " .. err) return end
    if players[pid] ~= p or #rows == 0 then return end
    local first, mine = rows[1].hid, {}
    for _, r in ipairs(rows) do
      if r.hid == first then mine[#mine + 1] = r end
    end
    local coat = rows[1].coat
    p.savedHorse = { dbId = first, breed = rows[1].soul, coat = coat ~= "" and coat or nil, stacks = readStacks(mine) }
  end)
  -- the stats an admin gave their horses (put on a horse when /horse makes it again)
  db:Query("SELECT s.horse_id, s.stat, s.level FROM horse_stats s JOIN player_horses h ON h.id = s.horse_id WHERE h.player_id = @p",
    { p = p.id }, function(rows, err)
      if err then Log("BasicRP: the horse stats of " .. p.name .. " could not be read: " .. err) return end
      if players[pid] ~= p then return end
      p.horseStats = p.horseStats or {}
      for _, r in ipairs(rows) do
        local stats = p.horseStats[r.horse_id] or {}
        stats[r.stat] = tonumber(r.level)
        p.horseStats[r.horse_id] = stats
      end
    end)
end

-- ------------------------------------------------------------------ the progression a character keeps
-- The stats, the skills, the perks, the main level and what a character has eaten and slept are the soul's in the player's
-- game, which reports them to the server a few seconds after the spawn and on every change; the server hands them to this
-- mode (GetPlayerProgress). They are saved with the character - player_progress (one row per stat and skill: its level, the
-- XP toward the next and its unspent perk points), player_perks (one row per perk), the nourishment and the energy in the
-- players row - the moment a level or a perk changes and every minute with the place, and put back at the next login with
-- SetPlayerProgress. The main level ("mainlevel") is a row like the others but the game works its level out itself: it is saved
-- for the eye, and only its perk points are put back (SetPlayerPerkPoints). A character is saved only after its saved
-- progression was put back (p.progressReady): a game that crashed, or reports late, must not write its fresh soul over the
-- character - the lesson of the bags. The rules - change them here:
PROGRESS = {
  xp_rate = 1,   -- every XP the game awards a player (a kill, a hit, a book, a distance walked) counts this many times: 0 none, 1 as the game gives it
}

-- What a character found of the world, kept with it. The player's game reports the named places and points of interest, the books
-- read, the map's pin and legend and the parts of the map uncovered; the server records them (they only ever grow - the pin and the
-- legend are the newest), this mode saves the record in player_discovery (one row per level and kind; the
-- books are the same on every level) and puts it back at the next login. All off: the game's own map behaviour - the whole map shown
-- from the start - and nothing saved; no table is made and no player's game is asked for anything. The rules - change them here:
DISCOVERY = {
  places = false,      -- the named places (villages, towns, camps) and points of interest a character found - they show on the map with their names
  reading = false,     -- the books a character read and how far they studied each: re-reading a book after a relog no longer farms its XP
  ui = false,          -- the pin a character placed on the map and the legend categories they switched off
  fog = false,         -- the parts of the map a character uncovered: only with map_fog = true under [ui] in server.toml (else the whole map shows anyway)
  explorer = "keep",   -- "strip": the Explorer perk, which reveals the whole level the moment a character holds it, is left out of the perks put back at the login
}
local EXPLORER_PERK = "34e03c47-de53-482f-b3f5-555e7e36d70c"   -- the game's Explorer perk

-- The quests a character holds in the game's journal, kept with it: every quest made with a key (CreateQuest's `key` - a script built on
-- this mode gives its quests one) is saved in player_quests with its state and each objective's, and put back, silently, at the next
-- login. A quest without a key is never saved: its id lasts one server run. The rules - change them here:
QUESTS = {
  keep = true,   -- false: the players' quests last until they leave, as the server keeps them (no table is made)
}

-- the names the game's menus show for the stats and skills whose own names differ
local LABELS = { mainlevel = "main level", storyprogress = "story progress", horse_riding = "horsemanship", fencing = "warfare",
  weapon_sword = "swords", weapon_large = "polearms", weapon_unarmed = "unarmed", weapon_shield = "shield", weapon_dagger = "dagger" }
local STAT_ORDER = { "strength", "agility", "vitality", "speech" }   -- /skills' stats line; the main level has a line of its own

local function label(name) return LABELS[name] or (name:gsub("_", " ")) end

-- "2 perk points" for points above 0, else nil
local function perkPoints(points)
  points = tonumber(points) or 0
  if points <= 0 then return nil end
  return fmt("%d perk point%s", points, points == 1 and "" or "s")
end

-- a name the admin typed for the main level (the game works it out, so no command sets it)
local MAIN_LEVEL_NAMES = { mainlevel = true, main_level = true, main = true, level = true }
local function isMainLevel(name) return MAIN_LEVEL_NAMES[(name:lower():gsub("[%s%-]", "_"))] == true end

-- warfare (the game's fencing) is worked out from the weapon skills too: set or give XP to those instead
local WARFARE_NAMES = { warfare = true, fencing = true }
local function isWarfare(name) return WARFARE_NAMES[(name:lower():gsub("[%s%-]", "_"))] == true end
local WARFARE_REFUSAL = "Warfare follows the weapon skills (swords, heavy weapons, polearms, unarmed, marksmanship) - set those. /perkpoints sets its points."

-- a command's arguments that would not parse: no such player, or the usage
local function badArgs(pid, reason, line)
  SendClientMessage(pid, COLOR_RED, tostring(reason):find("^no player") and "No such player." or "Usage: " .. line)
  return true
end

-- "warfare 8 (2 perk points)" for a stat or skill of GetPlayerProgress
local function progressEntry(name, v)
  local points = perkPoints(v.points)
  return fmt("%s %d", label(name), v.level) .. (points and " (" .. points .. ")" or "")
end

-- /skills: the main level first, then the player's stats and skills as their game last reported them, the perk points not
-- spent yet beside the ones that have any; /skills <name> one of them with its XP
local function showSkills(pid, name)
  if name ~= "" then
    local level, xp, need = GetPlayerStat(pid, name), nil, nil
    if level > 0 then
      xp, need = GetPlayerStatXP(pid, name)
    else
      level = GetPlayerSkill(pid, name)
      if level > 0 then xp, need = GetPlayerSkillXP(pid, name) end
    end
    local points = perkPoints(GetPlayerPerkPoints(pid, name))
    if level == 0 then
      SendClientMessage(pid, COLOR_RED, "No stat or skill of that name, or your game has not reported it yet: " .. name)
    elseif (need or 0) > 0 then
      say(pid, fmt("%s: level %d, %.0f of %.0f XP to the next", name, level, xp, need) .. (points and ", " .. points or ""))
    else
      say(pid, fmt("%s: level %d", name, level) .. (points and ", " .. points or ""))
    end
    return
  end
  local progress = GetPlayerProgress(pid)
  local main, stats, skills, names = progress and progress.stats.mainlevel, {}, {}, {}
  for _, stat in ipairs(STAT_ORDER) do
    local v = progress and progress.stats[stat]
    if v then stats[#stats + 1] = progressEntry(stat, v) end
  end
  for skill in pairs(progress and progress.skills or {}) do names[#names + 1] = skill end
  table.sort(names, function(a, b) return label(a) < label(b) end)
  for _, skill in ipairs(names) do skills[#skills + 1] = progressEntry(skill, progress.skills[skill]) end
  if not main and #stats == 0 and #skills == 0 then
    say(pid, "Your game has not reported your skills yet - it does a few seconds after you spawn.")
    return
  end
  if main then
    local points = perkPoints(main.points)
    say(pid, fmt("Main level: %d", main.level) .. (points and " (" .. points .. ")" or ""))
  end
  if #stats > 0 then say(pid, "Stats: " .. table.concat(stats, ", ")) end
  for i = 1, #skills, 10 do   -- ten a line: the chat's width
    SendClientMessage(pid, COLOR_WHITE, (i == 1 and "Skills: " or "  ") .. table.concat(skills, ", ", i, math.min(i + 9, #skills)))
  end
end

-- /skills for everyone; the admin's /setlevel <player> <stat|skill> <level> [xp] (level and XP set as given, lowering too;
-- the main level is the game's own to work out and is refused), /givexp <player> <stat|skill> <xp> (the game's way: the
-- level-up notice, the perk points), /perk <player> add|remove <perk> (a GUID, or a name from the perks list of the scripting
-- docs), /perkpoints <player> <stat|skill|mainlevel> <n> (the perk points not spent yet) and /xprate [rate]. The server resolves
-- the names (warfare for fencing ...)
function progressCommand(pid, cmd, args)
  if cmd == "skills" then showSkills(pid, args:match("^%s*(.-)%s*$")) return true end
  if cmd ~= "setlevel" and cmd ~= "givexp" and cmd ~= "perk" and cmd ~= "perkpoints" and cmd ~= "xprate" then return false end
  if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_RED, "/" .. cmd .. " is for admins.") return true end
  if cmd == "setlevel" then
    local target, name, level, xp = sscanf(args, "usdf?")
    if target == false then return badArgs(pid, name, "/setlevel <player> <stat|skill> <level> [xp]") end
    if isMainLevel(name) then
      SendClientMessage(pid, COLOR_RED, "The main level cannot be set - the game works it out from the stats and skills. Set those, or use /perkpoints for its points.")
      return true
    end
    if isWarfare(name) then SendClientMessage(pid, COLOR_RED, WARFARE_REFUSAL) return true end
    if not (SetPlayerStat(target, name, level, xp) or SetPlayerSkill(target, name, level, xp)) then
      SendClientMessage(pid, COLOR_RED, "Not a stat or skill, or not a level from 0 to 30 - /skills lists the names.")
      return true
    end
    say(pid, fmt("%s: %s is level %d now.", GetPlayerName(target), name, level))
    if target ~= pid then say(target, fmt("%s set your %s to level %d.", GetPlayerName(pid), name, level)) end
  elseif cmd == "givexp" then
    local target, name, xp = sscanf(args, "usf")
    if target == false then return badArgs(pid, name, "/givexp <player> <stat|skill> <xp>") end
    if isMainLevel(name) then
      SendClientMessage(pid, COLOR_RED, "The main level takes no XP of its own - give XP to a stat or a skill.")
      return true
    end
    if isWarfare(name) then SendClientMessage(pid, COLOR_RED, WARFARE_REFUSAL) return true end
    if xp <= 0 or xp > 100000 or not (AddPlayerStatXP(target, name, xp) or AddPlayerSkillXP(target, name, xp)) then
      SendClientMessage(pid, COLOR_RED, "Not a stat or skill, or not an XP amount above 0 and up to 100000 - /skills lists the names.")
      return true
    end
    say(pid, fmt("%s: %g XP in %s.", GetPlayerName(target), xp, name))
  elseif cmd == "perk" then
    local target, how, perk = sscanf(args, "usz")
    if target == false then return badArgs(pid, how, "/perk <player> add|remove <perk>") end
    how = how:lower()
    if how ~= "add" and how ~= "remove" then return badArgs(pid, "", "/perk <player> add|remove <perk>") end
    local ok
    if how == "add" then ok = AddPlayerPerk(target, perk) else ok = RemovePlayerPerk(target, perk) end
    if not ok then
      SendClientMessage(pid, COLOR_RED, "No such perk: " .. perk .. " - a GUID, or a name from the list at docs.kcd-mp.com/reference/perks/")
      return true
    end
    say(pid, fmt("%s: %s %s.", GetPlayerName(target), GetPerkName(perk) or perk, how == "add" and "added" or "taken away"))
  elseif cmd == "perkpoints" then
    local target, name, points = sscanf(args, "usd")
    if target == false then return badArgs(pid, name, "/perkpoints <player> <stat|skill|mainlevel> <points>") end
    if points < 0 or not SetPlayerPerkPoints(target, name, points) then
      SendClientMessage(pid, COLOR_RED, "Not a stat, a skill or mainlevel, or not a number of perk points the game takes (0 or more) - /skills lists the names.")
      return true
    end
    say(pid, fmt("%s: %s has %d perk point%s now.", GetPlayerName(target), name, points, points == 1 and "" or "s"))
    if target ~= pid then say(target, fmt("%s set your %s perk points to %d.", GetPlayerName(pid), name, points)) end
  else
    local rate, why = sscanf(args, "f?")
    if rate == false then return badArgs(pid, why, "/xprate [rate from 0 to 100]") end
    if rate == nil then say(pid, fmt("The XP rate is %g - /xprate <rate from 0 to 100> changes it.", GetXPRate())) return true end
    if rate < 0 or rate > 100 then SendClientMessage(pid, COLOR_RED, "The XP rate is from 0 to 100.") return true end
    SetXPRate(rate)
    Log(fmt("BasicRP: %s set the XP rate to %g", GetPlayerName(pid), rate))
    say(pid, fmt("The XP rate is %g now.", rate))
  end
  return true
end

-- /horsestat [stat level]: the horse the admin rides, else their own one - its strength, agility, vitality or courage (level 1
-- to 30; /horsestat alone lists them). Saved in horse_stats and put back when /horse brings the horse again.
local HORSE_STATS = { "strength", "agility", "vitality", "courage" }
function horseStat(pid, args)
  if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_RED, "/horsestat is for admins.") return true end
  local p = players[pid]
  local mount = GetPlayerMount(pid)
  local target = mount and GetEntityKind(mount) == ENTITY_HORSE and mount or ownHorse(pid)
  if not target then say(pid, "You have no horse - /horse brings one.") return true end
  if args == "" then
    local parts = {}
    for _, stat in ipairs(HORSE_STATS) do
      local level = GetHorseStat(target, stat)
      parts[#parts + 1] = fmt("%s %s", stat, level > 0 and fmt("%d", level) or "as bred")
    end
    say(pid, "The horse: " .. table.concat(parts, ", ") .. " - /horsestat <stat> <level>")
    return true
  end
  local stat, level = sscanf(args, "sd")
  if stat == false then return badArgs(pid, level, "/horsestat <strength|agility|vitality|courage> <level from 1 to 30>") end
  stat = stat:lower()
  local known = false
  for _, s in ipairs(HORSE_STATS) do known = known or s == stat end
  if not known or level < 1 or level > 30 then
    SendClientMessage(pid, COLOR_RED, "A horse has strength, agility, vitality and courage, each from level 1 to 30.")
    return true
  end
  local id = tonumber(GetEntityData(target, "db_id"))
  if not id and db and p and p.logged and target == ownHorse(pid) then   -- their first horse: its row is still being made
    say(pid, "Your horse is not in the books yet - try again in a moment.")
    return true
  end
  if not SetHorseStat(target, stat, level) then
    SendClientMessage(pid, COLOR_RED, "That horse will not take it.")
    return true
  end
  if id and db then   -- a horse with a row: the stat is kept for the next time it is brought
    db:Batch({
      { "DELETE FROM horse_stats WHERE horse_id = @h AND stat = @s", { h = id, s = stat } },
      { "INSERT INTO horse_stats (horse_id, stat, level) VALUES (@h, @s, @l)", { h = id, s = stat, l = level } },
    }, function(ok, err) if not ok then Log("BasicRP: the horse stat was not saved: " .. tostring(err)) end end)
    local owner = players[GetHorseOwner(target) or -1]
    if owner then
      owner.horseStats = owner.horseStats or {}
      owner.horseStats[id] = owner.horseStats[id] or {}
      owner.horseStats[id][stat] = level
    end
  end
  say(pid, fmt("The horse's %s is level %d now.", stat, level))
  return true
end

-- /setenergy, /setsleep, /sethunger [value] [name] (2026-10-12, the user's ask): the admin's levers on a character's stamina (the
-- bar a swing or a sprint spends, 0 .. its maximum) and the game's Energy (how rested they are, what a bed restores, 0 .. 100) - the
-- caller's own or the named player's; alone they say the value. /sethunger: the Nourishment (how fed, 0 .. 100). The Energy and
-- the Nourishment are kept with the character (player_progress).
function vitalCommand(pid, cmd, args)
  if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_RED, "/" .. cmd .. " is for admins.") return true end
  local value, name = args:match("^%s*(%d+%.?%d*)%s*(.-)%s*$")
  if not value then name = args:match("^%s*(.-)%s*$") end
  local target = pid
  if name and name ~= "" then
    local id, why = GetPlayerId(name)
    if not id then say(pid, why or ("Nobody called " .. name .. " is here.")) return true end
    target = id
  end
  local who = target == pid and "Your" or (GetPlayerName(target) .. "'s")
  if cmd == "setenergy" then
    local max = GetPlayerMaxStamina(target) or 100
    if not value then say(pid, fmt("%s stamina is %.0f of %.0f - /setenergy <0-%.0f> [name]", who, GetPlayerStamina(target) or 0, max, max)) return true end
    SetPlayerStamina(target, math.min(tonumber(value), max))
    say(pid, fmt("%s stamina is now %.0f.", who, math.min(tonumber(value), max)))
  else
    -- /setsleep the Energy, /sethunger the Nourishment (how fed: 0 starving .. 100)
    local sleep = cmd == "setsleep"
    local what = sleep and "energy (rest)" or "nourishment"
    local now, max
    if sleep then now, max = GetPlayerEnergy(target) else now, max = GetPlayerNourishment(target) end
    if not value then
      say(pid, fmt("%s %s is %s of %s - /%s <0-100> [name]", who, what, now and fmt("%.0f", now) or "?", max and fmt("%.0f", max) or "100", cmd))
      return true
    end
    local v = math.min(tonumber(value), max or 100)
    if sleep then SetPlayerEnergy(target, v) else SetPlayerNourishment(target, v) end
    say(pid, fmt("%s %s is now %.0f.", who, what, v))
  end
  return true
end

-- /horsecoat [coat]: the horse the admin rides, else their own one - its coat, one of GetHorseCoats() (/horsecoat alone lists
-- them). Saved in player_horses and put back when /horse brings the horse again.
function horseCoat(pid, args)
  if not IsPlayerAdmin(pid) then SendClientMessage(pid, COLOR_RED, "/horsecoat is for admins.") return true end
  local mount = GetPlayerMount(pid)
  local target = mount and GetEntityKind(mount) == ENTITY_HORSE and mount or ownHorse(pid)
  if not target then say(pid, "You have no horse - /horse brings one.") return true end
  local coat = args:lower():match("^%s*(%S+)")
  if not coat then
    say(pid, fmt("The horse is %s - /horsecoat <%s>", GetHorseCoat(target) or "?", table.concat(GetHorseCoats(), "|")))
    return true
  end
  local id = tonumber(GetEntityData(target, "db_id"))
  local p = players[pid]
  if not id and db and p and p.logged and target == ownHorse(pid) then   -- their first horse: its row is still being made
    say(pid, "Your horse is not in the books yet - try again in a moment.")
    return true
  end
  if not SetHorseCoat(target, coat) then
    SendClientMessage(pid, COLOR_RED, "The coats: " .. table.concat(GetHorseCoats(), ", "))
    return true
  end
  coat = GetHorseCoat(target)
  if id and db then   -- a horse with a row: the coat is kept for the next time it is brought
    db:Execute("UPDATE player_horses SET coat = @c WHERE id = @h", { c = coat, h = id }, function(_, _, err)
      if err then Log("BasicRP: the horse's coat was not saved: " .. tostring(err)) end
    end)
    local owner = players[GetHorseOwner(target) or -1]
    if owner and owner.savedHorse and owner.savedHorse.dbId == id then owner.savedHorse.coat = coat end
  end
  say(pid, fmt("The horse is %s now.", coat))
  return true
end

-- at the login: the saved progression put back with SetPlayerProgress. One read - the stats and skills as rows of their
-- kind, the perks as rows of the kind "perk" - and the nourishment and the energy from the players row (`row`). Every stat and
-- skill comes back with its level, XP and unspent perk points; the main level ("mainlevel") only with its points, put back
-- by SetPlayerPerkPoints - its level is the game's own to work out, never ordered. A character with nothing saved is left as
-- the game made it, and saved from its first change. When the read fails nothing is saved over the character this session.
function loadProgress(pid, p, row)
  db:Query("SELECT kind, name, level, xp, points FROM player_progress WHERE player_id = @p " ..
    "UNION ALL SELECT 'perk', perk, 0, 0, 0 FROM player_perks WHERE player_id = @q", { p = p.id, q = p.id }, function(rows, err)
      if err then Log("BasicRP: the progress of " .. p.name .. " could not be read: " .. err) return end
      if players[pid] ~= p then return end
      local progress = { stats = {}, skills = {}, perks = {}, nourishment = row.nourishment, energy = row.energy }
      local keys, perks, levels, mainPoints = {}, {}, 0, nil
      for _, r in ipairs(rows) do
        if r.kind == "perk" then
          if DISCOVERY.explorer == "strip" and r.name:lower() == EXPLORER_PERK then
            p.explorerSaved = true   -- left out of what is put back; its row stays (saveProgress keeps it)
          else
            progress.perks[#progress.perks + 1] = r.name
          end
          perks[r.name:lower()] = true
        elseif r.kind == "stat" or r.kind == "skill" then
          local level, xp, points = tonumber(r.level) or 0, tonumber(r.xp) or 0, tonumber(r.points) or 0
          if r.kind == "stat" and r.name == "mainlevel" then
            mainPoints = points   -- the pool only: the level follows from the stats and skills
          else
            progress[r.kind == "stat" and "stats" or "skills"][r.name] = { level = level, xp = xp, points = points }
          end
          keys[r.kind .. ":" .. r.name] = fmt("%d:%.1f:%d", level, xp, points)
          levels = levels + 1
        end
      end
      p.progressRows, p.perkSet = keys, perks   -- what the tables hold now: a save writes what differs
      p.vitalsKey = row.nourishment and row.energy and fmt("%.1f:%.1f", row.nourishment, row.energy) or nil
      if levels == 0 then
        p.progressFresh = true   -- nothing saved (a new account, or one from before the progression was kept): the game's own start is the first save
        return
      end
      SetPlayerProgress(pid, progress)
      if mainPoints then SetPlayerPerkPoints(pid, "mainlevel", mainPoints) end
      p.progressReady = true
      Log(fmt("BasicRP: %s's progress restored (%d stats and skills, %d perks)", GetPlayerName(pid), levels, #progress.perks))
    end)
end

-- true when the character's progression may be saved: its saved one was put back, or it had none and the game has reported its own
local function progressReady(pid, p)
  if p.progressReady then return true end
  if not p.progressFresh then return false end
  local now = GetPlayerProgress(pid)
  if now and next(now.skills or {}) then p.progressReady = true end
  return p.progressReady == true
end

-- The progression into one transaction, only what differs from the last save: a stat or skill row whose level, XP or perk
-- points changed (the main level's row too), the perks added or taken away, the nourishment and the energy. The values are read
-- now, on the tick; the writes run later.
function saveProgress(pid)
  local p = players[pid]
  if not (db and p and p.logged and p.id) or p.staged or not progressReady(pid, p) then return end
  local now = GetPlayerProgress(pid)
  local stats, skills = now and now.stats or {}, now and now.skills or {}
  if next(stats) == nil and next(skills) == nil then return end   -- the game has reported nothing yet
  local batch, keys = {}, p.progressRows
  for _, group in ipairs({ { "stat", stats }, { "skill", skills } }) do
    for name, v in pairs(group[2]) do
      local points = v.points or 0
      local key = fmt("%d:%.1f:%d", v.level, v.xp or 0, points)
      local id = group[1] .. ":" .. name
      if keys[id] ~= key then
        keys[id] = key
        batch[#batch + 1] = { "DELETE FROM player_progress WHERE player_id = @id AND kind = @k AND name = @n", { id = p.id, k = group[1], n = name } }
        batch[#batch + 1] = { "INSERT INTO player_progress (player_id, kind, name, level, xp, points) VALUES (@id, @k, @n, @l, @x, @pt)",
          { id = p.id, k = group[1], n = name, l = math.floor(v.level), x = v.xp or 0, pt = math.floor(points) } }
      end
    end
  end
  local perks = {}
  for _, guid in ipairs(now.perks or {}) do perks[guid:lower()] = true end
  if p.explorerSaved and DISCOVERY.explorer == "strip" then perks[EXPLORER_PERK] = true end   -- left out of the restore, never taken from the character
  local was = p.perkSet
  if was == nil then   -- after a failed save: the rows written again whole
    batch[#batch + 1] = { "DELETE FROM player_perks WHERE player_id = @id", { id = p.id } }
    for guid in pairs(perks) do batch[#batch + 1] = { "INSERT INTO player_perks (player_id, perk) VALUES (@id, @g)", { id = p.id, g = guid } } end
  else
    for guid in pairs(perks) do
      if not was[guid] then batch[#batch + 1] = { "INSERT INTO player_perks (player_id, perk) VALUES (@id, @g)", { id = p.id, g = guid } } end
    end
    for guid in pairs(was) do
      if not perks[guid] then batch[#batch + 1] = { "DELETE FROM player_perks WHERE player_id = @id AND perk = @g", { id = p.id, g = guid } } end
    end
  end
  p.perkSet = perks
  if now.nourishment and now.energy then
    local key = fmt("%.1f:%.1f", now.nourishment, now.energy)
    if key ~= p.vitalsKey then
      p.vitalsKey = key
      batch[#batch + 1] = { "UPDATE players SET nourishment = @n, energy = @e WHERE id = @id", { n = now.nourishment, e = now.energy, id = p.id } }
    end
  end
  if #batch == 0 then return end
  db:Batch(batch, function(ok, err)
    if ok then return end
    Log("BasicRP: the progress of " .. p.name .. " not saved: " .. tostring(err))
    p.progressRows, p.perkSet, p.vitalsKey = {}, nil, nil   -- the next save writes it all again
  end)
end

-- the server heard of a change in the soul: a level or a perk is saved at once, the XP and the hunger with the minute's round
function OnPlayerProgressChange(pid, levels)
  local p = players[pid]
  if not (db and p and p.logged and p.id) then return end
  if p.progressFresh then p.progressReady = true end   -- nothing was saved for this character: the game's own start is their first save
  if levels then saveProgress(pid) end
end

-- ------------------------------------------------------------------ what a character found
-- The rules are the DISCOVERY table above. The server records what a player's game reports (GetPlayerDiscovery: a block per kind, the
-- data a base64 text the server keeps in a fixed, versioned format) and this mode keeps it in player_discovery - one row per player,
-- level and kind, the books under the empty level because the game keeps them once for everything - saved by the minute's round and
-- when the player leaves, only the kinds that grew (OnPlayerDiscoveryChange) and only when the text differs from the last save. At the
-- login the saved rows are put back with SetPlayerDiscovery, which adds them to what the player's game holds (the record only grows).
-- Nothing is saved before the saved rows were put back (p.discoveryReady), or - for a character with none - before the game has
-- reported its own: a record that is empty only because the game has not reported must never replace a saved one, and a read that
-- failed saves nothing that session.
local DISCOVERY_KINDS = { "places", "reading", "ui", "fog" }   -- the kinds a rule can keep
local discoveryOn = false                                  -- a rule is on and its table is there

-- whether a rule keeps this kind (a name that is no kind, "explorer" among them, is none); one test for every use of a rule, so a value
-- other than true (a 1, say) turns it on for the asking, the table, the restore and the save alike
local function kept(kind)
  for _, k in ipairs(DISCOVERY_KINDS) do
    if k == kind then return DISCOVERY[k] and true or false end
  end
  return false
end

local function discoveryKinds()
  local kinds = {}
  for _, kind in ipairs(DISCOVERY_KINDS) do
    if kept(kind) then kinds[#kinds + 1] = kind end
  end
  return kinds
end

-- whether the game has reported a whole block of a kind this mode keeps, so the record holds its own state and not an empty guess
local function gameReported(pid)
  for _, kind in ipairs(discoveryKinds()) do
    if IsPlayerDiscoveryKnown(pid, kind) then return true end
  end
  return false
end

-- the kinds of a character marked for the next save, each on its own level (the books have none): the server's record can hold what no
-- change call announced - what the game reported before the login, the union a restore made, a change still waiting for its window when
-- the player left - so the login, the goodbye and the shutdown mark them all; a row is written only when its text differs from the last save
function markDiscovery(pid)
  local p = players[pid]
  if not (discoveryOn and p) then return end
  local level = GetLevel():lower()
  p.discoveryDirty = p.discoveryDirty or {}
  for _, kind in ipairs(discoveryKinds()) do
    p.discoveryDirty[kind] = kind == "reading" and "" or level
  end
  if p.discoveryFresh and not p.discoveryReady and gameReported(pid) then p.discoveryReady = true end   -- a character with nothing saved: its game's first report
end

-- at the start, only when a rule is on: the table (no rule, no table - a default install changes nothing and needs no SQL) and the
-- kinds the players' games are asked for
function setupDiscovery()
  local kinds = discoveryKinds()
  if #kinds == 0 then return end
  if not execInit("CREATE TABLE IF NOT EXISTS player_discovery (player_id INT NOT NULL, level VARCHAR(32) NOT NULL, kind VARCHAR(12) NOT NULL, " ..
      "format SMALLINT NOT NULL, data TEXT NOT NULL, updated VARCHAR(32), PRIMARY KEY (player_id, level, kind), " ..
      "FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_discovery table") then
    Log("BasicRP: what characters find is not kept - the player_discovery table could not be made")
    return
  end
  discoveryOn = true
  SetDiscoveryTracking(kinds)
  Log("BasicRP: keeping what characters find (" .. table.concat(kinds, ", ") .. ")")
end

-- at the login, after the progression: what the character found, put back. One read of the rows of this level and of the books; a
-- character with none is left as the game made it and saved from its first report. A read that fails, or a row the server cannot
-- read, saves nothing over the character this session.
function loadDiscovery(pid, p)
  if not discoveryOn then return end
  local level = GetLevel():lower()
  db:Query("SELECT kind, level, format, data, updated FROM player_discovery WHERE player_id = @p AND (level = @l OR level = '')",
    { p = p.id, l = level }, function(rows, err)
      if err then Log("BasicRP: what " .. p.name .. " found could not be read: " .. err) return end
      if players[pid] ~= p then return end
      local record, saved, count = { level = level }, {}, 0
      for _, r in ipairs(rows) do
        if kept(r.kind) and r.data and r.data ~= "" then
          record[r.kind] = { format = tonumber(r.format) or 1, data = r.data }
          saved[r.kind .. "|" .. r.level] = r.data   -- what the table holds now: a save writes what differs
          count = count + 1
        end
      end
      p.discoveryRows = saved
      if count == 0 then
        p.discoveryFresh = true   -- nothing saved: the game's own first report is the first save
        if gameReported(pid) then   -- the game reported before the read answered: no change call of ours heard it (the login was not done)
          p.discoveryReady = true
          markDiscovery(pid)
        end
        return
      end
      if SetPlayerDiscovery(pid, record) then
        p.discoveryReady = true
        markDiscovery(pid)   -- the record is now the saved rows united with what the game held: a save writes whatever differs
        Log(fmt("BasicRP: %s's places and books restored (%d kinds)", GetPlayerName(pid), count))
      else
        Log("BasicRP: part of what " .. p.name .. " found could not be put back - nothing of it is saved this session")
      end
    end)
end

-- the server heard of more: the kind is marked and written by the minute's round and when the player leaves
function OnPlayerDiscoveryChange(pid, kind, level)
  local p = players[pid]
  if not (discoveryOn and db and p and p.logged and p.id) or not kept(kind) then return end
  if p.discoveryFresh then p.discoveryReady = true end   -- nothing was saved for this character: the game's first report is their first save
  p.discoveryDirty = p.discoveryDirty or {}
  p.discoveryDirty[kind] = level
end

function OnPlayerDiscoveryRestore(pid, kind, ok)
  if not ok then Log("BasicRP: " .. (GetPlayerName(pid) or "a player") .. "'s game could not put back the " .. kind) end
end

-- the kinds marked dirty into one transaction, a row only when its text differs from the last save. The values are read now, on
-- the tick; the writes run later.
function saveDiscovery(pid)
  local p = players[pid]
  if not (discoveryOn and db and p and p.logged and p.id) or p.staged or not p.discoveryReady or not p.discoveryDirty then return end
  local dirty = p.discoveryDirty
  p.discoveryDirty = nil
  local record = GetPlayerDiscovery(pid)
  if not record then return end
  local batch, rows = {}, p.discoveryRows or {}
  p.discoveryRows = rows
  for kind, level in pairs(dirty) do
    local block, key = record[kind], kind .. "|" .. level
    if block and block.data ~= "" and rows[key] ~= block.data then
      rows[key] = block.data
      batch[#batch + 1] = { "DELETE FROM player_discovery WHERE player_id = @id AND level = @l AND kind = @k", { id = p.id, l = level, k = kind } }
      batch[#batch + 1] = { "INSERT INTO player_discovery (player_id, level, kind, format, data, updated) VALUES (@id, @l, @k, @f, @d, @u)",
        { id = p.id, l = level, k = kind, f = block.format, d = block.data, u = os.date("!%Y-%m-%dT%H:%M:%SZ", block.updated) } }
    end
  end
  if #batch == 0 then return end
  db:Batch(batch, function(ok, err)
    if ok then return end
    Log("BasicRP: what " .. p.name .. " found was not saved: " .. tostring(err))
    p.discoveryRows = {}   -- the next save writes it all again
    p.discoveryDirty = p.discoveryDirty or {}
    for kind, level in pairs(dirty) do p.discoveryDirty[kind] = level end
  end)
end

-- ------------------------------------------------------------------ the quests a character holds
-- The rules are the QUESTS table above. player_quests holds one row per character and quest key: the quest's state ("active", "done",
-- "failed") and its objectives' states in order ("done,active,hidden"). The server forgets a player's quests when they leave and a
-- quest's id lasts one server run, so the rows go by key: at the login every row whose key a quest has this run is put back with
-- SetPlayerQuest (silent); a row whose quest is not made this run stays in the table for the day it is again. A save - the minute's
-- round, the goodbye, the shutdown - writes only the quests that changed since the last save, and deletes the row of a keyed quest the
-- character no longer holds. Nothing is saved before the rows were read (p.questsReady): a read that failed saves nothing that session.
local questsOn = false   -- QUESTS.keep is on and the table is there

-- at the start, only when QUESTS.keep: the table (no rule, no table)
function setupQuests()
  if not QUESTS.keep then return end
  if not execInit("CREATE TABLE IF NOT EXISTS player_quests (player_id INT NOT NULL, quest_key VARCHAR(64) NOT NULL, " ..
      "state VARCHAR(8) NOT NULL, objectives VARCHAR(160) NOT NULL, PRIMARY KEY (player_id, quest_key), " ..
      "FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE)", "the player_quests table") then
    Log("BasicRP: the characters' quests are not kept - the player_quests table could not be made")
    return
  end
  questsOn = true
  Log("BasicRP: keeping the characters' quests (the ones with a key)")
end

-- a keyed quest as its row stores it: "state|objectives"
local function questRow(q) return q.state .. "|" .. table.concat(q.objectives, ",") end

-- at the login, after the progression: the character's quests back in their journal, silently
function loadQuests(pid, p)
  if not questsOn then return end
  db:Query("SELECT quest_key, state, objectives FROM player_quests WHERE player_id = @p", { p = p.id }, function(rows, err)
    if err then Log("BasicRP: the quests of " .. p.name .. " could not be read: " .. err) return end
    if players[pid] ~= p then return end
    local saved, restored, waiting = {}, 0, 0
    for _, r in ipairs(rows) do
      saved[r.quest_key] = r.state .. "|" .. (r.objectives or "")
      if GetQuestByKey(r.quest_key) then
        local objectives = {}
        for s in string.gmatch(r.objectives or "", "[^,]+") do objectives[#objectives + 1] = s end
        local ok, why = SetPlayerQuest(pid, r.quest_key, r.state, objectives)
        if ok then restored = restored + 1 else Log(fmt("BasicRP: %s's quest %s was not put back: %s", p.name, r.quest_key, tostring(why))) end
      else
        waiting = waiting + 1   -- no quest has this key this run: the row waits for it
      end
    end
    p.questRows, p.questsReady = saved, true
    if #rows > 0 then
      Log(fmt("BasicRP: %s's quests restored (%d%s)", GetPlayerName(pid), restored,
        waiting > 0 and fmt(", %d kept for quests not made this run", waiting) or ""))
    end
  end)
end

-- what changed since the last save, in one transaction. The values are read now, on the tick; the writes run later.
function saveQuests(pid)
  local p = players[pid]
  if not (questsOn and db and p and p.logged and p.id) or p.staged or not p.questsReady then return end
  local rows, held, batch = p.questRows or {}, {}, {}
  for _, q in ipairs(GetPlayerQuests(pid)) do
    if q.key then
      local row = questRow(q)
      held[q.key] = true
      if rows[q.key] ~= row then
        batch[#batch + 1] = { "DELETE FROM player_quests WHERE player_id = @id AND quest_key = @k", { id = p.id, k = q.key } }
        batch[#batch + 1] = { "INSERT INTO player_quests (player_id, quest_key, state, objectives) VALUES (@id, @k, @s, @o)",
          { id = p.id, k = q.key, s = q.state, o = table.concat(q.objectives, ",") } }
        rows[q.key] = row
      end
    end
  end
  for key in pairs(rows) do
    if not held[key] and GetQuestByKey(key) then   -- the mode took it away (a quest not made this run keeps its row)
      batch[#batch + 1] = { "DELETE FROM player_quests WHERE player_id = @id AND quest_key = @k", { id = p.id, k = key } }
      rows[key] = nil
    end
  end
  p.questRows = rows
  if #batch == 0 then return end
  db:Batch(batch, function(ok, err)
    if ok then return end
    Log("BasicRP: the quests of " .. p.name .. " were not saved: " .. tostring(err))
    p.questRows = {}   -- the next save writes them all again
  end)
end

-- ------------------------------------------------------------------ the place a player left
-- The values are read now, on the tick; the writes run later on another thread.
function savePlace(pid)
  local p = players[pid]
  -- not while a new character is made in its world of one: an older account keeps the place it had
  if not db or not p or not p.logged or not p.id or p.staged or not IsPlayerInWorld(pid) then return end
  local x, y, z = GetPlayerPos(pid)
  db:Execute("UPDATE players SET x = @x, y = @y, z = @z, yaw = @yaw, level = @l, last_seen = @t WHERE id = @id",
    { x = x, y = y, z = z, yaw = GetPlayerYaw(pid), l = GetLevel(), t = os.date("!%Y-%m-%dT%H:%M:%SZ"), id = p.id },
    function(_, _, err) if err then Log("BasicRP: the place of " .. p.name .. " was not saved: " .. err) end end)
  saveCarried(pid)   -- nothing when nothing changed since the last change was saved
  saveProgress(pid)  -- the same for the stats, skills, perks and states (the XP and the hunger are kept here, with the minute)
  saveDiscovery(pid) -- and for the places and books found
  saveQuests(pid)    -- and for the quests in the journal
end

function savePlaces()
  for pid in pairs(players) do savePlace(pid) end
end

function OnGameModeExit()
  for pid in pairs(players) do markDiscovery(pid) end   -- what the players found since their last save, announced or not
  savePlaces()   -- best effort: a shutdown may be gone before the writes land, the minute timer covers the rest
end
