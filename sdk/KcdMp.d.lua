---@meta

-- KCD:MP (KCD Multiplayer) - the game mode API (server side), Lua 5.4.
-- Definitions for the Lua language server (LuaLS - the VS Code "Lua" extension and its kin): completion, hover
-- documentation and diagnostics while writing a script. Generated from the reference - do not edit.
-- https://docs.kcd-mp.com

-- ======== Server and timers =====================================================
-- The mode's own lifecycle, the server's facts, timers and the log. Everything a mode does happens on the simulation thread,
-- one tick at a time, thirty times a second - the callbacks run inside a tick, the timers run in the tick they fall due, and a
-- slow callback delays the tick for every player (Getting started).

---**Called by the server** - The script is loaded and the API is ready - the place to create zones, HUD texts, timers and actors.
---
---Called once when the server starts and again after every hot reload. Everything the mode
---creates - zones, HUD texts, props, actors, timers, state - is gone before it runs again, so this is where it is (re)made.
---The players are told to the mode afterwards: `OnPlayerConnect` for everyone on, then `OnPlayerSpawn` for those already in
---the world. The one place the mode's database answers synchronously (`QuerySync`, `ExecuteSync`): the
---tables a mode makes and the rules it loads before the first player.
function OnGameModeInit() end

---**Called by the server** - The server shuts down or the mode is about to be reloaded.
---
---The last callback of a mode's life; the objects the mode made are torn down by the server right after this. A write to
---the mode's database from here (`Execute`) still goes out, but on a shutdown the server may be gone before
---it lands: keep the writes that matter at the moment of the change and on the disconnect, not here.
function OnGameModeExit() end

---**Called by the server** - Every simulation tick, with the time since the last one.
---
---Thirty times a second (`[rates] tick_hz`), after the tick's network events were applied. Whatever runs here runs for every
---tick of every player's game, so keep it to a few lines; do the heavy things on a timer every
---second instead. The server log reports the slowest tick while the budget is missed.
---@param dt number seconds since the previous tick (`0.033` at 30 Hz)
function OnTick(dt) end

---Names the mode in the server log and the server browser.
---@param name string the mode's name, e.g. `"freeroam"`
function SetGameModeText(name) end

---The number of the simulation tick being processed.
---
---Counts up from the server's start, one per tick (30 a second). Handy as a cheap clock for "every n ticks" logic; for
---time in milliseconds use `GetServerTime`.
---@return number the tick
function GetServerTick() end

---The server's clock in milliseconds.
---
---Milliseconds since the server started - the clock the protocol carries. It wraps after about 49 days; compare differences,
---not absolute values, for anything long-lived.
---@return number milliseconds
function GetServerTime() end

---How many players the server holds (`[server] max_players`).
---
---Player ids run from `0` to `GetMaxPlayers() - 1`.
---@return number the slot count
function GetMaxPlayers() end

---The name of the level the server runs.
---
---`[server] level` in `server.toml`: `klaster`, `trosecko` or `kutnohorsko` (Levels).
---Every client boots the same level; the launcher asks the server which.
---@return string the level name
function GetLevel() end

---The level as a player reads it.
---
---The game's own name of the level `GetLevel` names: `Trosky` for `trosecko`, `Kuttenberg` for `kutnohorsko`,
---`Sedletz Monastery` for `klaster`. For what a player sees - a welcome line, a HUD text; keep `GetLevel` for
---comparisons and file names.
---@return string the name
function GetLevelName() end

---Writes a line to the server log, prefixed `[lua]`.
---
---Every argument is converted with `tostring` and joined with spaces, like `print` - and `print` **is** this function in a
---game mode. The line lands in the server's log (the console and the log file), never in a player's chat.
---@param ... any the values to write
function Log(...) end

---Calls a function after a delay, once or repeatedly.
---
---The function runs on the simulation thread in the tick the timer falls due - the same place a callback runs, so it may call
---anything a callback may. A repeating timer runs every `ms` milliseconds until `KillTimer`; a one-shot timer
---runs once and is gone. Timers belong to the mode: a reload discards them. The shortest interval is one tick (about 33 ms).
---@param fn function the function to call (no arguments)
---@param ms number the delay, and the interval of a repeating timer, in milliseconds
---@param repeating? boolean `true` repeats every `ms`; `false` or nothing fires once
---@return number the timer's id, for `KillTimer`
function SetTimer(fn, ms, repeating) end

---Stops a timer.
---@param id number the id `SetTimer` returned
---@return boolean `true` when there was such a timer
function KillTimer(id) end

---Reloads this mode at the end of the tick, without restarting the server.
---
---The running mode is shut down (`OnGameModeExit`), everything it made is torn down - zones, HUD texts, props, actors, state
---bags, nameplates, colors, teams, timers, `SetPlayerData`, the admins it promoted, the secret commands - and the script is
---read again from disk and initialised (`OnGameModeInit`), then told about every player again (`OnPlayerConnect`,
---`OnPlayerSpawn`). The players, their vitals, inventories, buffs, horses, drops, doors and containers stay as they are;
---everyone reads `the game mode was reloaded: <name>`. A script that fails to load leaves the built-in freeroam in charge
---until the next reload; a missing file refuses the reload. `/reload` (admins) and `[gamemode] watch = true` do the same.
---@param reason? string a word for the log (`"the script asked"` without one)
function ReloadGameMode(reason) end

-- ======== Players ===============================================================
-- A player is a `pid` from `0` to `GetMaxPlayers() - 1`, given at the handshake and **reused after a disconnect**: keep the
-- pid while a player is on, and check `IsPlayerConnected` before trusting a pid kept across ticks. Readers return `nil` for a
-- pid that is not connected; setters return `false`. Positions are metres, yaw is degrees (`0` = facing +Y, counter-clockwise);
-- a mounted player's position and velocity are the horse's.

---**Called by the server** - A player crouched, stood up, got into a saddle or sat down in a cart.
---
---`stance` is the new one, `previous` the one before: `STANCE_STANDING`, `STANCE_CROUCHING`, `STANCE_MOUNTED` or
---`STANCE_SEATED`. A crouch comes once it has held for a quarter of a second, so a quick dip does not call it.
---`GetPlayerStance` reads the stance at any time.
---@param pid number the player
---@param stance number the new stance
---@param previous number the stance before
function OnPlayerStanceChange(pid, stance, previous) end

---**Called by the server** - A player closed or opened their helmet's visor.
---
---`down` is `true` when the visor went down, `false` when it came up. A player starts with it up: one who spawns with the
---visor already down calls it once with `true`, one with it up does not call it. `IsPlayerVisorDown` reads it at any
---time.
---@param pid number the player
---@param down boolean `true` = the visor is down now, `false` = up
function OnPlayerVisorChange(pid, down) end

---**Called by the server** - The handshake is done and the client is loading the level.
---
---The player has a name and an address and no position yet; they are not in the world until `OnPlayerSpawn`. The server
---remembers nothing about them from earlier visits: a mode with a database looks the name up here (or the
---player's id). Names are not unique - two players may join under one; a mode whose accounts are names turns
---the second one away here with `Kick`. Also
---called for everyone on the server after a reload - the place to make the mode's admins again
---(`SetPlayerAdmin`).
---@param pid number the player
function OnPlayerConnect(pid) end

---**Called by the server** - The client's level is ready - decide where the player spawns, or hold them.
---
---Set the spawn point with `SetSpawnInfo` and return `true` (or nothing): the player is spawned there - or at the server's
---default point without one - and `OnPlayerSpawn` follows. Return `false` to **hold** the player: their screen says
---"waiting for the spawn" until the mode calls `SpawnPlayer` - a lobby, a team pick, a class menu. Called once per level
---load, not on respawns.
---
---Return value: `true` or nothing spawns the player now; `false` holds them until `SpawnPlayer`
---@param pid number the player
function OnPlayerRequestSpawn(pid) end

---**Called by the server** - The player stands in the world and the others see them.
---
---After the first spawn, every respawn after a death, and every `SpawnPlayer`. Vitals are full, the position is the
---spawn point, `IsPlayerInWorld` is `true`. Show the player their HUD texts here - a late joiner gets nothing shown before.
---@param pid number the player
function OnPlayerSpawn(pid) end

---**Called by the server** - The player is gone.
---
---`reason` is `"disconnected"` (they left), `"timed out"` (nothing heard for a while) or `"kicked: <reason>"` with the text
---given to `Kick` or `Ban`. Their pid may be given to the next player who joins; their `SetPlayerData` goes with them once
---this returns. The server keeps nothing of a player: this is the moment to save what the mode keeps. A horse they controlled stays in the world (a nearby player takes it over); their dog leaves
---with them; every fight of theirs ends. The server announces no kick or ban to the other players: a mode that wants one
---says it here, as the example does.
---@param pid number the player
---@param reason string why, as above
function OnPlayerDisconnect(pid, reason) end

---**Called by the server** - The player pressed the use key on another player whose prompt they see.
---
---Fires when a player within 3.5 m, facing `target`, presses the use key while the prompt over
---`target` shows on their screen (everyone's, or their own from `SetPlayerPromptFor`) - a hidden prompt counts too, so a
---mode can pick the action itself when the key is pressed. What the prompt offered - a talk, a search, a trade, an arrest - is
---the mode's to do here. The game's own use key on a player goes first: while `target`
---lies knocked out or is carried (the carry), and while the player crouches (the pickpocket), no prompt shows and this
---does not fire.
---@param pid number the player who pressed the key
---@param target number the player it was pressed on
function OnPlayerInteractPlayer(pid, target) end

---Everyone who passed the handshake, in join order.
---@return table a list of pids, `{}` on an empty server
function GetPlayers() end

---The players in the world within a radius of a point, nearest first.
---
---A role-play mode's "who hears this": every spawned player within `radius` metres of `x, y, z`, the nearest first. With
---`world` only the players of that virtual world count; without it, every world. The point may be
---a player's own position - they are in the list then.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@param world? number a virtual world; `nil` = any
---@return table a list of pids, nearest first
function GetPlayersInRange(x, y, z, radius, world) end

---How many players are connected.
---@return number
function GetPlayerCount() end

---Calls a function for every connected player, in join order.
---
---The loop of `GetPlayers` in one call. The list is taken before the first call, so the function may kick, hold or spawn
---players as it goes; a player who left meanwhile is skipped. With `inWorld` `true` only the players standing in the world
---are visited - the ones still loading or held by `OnPlayerRequestSpawn` are left out (`IsPlayerInWorld`). The function
---returning `false` stops the loop.
---@param fn function `function(pid) end`; return `false` to stop
---@param inWorld? boolean `true` = the players in the world alone (`false`)
---@return number how many players the function saw
function ForEachPlayer(fn, inWorld) end

---The player's name, as they joined.
---
---Names are not unique: two players may join under one name, and their pids tell them apart (a mode that wants one player
---per name turns the second away in `OnPlayerConnect`). A name is 1-24 characters: Latin letters (the accented
---ones too) or Cyrillic letters - one alphabet per name, the first letter's, so a name cannot mix look-alike letters of
---both - digits, spaces and `_-.[]()`; anything else is left out when the player joins. The server takes a name from whoever types it and proves
---nothing: a mode that wants a name to belong to someone builds accounts on its database. `nil` when no
---player has the pid.
---@param pid number the player
---@return string|nil
function GetPlayerName(pid) end

---The player's id on this server - the same at every join from their game, theirs alone.
---
---32 lowercase hex digits, the same every time the player joins this server from the same game install, whatever name they
---type. Their game makes it from a secret only that install holds, so another player cannot claim it, and the ids one player has
---on two servers have nothing in common. It is there from `OnPlayerConnect` on - a key for the mode's own records (characters,
---ranks, bans) where it would otherwise ask a password. `""` when their game sent none: a join without the launcher's look at the
---server first (a direct join, an older launcher). A new Windows or a wiped app-data folder gives the player a new id; a copy of
---the server's data folder keeps the ids (the server keeps what they are made from in its database).
---@param pid number the player
---@return string 32 hex digits; `""` when none
function GetPlayerUid(pid) end

---The player online with this id.
---@param uid string an id of `GetPlayerUid`
---@return number|nil the pid; `nil` when nobody online has it
function GetPlayerByUid(uid) end

---The player's Steam ID, as their game reports it.
---
---The SteamID64 (`"76561198..."`, a string: the number is too long for a Lua number) of the Steam account their game runs
---under - a name to show, a profile to link, a list to check. **Their game's word, not proven**: a modified game can send anyone's,
---so it is no password (`GetPlayerUid` is the id a player cannot fake). `""` when their game is not on Steam (the Microsoft
---Store's) or the player keeps it to themselves.
---@param pid number the player
---@return string the SteamID64; `""` when none
function GetPlayerSteamId(pid) end

---The player's PC on this server - for bans a new name, address or reinstall does not get around.
---
---Four parts of 16 hex digits joined by dashes, always in this order: `system-board-disk-machine` - the PC's system id, its
---main board's serial, the serial of the disk Windows runs from, and Windows' own install id. A part the PC has no real value
---for is `0000000000000000`. The same PC gives the same parts at every join to this server, whatever name the player types,
---whatever address they come from, after a reinstall of the game. Unlike `GetPlayerUid` it survives a wiped app-data folder,
---and a new Windows changes only the last part.
---
---Every part is made with this server's own key, so the parts of one PC on two servers have nothing in common, and the PC's
---serials themselves never reach the server. A player who swaps their disk changes one part - so compare with
---`CompareHwid` and treat **two or more shared parts** as the same PC, rather than comparing the whole string.
---
---It is there from `OnPlayerConnect` on. `""` when their game sent none (a join without the launcher, an older game) - a
---strict server turns such players away. **Their game's word**: a modified game can send other parts, so this makes ban
---evasion hard, not impossible.
---@param pid number the player
---@return string `system-board-disk-machine`, 67 characters; `""` when none
function GetPlayerHwid(pid) end

---The parts of the player's PC by name - for a database with a column per part.
---
---The parts of `GetPlayerHwid` in a table: `system`, `board`, `disk` and `machine`, each 16 hex digits. A part the PC has
---no value for is left out (`nil`). With a column per part a ban list is searched by the database itself
---(`WHERE system = @s OR disk = @d ...`) instead of a loop over every ban.
---@param pid number the player
---@return table|nil `{ system = ..., board = ..., disk = ..., machine = ... }` (the parts the PC has); `nil` when their game sent none
function GetPlayerHardware(pid) end

---How many parts two PCs share - 0 to 4.
---
---Counts the parts of two hwids that both have and that are equal (a part of zeros never counts). 4 is the
---same PC unchanged; 2 or 3 the same PC with a part changed (a new disk, a new Windows); 1 can be chance (two PCs from one
---shop image share Windows' id). Case and spaces around the strings do not matter; a malformed or empty string shares
---nothing.
---@param a string an hwid
---@param b string another hwid
---@return number the shared parts, `0`-`4`
function CompareHwid(a, b) end

---The players online on one PC - a banned PC's other names.
---
---Every player online whose PC shares at least `minMatches` parts with `hwid` (see `CompareHwid`), in
---join order. Ban a player and their other names on the server go too; or warn an admin when two players play from one PC.
---@param hwid string an hwid
---@param minMatches? number the parts that must be shared, `1`-`4`; `2` when left out
---@return table a list of pids; empty for a malformed hwid
function GetPlayersByHwid(hwid, minMatches) end

---The player a command names - a pid, a name or a fragment of one - or `nil` and why.
---
---The reverse of `GetPlayerName`, for commands that take a player: `"2"` or `2` is the pid 2 (returned when that
---player is connected); a name is matched case-insensitively, in any alphabet - the exact name when one player has it, else a
---fragment (`"hen"` for Henry) when exactly one connected name contains it. `nil` when nobody matches or two do - names are not
---unique, so two players called Henry make "Henry" name nobody and the reason asks for the pid - and a command never guesses
---between two. The second value is the reason in words ("no player called ...", "more than one player is called ... - use the
---player's id"), ready to send back. `sscanf`'s `u` letter is this function.
---@param name string|number a pid, a name, or a fragment of a name
function GetPlayerId(name) end

---Whether a pid belongs to a connected player.
---
---`true` from the handshake to the disconnect - the player may still be loading the level. For "standing in the world" use
---`IsPlayerInWorld`.
---@param pid number the player
---@return boolean
function IsPlayerConnected(pid) end

---Whether the player is spawned and replicated.
---
---`false` while the level loads, while a spawn is held, after a despawn. Positions and vitals mean something only while this
---is `true`; a dead player waiting for the respawn is still in the world (`IsPlayerDead`).
---@param pid number the player
---@return boolean
function IsPlayerInWorld(pid) end

---The player's round trip to the server in milliseconds.
---@param pid number the player
---@return number milliseconds; `-1` when not connected
function GetPlayerPing(pid) end

---The mods the player's game loaded - its Steam Workshop items and the folders of its Mods folder.
---
---Read by the player's game from its own record of the mods it enabled, with the id, name and version of each mod's
---`mod.manifest`. `[mods]` in server.toml already judged them when the player joined (any, an allow list or none); a
---mode may refuse others on its own terms. The list is the client's word - a modified game can leave a mod out - so
---the rules that matter are the server's own checks.
---@param pid number the player
---@return table a list of `{id=, name=, version=, kb=}` (`kb` = the size of the mod's files); empty for none or when not connected
function GetPlayerMods(pid) end

---The player's address.
---@param pid number the player
---@return string `"a.b.c.d"`; `""` when not connected
function GetPlayerIP(pid) end

---The player's position of record.
---
---Metres in the level's world space, from the client's reports (thirty a second); a mounted player's position is the horse's.
---A report that would move a player faster than `[validation] max_speed` allows is refused and the client pulled back, so the
---record is the server's own opinion of where they are.
---@param pid number the player
---@return number x three numbers `x, y, z`; `nil` when not connected
---@return number y
---@return number z
function GetPlayerPos(pid) end

---The direction the player faces, in degrees.
---
---The game's convention: `0` faces +Y, `90` faces -X, `180` faces -Y, `270` faces +X - counter-clockwise seen from above.
---@param pid number the player
---@return number degrees `0`..`360`; `0` when not connected
function GetPlayerYaw(pid) end

---The player's velocity in metres per second.
---@param pid number the player
---@return number vx three numbers `vx, vy, vz`; `nil` when not connected
---@return number vy
---@return number vz
function GetPlayerVelocity(pid) end

---Moves the player's game to a point - a teleport.
---
---The client puts the player there on the next frame and the server's record follows; reports from before the move are
---dropped, so honest clients never trip the speed check. `z` below `0` puts the player on the terrain at `x, y`. A mounted
---player is moved with the horse. Without `yaw` the player keeps their heading.
---@param pid number the player
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the terrain
---@param yaw? number degrees to face
---@return boolean `false` when not connected
function SetPlayerPos(pid, x, y, z, yaw) end

---Lets the player fly - or lands them.
---
---Flying, the player moves along where they look with their movement keys - **Space** up, **C** down, **Shift** three
---times faster - with no gravity and through walls, and the server's movement checks (the speed cap, the height over the
---terrain, the walls) and fall damage leave them alone; what they see around them follows them, so a flying admin shows a
---crowd from above. Landing puts them on the ground under where they are, and the checks and falls start again a few
---seconds later. A death, a mount, a cart seat and a respawn land them too. The server has no command for it: a mode
---gives its admins one (the example).
---@param pid number the player
---@param flying boolean `true` to fly, `false` to land
---@param speed? number the pace in m/s, 1 to 50 (Shift triples it); 12 when left out
---@return boolean `true`, or `false` and the reason as the player reads it (`"Get off the horse first."`, `"You are dead."` ...)
function SetPlayerFlying(pid, flying, speed) end

---Whether the player flies (`SetPlayerFlying`).
---@param pid number the player
---@return boolean `false` also when not connected
function IsPlayerFlying(pid) end

---Gives a player the third-person view - or keeps them in first person.
---
---The third-person view is the game's own camera behind the player, so nobody needs a camera mod for it. `"off"` keeps the
---player in first person (one looking from behind goes back to first person at once). `"allow"` lets them switch with
---their third-person key - **F3** unless they changed it in the launcher's options - and the view they had is kept.
---`"force"` puts them in third person and the key does nothing. `true` is `"allow"`, `false` and `nil` are `"off"`, and
---the words may be written in any case.
---
---Two more rules say where the view gives way to first person. With `inFights` set to `false` the player's game goes to
---first person while they fight with a sword, an axe or fists, and with `whenAiming` set to `false` while a bow, a
---crossbow or a gun is drawn; each goes back to third person when the fight or the aiming ends. While a bow, a crossbow
---or a gun is in the player's hands in third person an aiming dot shows at the centre of the screen; `crosshair` set to
---`false` keeps it off (first person always keeps the game's own look, without a dot). Left out, or `nil`, all three are
---`true`: third person stays on there and the dot shows. Each call sets the whole rule, so a call that changes only the
---mode passes the three again.
---
---It lasts until you change it or the player leaves; every visit starts with `"off"`, third person kept on in fights and
---when aiming and the dot on, so a mode that wants the view sets it when the player connects (`OnPlayerConnect`). The game's own
---camera still takes over in a dialogue, in a menu and in a minigame; riding a horse keeps the view, and so do fighting
---and aiming unless a rule above says first person (while aiming in third person the camera moves over the player's
---shoulder and the shot flies to the crosshair). It is a setting of KCD:MP's own camera: a camera mod a player runs
---themselves is not stopped by it.
---
---The shipped game modes keep this rule in a `CAMERA` table at the top of their script and set it in `OnPlayerConnect`, as the
---example below does: freeroam and BasicRP use `"allow"`, the duel arena `"off"`. Change the table to change the view.
---@param pid number the player
---@param mode string|boolean|nil `"off"`, `"allow"` or `"force"`; `true` for `"allow"`, `false` or `nil` for `"off"`
---@param inFights? boolean|nil `false` keeps the player in first person while they fight with a sword, an axe or fists; `true` or `nil` (the default) keeps third person on
---@param whenAiming? boolean|nil `false` keeps the player in first person while a bow, a crossbow or a gun is drawn; `true` or `nil` (the default) keeps third person on
---@param crosshair? boolean|nil `false` keeps the aiming dot off in third person; `true` or `nil` (the default) shows it while a bow, a crossbow or a gun is in the hands
---@return boolean `true`, or `false` and the reason (`"Not connected."`, or the three words when `mode` is none of them)
function SetPlayerThirdPerson(pid, mode, inFights, whenAiming, crosshair) end

---The third-person view the mode gave a player (`SetPlayerThirdPerson`).
---
---`"off"` until a mode changed it, with third person kept on in fights and when aiming and the aiming dot on. With
---`"allow"`, which view the player looks from at the moment is their own choice and the server does not know it.
---@param pid number the player
---@return string mode four values `mode, inFights, whenAiming, crosshair`: `"off"`, `"allow"` or `"force"`, then `false` where the player is held in first person (a fight, aiming) and `true` where third person stays on, then whether the aiming dot shows in third person; a single `nil` when not connected
---@return boolean inFights
---@return boolean whenAiming
---@return boolean crosshair
function GetPlayerThirdPerson(pid) end

---Where and as what the player's next spawn happens.
---
---Sets the point and the outfit for the next `SpawnPlayer` or the spawn that follows `OnPlayerRequestSpawn`. The
---presets are GUIDs from the game's tables - clothing presets and
---weapon presets; `""` or `nil` keeps the server's `[spawn]` defaults. `appearance` is the soul
---whose face and body the **other** players see on this player's body - a soul of the `NPC` or `NPC_Female` archetype from
---the souls by name, id or GUID; `""` picks one from the server's `[spawn] appearances` pool by the
---player's name, so a player looks the same every visit. A look chosen part by part - the face, the hair, the beard, the
---skin - is `SetPlayerLook`'s: its parts replace the soul's on every screen. The point is remembered until the next
---`SetSpawnInfo`; respawns after a death use it too. The bag is emptied and the outfit put on at a player's first spawn of a
---visit and at any spawn whose two presets differ from the spawn before (the purse the server holds for them stays); a
---respawn with the same presets keeps what they carry, so the outfit is the mode's to change by presets or by
---`SetPlayerInventory`.
---@param pid number the player
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the terrain
---@param yaw number degrees to face (`0` without)
---@param clothingPreset? string a clothing preset GUID; `""` = the server default
---@param weaponPreset? string a weapon preset GUID; `""` = the server default
---@param appearance? string the soul whose face the others see (name, id or GUID); `""` = the server's pool
---@return boolean `false` when not connected
function SetSpawnInfo(pid, x, y, z, yaw, clothingPreset, weaponPreset, appearance) end

---Spawns - or respawns - the player at their SetSpawnInfo point.
---
---Puts a player whose level is loaded into the world at the point `SetSpawnInfo` set (the server's default without one), or
---moves and re-outfits one who already is; `OnPlayerSpawn` follows. The way to release a player held by
---`OnPlayerRequestSpawn` returning `false`, and to respawn the dead when `[combat] respawn_seconds` is `0`. A spawn heals:
---full health and stamina, injuries and the server's buffs gone.
---@param pid number the player
---@return boolean `false` when not connected
function SpawnPlayer(pid) end

---The server's spawn point from server.toml.
---@return number x the `[spawn]` section's point as `x, y, z, yaw`
---@return number y
---@return number z
---@return number yaw
function GetDefaultSpawn() end

---Remembers a spawn point under a tag.
---
---A plain list the server keeps for the mode - nothing else uses it. Points are grouped by `tag` (`""` without one):
---one list per team, per arena, per role.
---@param x number metres
---@param y number metres
---@param z number|nil metres; `nil` = `-1`, on the terrain
---@param yaw number degrees (`0` without)
---@param tag? string the list to add to
---@return number how many points the list holds now
function AddSpawnPoint(x, y, z, yaw, tag) end

---The spawn points of a tag.
---@param tag? string the list (`""` without)
---@return table a list of `{x=, y=, z=, yaw=}`; `{}` when empty
function GetSpawnPoints(tag) end

---One spawn point of a tag, at random.
---@param tag? string the list (`""` without)
---@return number x a point as `x, y, z, yaw`; `nil` when the list is empty
---@return number y
---@return number z
---@return number yaw
function GetRandomSpawnPoint(tag) end

---Forgets the spawn points of a tag.
---@param tag? string the list (`""` without)
function ClearSpawnPoints(tag) end

---Holds or releases the player's keyboard.
---
---`false` freezes the player where they stand: the keyboard does nothing on their client, the mouse still looks around,
---**Enter** still opens the chat and its scroll keys (**Page Up** / **Page Down** unless the player changed them) still
---move it. `true` gives the keyboard back. The server's own login hold uses the same lever
---for a registered name until its `/login`.
---@param pid number the player
---@param controllable boolean `false` holds, `true` releases
---@return boolean `false` when not connected
function TogglePlayerControllable(pid, controllable) end

---Puts the player's view at a point, looking at another - a cutscene, a view over a town.
---
---The player's view moves to x y z and looks at lx ly lz, gliding there from where it is over `ms` milliseconds (`0` = a cut, at
---most 60000; the glide eases in and out), with the field of view `fov` - a narrow one zooms in. Their body stays where it is,
---its head shown, and their keys still move it - hold them with `TogglePlayerControllable` for a cutscene. The view stays there
---until `ResetPlayerCamera`, through a death or a respawn; a rejoin starts with their own view. Several calls in a row make a
---camera tour: each glides on from where the last one is.
---@param pid number the player
---@param x number metres - where the camera stands
---@param y number metres
---@param z number metres
---@param lx number metres - the point it looks at
---@param ly number metres
---@param lz number metres
---@param ms? number the glide from where the view is, milliseconds (`0` = a cut)
---@param fov? number the field of view in degrees, 10-120 (`nil` = the player's own)
---@return boolean `false` when not connected, or when the point looks nowhere (it is the camera's own)
function SetPlayerCamera(pid, x, y, z, lx, ly, lz, ms, fov) end

---Gives the player their own view back.
---@param pid number the player
---@param ms? number the glide back to their eyes, milliseconds (`0` = a cut)
---@return boolean `false` when not connected
function ResetPlayerCamera(pid, ms) end

---Whether the mode's camera holds the player's view.
---@param pid number the player
---@return boolean `true` after `SetPlayerCamera` until `ResetPlayerCamera`
function IsPlayerCameraSet(pid) end

---Whether the player's keyboard is theirs right now.
---@param pid number the player
---@return boolean `false` while held
function IsPlayerControllable(pid) end

---Disconnects the player with a reason.
---
---The player's client shows the reason and leaves; `OnPlayerDisconnect` follows with `"kicked: <reason>"`. The server tells
---nobody else - not for a kick, a `Ban`, the built-in `/kick` and `/kickban` or the audit's kicks: a mode that wants the
---others to know says it, in `OnPlayerDisconnect` (its example) or right after the call. Nothing keeps them from rejoining -
---for that, `Ban`.
---@param pid number the player
---@param reason? string shown to the player (`"kicked"` without one)
---@return boolean `false` when not connected
function Kick(pid, reason) end

---The label over the player's body on every other screen.
---
---By default the label is the player's name; this replaces it - a rank, a team tag, a title. `""` puts the name back.
---At most 48 characters. The label keeps its color (`SetPlayerColor`) and hides behind walls like the name does.
---@param pid number the player
---@param text string the label; `""` = the name again
---@return boolean `false` when not connected
function SetPlayerNameplate(pid, text) end

---The label as the mode set it.
---@param pid number the player
---@return string the text; `""` when it is the name
function GetPlayerNameplate(pid) end

---What one player alone sees over another player's body - a name they were told, a rank only they know.
---
---The label over `target`'s body on `viewer`'s screen, in the place of the label everyone else sees (`SetPlayerNameplate`,
---else the player's name). `""` takes it away and `viewer` sees the label everyone sees again. At most 48 characters; the
---label keeps the target's color (`SetPlayerColor`). One text for each pair of players.
---
---It is the mode's to remember: the text goes when the target leaves (their id is the next player's to take) and with a
---reload of the mode, so a mode that keeps who knows whom sets it again when either player joins. With the name plates
---showing a player's id and only while a key is held (the `text` and `peek_key` options of `SetPlayerInterfaceOptions`) this
---is the whole of "you do not know them until they say who they are".
---@param viewer number the player whose screen shows the text
---@param target number the player the text hangs over
---@param text string the label for this viewer alone; `""` = the label everyone sees again
---@return boolean `false` when either player is not connected
function SetPlayerNameplateFor(viewer, target, text) end

---The text one player alone sees over another's body, as the mode set it.
---@param viewer number the player whose screen shows the text
---@param target number the player the text hangs over
---@return string the text; `""` when `viewer` sees the label everyone sees
function GetPlayerNameplateFor(viewer, target) end

---Hides the label over a player's body on every other screen, or shows it again.
---
---The whole plate goes: the name, the mode's label (`SetPlayerNameplate`), each player's own name for them
---(`SetPlayerNameplateFor`) and the health bar under it - a sneaking player, a disguise, a hidden admin. The label's text
---and color are kept and come back with it. The name in the Tab list stays.
---
---It is the mode's to keep: a reload of the mode shows every label again. Players on an older client still see the label.
---@param pid number the player
---@param hidden boolean `true` hides the label, `false` shows it again
---@return boolean `false` when not connected
function SetPlayerNameplateHidden(pid, hidden) end

---Whether the label over a player's body is hidden.
---@param pid number the player
---@return boolean `true` while `SetPlayerNameplateHidden` hides it; `false` when not connected
function IsPlayerNameplateHidden(pid) end

---Makes a player invisible to every other player, or seen again.
---
---Nothing of the player shows on another screen: no body, no clothes, no name plate, no horse they ride, nothing carried in
---their hands. Their voice is not heard and their party has no compass mark for them. Their own game is unchanged - they see
---and hear everyone as before, and can move, ride, chat and use commands. Server animals leave an invisible player alone, a
---carry they are part of ends, and nobody can carry them or be carried by them while they are hidden.
---
---Made for admins who watch unseen, but it is the mode's to use however it likes - nothing limits it to admins. Combine it with
---`SetPlayerFlying` for a spectator, `SetPlayerInvisibleFor` to let some players (the other admins) still see them. The
---name in the Tab list and their chat lines stay; hide those yourself if you want. A reload of the mode shows everyone again.
---@param pid number the player
---@param invisible boolean `true` hides the player, `false` shows them again
---@return boolean `false` when not connected
function SetPlayerInvisible(pid, invisible) end

---Whether a player is invisible to other players.
---@param pid number the player
---@return boolean `true` while `SetPlayerInvisible` hides them; `false` when not connected. One viewer's own rule may differ: `IsPlayerVisibleTo`
function IsPlayerInvisible(pid) end

---Hides a player from one viewer, or shows them to one viewer while they are invisible to the rest.
---
---One viewer's own rule for the player, which wins over `SetPlayerInvisible` both ways: `false` lets this viewer see an
---invisible player (the other admins), `true` hides a visible player from this viewer alone, `nil` drops the rule. What a hidden
---player hides is the same as `SetPlayerInvisible`'s - body, gear, name plate, horse, voice, compass mark.
---
---The rule is forgotten when the viewer leaves, and by a reload of the mode.
---@param pid number the player who is hidden or shown
---@param viewer number the player whose screen the rule is for
---@param invisible boolean|nil `true` hides `pid` from `viewer`, `false` shows them, `nil` follows `SetPlayerInvisible` again
---@return boolean `false` when either is not connected or both are the same player
function SetPlayerInvisibleFor(pid, viewer, invisible) end

---Whether one player sees another.
---@param pid number the player who may be hidden
---@param viewer number the player looking
---@return boolean the viewer's own rule (`SetPlayerInvisibleFor`) when there is one, else `not IsPlayerInvisible(pid)`; always `true` for a player looking at themselves, `false` when either is not connected
function IsPlayerVisibleTo(pid, viewer) end

---How a player stands - on their feet, crouching, in a saddle or in a cart seat.
---
---As their game last reported it: one of `STANCE_STANDING`, `STANCE_CROUCHING`, `STANCE_MOUNTED` and `STANCE_SEATED`.
---`OnPlayerStanceChange` follows every change.
---@param pid number the player
---@return number the stance; `STANCE_STANDING` when not connected
function GetPlayerStance(pid) end

---Whether a player is crouching.
---@param pid number the player
---@return boolean `true` while their stance is `STANCE_CROUCHING`; `false` when not connected
function IsPlayerCrouching(pid) end

---Whether a player's helmet visor is down.
---
---As their game last reported it - the game's own key that closes and opens a helmet's visor. `OnPlayerVisorChange`
---follows every change.
---@param pid number the player
---@return boolean|nil `true` while the visor is down, `false` while it is up; `nil` and `"not connected"` for a player who is not connected
---@return string
function IsPlayerVisorDown(pid) end

---A use prompt over a player - "[E] Talk" under their name, and the use key on them reaches the mode.
---
---Everyone else within 3.5 m of the player sees `[E] text` under their name, and pressing the use key on them fires
---`OnPlayerInteractPlayer`. `""` or `nil` takes it off. At most 32 characters, shown as written (a text that starts with
---`@` is a text key of the game's own, shown in the player's language). One viewer can be shown their own prompt
---over the player instead (`SetPlayerPromptFor`). The game's own use key on a player goes first: no prompt shows over a
---player who lies knocked out or is carried, or to a player who crouches (the game's pickpocket).
---
---With `hidden` set, nothing is drawn over the player's head: the use key on them still fires `OnPlayerInteractPlayer`,
---and the game's own key hint in the corner of the screen still shows `text`, as it does for a person in single player.
---Each call sets both the text and whether it is hidden.
---@param pid number the player the prompt hangs over
---@param text string|nil the word; `""` / `nil` = none
---@param hidden boolean|nil `true` = no `[E] text` line over the head, the use key still works; `false` / `nil` = shown (default)
---@return boolean `false` when not connected
function SetPlayerPrompt(pid, text, hidden) end

---The use prompt everyone sees over a player (SetPlayerPrompt).
---@param pid number the player
---@return string the word; `""` when there is none
function GetPlayerPrompt(pid) end

---Whether the use prompt everyone sees over a player is hidden (SetPlayerPrompt's `hidden`).
---@param pid number the player
---@return boolean `true` when the prompt is armed with nothing drawn over the head; `false` when shown, none or not connected
function IsPlayerPromptHidden(pid) end

---The use prompt one viewer alone sees over a player.
---
---`viewer` sees `text` over `pid` instead of everyone's prompt; `""` shows them none, `nil` gives them everyone's again.
---`OnPlayerInteractPlayer` fires for the viewer's use key while their prompt shows. Gone when either player leaves.
---`hidden` works as in `SetPlayerPrompt`: the viewer's use key is armed with nothing drawn over the player's head.
---@param viewer number the player who sees the prompt
---@param pid number the player it hangs over
---@param text string|nil the word; `""` = none for them; `nil` = everyone's again
---@param hidden boolean|nil `true` = no `[E] text` line over the head for this viewer, the use key still works
---@return boolean `false` when either is not connected, or they are one player
function SetPlayerPromptFor(viewer, pid, text, hidden) end

---The use prompt one viewer alone sees over a player (SetPlayerPromptFor).
---@param viewer number the player who sees it
---@param pid number the player it hangs over
---@return string|nil the viewer's own prompt; `nil` when they see everyone's
function GetPlayerPromptFor(viewer, pid) end

---The color of the player's label and of their name in the Tab roster.
---
---`0xRRGGBBAA`; `0` puts the default back. The alpha byte matters - `0x4080FF00` is invisible.
---@param pid number the player
---@param color number `0xRRGGBBAA`; `0` = the default
---@return boolean `false` when not connected
function SetPlayerColor(pid, color) end

---The player's color as set.
---@param pid number the player
---@return number `0xRRGGBBAA`; `0` = the default
function GetPlayerColor(pid) end

---Puts the player in a team - teammates cannot hurt each other.
---
---Any number is a team; `NO_TEAM` (`-1`) is none. **A hit between two players of one team is refused** before
---`OnPlayerDamage` and starts no fight. Nothing else is implied - no color, no label, no spawn: those are the mode's
---to set alongside. A mode that wants friendly fire back writes its rule in `OnPlayerDamage` and leaves teams unset.
---@param pid number the player
---@param team number the team; `NO_TEAM` (`-1`) = none
---@return boolean `false` when not connected
function SetPlayerTeam(pid, team) end

---The player's team.
---@param pid number the player
---@return number the team; `NO_TEAM` (`-1`) when none
function GetPlayerTeam(pid) end

---The virtual world the player is in.
---
---Players and entities are replicated to each other **within one world only**; `0` is the shared world. A registered name
---waiting for its `/login` sits in a world of its own. See Getting started and
---`SetPlayerVirtualWorld`.
---@param pid number the player
---@return number the world; `nil` when not connected
function GetPlayerVirtualWorld(pid) end

---Moves the player into another virtual world.
---
---From the next snapshot on the player sees, and is seen by, the players and entities of `world` only; the others part with
---them as if they had left and meet them again when they come back. Their mount comes along; a loose horse they controlled
---stays behind for whoever is nearest. Chat, the roster, the scoreboard, doors and containers stay global - unless
---`SetVirtualWorldOwnDoors` gave the world doors of its own: then the player sees that world's doors at once. Fights and hits
---stay inside a world. The client never learns its world - nothing changes on the player's screen but who is around.
---Instanced duels, private lobbies, a hidden staging area for the next round.
---@param pid number the player
---@param world number the world; `0` = the shared one
---@return boolean `false` when not connected
function SetPlayerVirtualWorld(pid, world) end

-- ======== Chat and commands =====================================================
-- Every chat line a player types passes through the mode before anyone sees it: a plain line through `OnPlayerText`, a `/`
-- line through `OnPlayerCommandText`. A `/` line the mode does not answer goes to the server's own
-- built-in commands (`/help`, `/pos`, `/give`, `/tp`, `/horse` ...), then to `Unknown command`; a mode
-- overrides a built-in by handling its name. `/fight` and `/peace` are the server's and are answered before the mode sees
-- them; `/mute` and `/unmute` are every player's whatever `[commands]` says, unless the mode handles them itself. The mode's own lines go out with `SendClientMessage`, `SendClientMessageInRange` and `SendClientMessageToAll`.
-- 
-- What a player types is **cleaned and rationed by the server** before the mode sees it - no invisible or direction-changing
-- characters, no stacks of accents, no flood of lines - so a mode's own filters start from a tidy line; `OnPlayerText` has
-- the details.
-- 
-- Beyond plain lines and commands, a mode can shape the chat itself:
-- 
-- - **Messages** - `SendChatMessage` and `SendChatMessageToAll` send a line made of pieces that differ in colour, weight and
--   slant (**spans**), on a channel of the mode's choice; `ClearPlayerChat` empties a player's chat.
-- - **Channels** - `RegisterChatChannel` adds a channel - Trade, Staff, a guild's - that only some players see or may write
--   into; what a player types on a channel goes to the players who see it. `UnregisterChatChannel` takes one away and
--   `RefreshChatChannels` tells the players' chats to look again after a rule of the mode changed.
-- - **Commands** - `RegisterCommand` gives a command its handler, its help line, its usage and its admin or secret mark in one
--   call; a chat that can suggest offers the command while the player types it. `AddChatSuggestion` and
--   `RemoveChatSuggestion` do the same for commands the mode still answers in `OnPlayerCommandText`. `UnregisterCommand`
--   takes one away.
-- - **Where it sits and how big it is** - the chat is a component of the interface: `SetPlayerInterfaceOptions` (one player)
--   and `SetInterfaceOptionsForAll` (everyone) move it to any corner or edge (`anchor`, `margin_x`, `margin_y`), size it
--   (`width`, `lines` from 4 to 20, `font_scale`) and set its backing; `SetPlayerInterface` hides it or hands it to a web
--   page. Change the interface has every option, with an example:
-- 
--   ```lua
--   -- the chat in the top-right corner, eight lines, for everyone
--   SetInterfaceOptionsForAll("chat", { anchor = "top-right", margin_x = 16, margin_y = 24, lines = 8 })
--   ```
-- 
-- A line's **words** are always there as plain text, so every chat can show every line; a chat that can style them - a chat
-- built as a web page - draws the spans, the channel's tab and the suggestions. The game's own chat draws each line in one
-- colour (the first span's, when it has one, otherwise the line's), puts the channel's label in front of a line
-- (`[Trade] Henry: two loaves`), has no channel picker - what a player types there is a line in the default channel - and no
-- suggestion list.
-- 
-- Every list the mode builds here - channels, registered commands, suggestions - starts empty again after a
-- reload, so a mode registers them where it is made again, in `OnGameModeInit`.

---**Called by the server** - A plain chat line - return `false` and nobody sees it.
---
---Never a `/` command (those are `OnPlayerCommandText`). Anything but `false` lets the line through to everyone
---connected, in the player's own color. Filters, team channels, a muted player, a whisper: return `false` and send the line
---on yourself with `SendClientMessage`.
---
---The server **cleans the line first**: control characters and the invisible ones (zero-width spaces, the marks that flip
---the direction of the text, tag characters) are dropped, every kind of space becomes one plain space and a run of them
---one, more than three accents or other combining marks stacked on a letter are cut, the ends are trimmed and a line over
---256 characters is cut. Emoji built with joiners, like a family or a heart, stay whole. A line that is empty after the
---cleaning never reaches the mode.
---
---It also **rations plain lines** per player before the mode is asked: a burst of five, then two lines a second, and the
---same line again within five seconds is dropped. The player is told "You are typing too fast." or "You just said that.",
---at most once every three seconds, and a dropped line never reaches `OnPlayerText` - a mode's database work or
---filter runs on the lines that count. `/` commands are not rationed.
---
---A line typed on a chat channel (`RegisterChatChannel`) arrives with the channel's name as `channel`; a line in the
---default channel has `""`. The server has already checked that the channel exists and that the player sees it and may
---write into it - a line that fails that is refused with a notice and never gets here - and the callback runs after the
---rationing above, so `channel` is a name the mode itself registered.
---
---What the callback **returns** says what becomes of the line:
---
---- `false` - nobody sees it;
---- a **text** - the line goes out with those words instead;
---- a **table** - the line goes out as that message: the shape `SendChatMessage` takes, `text` or `spans`, `channel`,
---  `color`, `template` and `params`; a table that names no channel keeps the one the player typed in, and one that names
---  another sends the line there;
---- `true` or nothing - the line goes out as typed.
---
---A rewritten line is still the player's: it goes out under their name, in their colour (or the channel's, or the table's
---`color`), to the players the channel reaches. It is held to the limits of `SendChatMessage` - 16 spans, 512
---characters - and a rewrite over them, an empty one, or one on a channel that does not exist is dropped and the server
---log says so. A table that is not a message at all (a span that is a number, a colour that is a text) is a script error:
---it is logged and counted, and the line goes out as typed - a filter that could not read its own answer does not
---swallow a player's words.
---
---Return value: `false` suppresses the line; a text replaces its words and a table replaces the whole message; anything else (or nothing) lets it through
---@param pid number who typed it
---@param text string the line, cleaned as above
---@param channel string the channel the line was typed in - `""` for the default one
function OnPlayerText(pid, text, channel) end

---**Called by the server** - A `/` command - return `true` when the mode answered it.
---
---`/tp 1 2 3` arrives as `cmd = "tp"`, `args = "1 2 3"`: the word after the slash as typed (compare it lower-cased if you want
---to be lenient) and the rest of the line, trimmed. Return `true` to say the mode answered - even when the answer was "you
---may not". Return `false` (or nothing) and the server's built-in commands get the line, then
---`Unknown command: /x`. A mode takes a built-in over by answering its name; a `/help` that prints a line and returns `false`
---is followed by the server's own list. Commands are never echoed to the chat.
---
---The line is cleaned like a chat line (`OnPlayerText` says how) before it is split, with one exception: a command the
---mode declared secret with `SetSecretCommand` - a `/login` - arrives exactly as typed, only the control characters
---dropped, so a password is never changed on the way.
---
---A command made with `RegisterCommand` is answered **before** this callback is asked: its name never reaches here, and
---it wins over a built-in of the same name. A mode may use both - the commands it registers, and the rest through this
---callback.
---
---Return value: `true` = handled; `false` or nothing = the server's built-ins, then "Unknown command"
---@param pid number who typed it
---@param cmd string the command without the slash, as typed
---@param args string everything after the command, trimmed; `""` when nothing
function OnPlayerCommandText(pid, cmd, args) end

---The arguments of a command as typed values - a player, a number, a word, the rest of the line - in one call.
---
---The name is SA-MP's on purpose: the same job, one letter per argument. `args` is the string `OnPlayerCommandText` hands
---you; `format` is one letter per argument, in order:
---
---| letter | the argument | what you get |
---|---|---|---|
---| `u` | a player: a pid or a name (or a fragment of one), as `GetPlayerId` reads it | the pid |
---| `d` | a whole number (`-3`, `50`) | a number |
---| `f` | a number (`0.5`, `12`) | a number |
---| `s` | one word - or a `"quoted string"` taken whole | a string |
---| `z` | the rest of the line, from here to the end | a string |
---
---A `?` after a letter makes that argument optional: `nil` when it is not there. Words are split on spaces; whatever
---follows the last letter is ignored. It returns the values in the format's order. When a required argument is
---missing or does not read - a number that is not one, a player nobody is called - it returns **`false` and the reason**
---(`"argument 2 (abc) is not a whole number"`, `"no player called xyz"`), ready for a usage line: check the first
---value against `false`, not against `nil`, when the first letter is optional.
---@param args string the command's arguments as `OnPlayerCommandText` gives them
---@param format string one letter per argument (`u d f s z`), a `?` after a letter for an optional one
---@return any ... the values in order, or `false, reason`
function sscanf(args, format) end

---A line in one player's chat.
---
---The line appears in the player's chat window in `color` (`0xRRGGBBAA`; the color
---constants name the usual ones). Long lines wrap; keep them to a sentence or two. A text over 16384 bytes of UTF-8 is cut
---at that size - the server log says so once after the mode loads - so a line built without a bound cannot break the
---chat.
---
---It is the one-colour, one-channel form of `SendChatMessage`, and unlike that function it **cuts** a long text where
---`SendChatMessage` refuses one over 512 characters.
---@param pid number the player
---@param color number `0xRRGGBBAA`
---@param text string the line
---@return boolean `false` when not connected
function SendClientMessage(pid, color, text) end

---The same line in everyone's chat.
---
---The same limit as `SendClientMessage`: a text over 16384 bytes of UTF-8 is cut at that size.
---@param color number `0xRRGGBBAA`
---@param text string the line
function SendClientMessageToAll(color, text) end

---The same line in the chat of everyone near a point - a role-play mode's nearby chat.
---
---Every spawned player within `radius` metres of `x, y, z` gets the line - the players `GetPlayersInRange` would list -
---and with `world` only those of that virtual world. The point may be a player's own position:
---they get the line too.
---
---The line is made **once** and sent to all of them, so a nearby chat costs the mode one call however many people stand
---around - a loop of `SendClientMessage` over `GetPlayersInRange` does the same with a call per listener, which adds
---up when a crowd talks. The same limit as `SendClientMessage`: a text over 16384 bytes of UTF-8 is cut at that size.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@param color number `0xRRGGBBAA`
---@param text string the line
---@param world? number a virtual world; `nil` = any
---@return number how many players got it
function SendClientMessageInRange(x, y, z, radius, color, text, world) end

---A chat message to one player - a text, or pieces that differ in colour, weight and slant.
---
---`message` is a text - `SendClientMessage` with the default colour - or a table:
---
---| key | what it is |
---|---|---|
---| `text` | the words, in one colour |
---| `spans` | the words in pieces: a list whose entries are a text or a table `{ text = "...", color = 0xRRGGBBAA, bold = true, italic = true }` (a span's `color` left out is the line's colour). When there are spans, `text` is ignored |
---| `channel` | the channel the line belongs to; `""` or left out is the default channel |
---| `color` | `0xRRGGBBAA`: the line's colour and that of every span that has none of its own. Left out, it is the channel's colour, else white |
---| `template` | the name of a chat template of the interface (`[theme.chat.templates]` in its `ui.toml`, `ooc`): the web chat lays the line out with it; the game's own chat draws the plain line |
---| `params` | the template's `{0}` to `{15}`: a list of texts (a number is written as text) - at most 16, 256 characters each, 1024 in all |
---
---A line carries at most **16 spans** and **512 characters** in all - counted over the words of every span - and a message
---over either is **refused, never cut**; so is an empty one.
---
---With a `template` and no `text` or `spans`, the plain line - the game's own chat, a bot, the server's log - is the template
---with the `params` put in and its tags left out (`<b>{0}</b>: {1}` with `{"Henry", "hi"}` is `Henry: hi`); when the interface
---has no template of that name, the params one after the other. A template's own words are the interface's: the template
---language (`{0}`, `{{` and `}}`, `<b>`, `<i>`, `<span class="...">`) never runs anything, and every param is shown as text.
---
---A line sent to **one player** reaches them whatever the channel's visibility - the mode chose the recipient. The game's
---own chat draws a line in one colour (the first span's, when it has one, otherwise the line's) with the channel's label in
---front; a chat that can style messages draws each piece as it was given.
---
---The answer is `true`, or `false` and the reason: `"no such player"`, `"no such channel"`, `"too many spans (16 at most)"`,
---`"the message is over 512 characters"`, `"empty message"`, `"bad template name (a-z, 0-9 and _, starting with a letter, 32
---at most)"`, `"too many params (16 at most)"`, `"a param is over 256 characters"`, `"the params are over 1024 characters in
---all"`, `"params need a template"` - or, for a table that is not a message, what is wrong with it in words (`"a span needs
---its text"`, `"spans must be a list"`, `"color must be a number"`, `"template must be a text"`, `"params must be a list"` ...).
---@param pid number the player
---@param message string|table a text, or a table `{ text | spans, channel, color, template, params }`
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"too many spans (16 at most)"`, `"no such channel"` ...)
---@return string reason
function SendChatMessage(pid, message) end

---The same message in everyone's chat - on a channel, in the chat of the players who see it.
---
---The message is the one of `SendChatMessage`, with the same limits and the same reasons (bar `"no such player"`). On the
---default channel the line goes to everyone connected; on a channel it goes to the players the
---channel is visible to - an admin-only channel's line to the admins, a party channel's to everyone who is in a party.
---@param message string|table a text, or a table `{ text | spans, channel, color, template, params }`
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SendChatMessageToAll(message) end

---Empties a player's chat.
---
---The player's chat forgets every line it holds. The F9 window keeps its own copy of the lines. Nothing is said to the
---player: send a line afterwards if they should be told.
---@param pid number the player
---@return boolean `false` when not connected
function ClearPlayerChat(pid) end

---A line over a player's head, in a color of your own, for everyone near them.
---
---The same speech bubble a chat line shows over the speaker (`[ui] chat_bubbles`), but the mode's: the text, the color
---(`0xRRGGBBAA`), how far it is seen (`distance` metres, `20` by default) and how long it stays (`ms`; `0` or `nil` = by
---the line's length, 5 to 12 s). The speaker sees nothing - nobody sees their own head - so a role-play mode prints the
---line in their chat as well. One line at a time per player; a new one replaces the old.
---@param pid number the player
---@param text string the line (one line, cleaned like a chat line - no control or invisible characters; long ones are cut)
---@param color? number `0xRRGGBBAA` (`COLOR_WHITE`)
---@param distance? number metres (`20`)
---@param ms? number milliseconds (`0` = by the length)
---@return boolean `false` when not connected
function SetPlayerChatBubble(pid, text, color, distance, ms) end

---Adds a chat channel that only some players see or may write into.
---
---A channel is a room of the chat with a name, a label and a colour: Trade, Staff, a guild's. A line a player types on it
---goes to the players who **see** the channel, and the game shows it with the channel's label. `options` is a table, and
---every key of it is optional:
---
---| key | what it is |
---|---|---|
---| `label` | what a chat shows for the channel, 32 characters at most (`"Trade"`); the name when left out |
---| `color` | `0xRRGGBBAA`: the channel's tab, and the colour of its lines that have none of their own (white) |
---| `visible` | who sees the channel and its lines: `"all"` (the default), `"admin"` (admins), `"party"` (players who are in a party: a member's line goes to **their party** alone), or a `function(pid)` that answers `true` for each player who sees it |
---| `can_send` | who may type into it: `true` (everyone who sees it - the default), `false` (nobody: only the mode writes there), `"admin"`, or a `function(pid)` that answers `true` for the players who may |
---
---A player who cannot see a channel cannot write into it either. A line on a channel that does not exist, or one the
---player may not write into, is refused with a notice ("There is no such chat channel." / "You cannot write in that
---channel.") and never reaches `OnPlayerText`.
---
---The **name** is 1 to 32 letters, digits and `_` (capitals are lowered); the default channel, `""`, is always there and is
---not registered. At most 64 channels; registering a name again replaces the channel. Each player's chat is told the
---channels they can see when they join and whenever a channel changes, they become or stop being an admin, or they join or
---leave a party. A `function` is asked when that list is made and for every line - for a player who joins, after
---`OnPlayerConnect`, so it may read what the mode set up there; when its answer changes for any other reason, call
---`RefreshChatChannels`. A function that fails answers `false` and is logged and counted like any callback.
---
---A reload of the mode empties the channels: register them in `OnGameModeInit`.
---
---The answer is `true`, or `false` and the reason: `"a channel name is 1-32 of a-z, 0-9 and _"`, `"the label is over 32
---characters"`, `"too many channels (64 at most)"`, `"visible is all, admin, party or a function"` or `"can_send is true,
---false, admin or a function"`.
---@param name string the channel's name - 1 to 32 of `a-z 0-9 _`
---@param options? table `{ label, color, visible, can_send }` - every key optional
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function RegisterChatChannel(name, options) end

---Takes a chat channel away.
---
---Every player's chat is told the shorter list, and a line typed on the channel is refused from then on. Lines already in
---the chats stay.
---@param name string the channel's name
---@return boolean `false` when there is no such channel
function UnregisterChatChannel(name) end

---Sends the channel list to a player's chat again - for a rule of the mode that changed.
---
---A player's chat is told its channels when they join and when a channel, their admin flag or their party changes. A
---channel whose `visible` or `can_send` is a function is asked at those moments, so when the answer changes at another
---one - the player joined a guild, was muted - call this and the chat looks again. Without a player it goes to everyone.
---@param pid? number|nil the player; `nil` for everyone
function RefreshChatChannels(pid) end

---Makes a `/command` with its handler, its help and its rules in one call.
---
---`/name rest of the line` runs `fn(pid, args)`: `args` is the rest of the line, trimmed, `""` when there is none. The
---handler runs **before** `OnPlayerCommandText` is asked and before the server's built-in commands, so a registered name
---wins over both - over the built-in `/help` too. What is not registered goes the old way, so a mode may use both. A handler
---that raises an error is logged and counted like any callback; the player is told nothing.
---
---`options` is a table, and every key of it is optional:
---
---| key | what it is |
---|---|---|
---| `help` | one line on what the command does, 160 characters at most |
---| `params` | the usage that follows the name - `"<player> [reason]"` - as a text, or a list of words joined with spaces; 96 characters at most |
---| `admin` | `true`: anyone who is not an admin (`SetPlayerAdmin`) is answered "Admins only." and the handler does not run; only admins are offered the command |
---| `secret` | `true`: the command's typing is a secret, as with `SetSecretCommand` - a chat masks it and keeps it out of its history, and `args` arrives exactly as typed. The handler must not log or store it |
---
---A chat that can suggest offers the command to the players who may use it, with its help and its usage, while they
---type; the game's own chat has no such list. `/help` lists the registered commands the player may use after the
---server's own.
---
---The **name** is 1 to 32 letters, digits, `_` and `-`; a slash in front and capitals are forgiven (`"/Pay"` is `pay`). `fight` and `peace` are the server's own and cannot be
---registered. At most 256 commands; registering a name again replaces the command. A reload of the mode empties the
---registry: register the commands in `OnGameModeInit`.
---
---The answer is `true`, or `false` and the reason: `"a command name is 1-32 of a-z, 0-9, _ and -"`, `"the handler is not
---a function"`, `"/fight is the server's own"`, `"the help is over 160 characters"`, `"the usage is over 96 characters"` or
---`"too many commands (256 at most)"`.
---@param name string the command without the slash - 1 to 32 of `a-z 0-9 _ -`
---@param fn function `function(pid, args)` - runs when a player types the command
---@param options? table `{ help, params, admin, secret }` - every key optional
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function RegisterCommand(name, fn, options) end

---Takes a registered command away.
---
---The command is no longer answered by its handler - the line goes on to `OnPlayerCommandText` and the built-ins - and
---its secret mark and its suggestion go with it.
---@param name string the command's name
---@return boolean `false` when there is no such command
function UnregisterCommand(name) end

---Suggests a command to the chats that can suggest one - for everyone, or for one player.
---
---A registered command (`RegisterCommand`) is suggested by itself, and so are the server's own commands to the players who
---may use them; this is for a command the mode answers in `OnPlayerCommandText`, or for one only some players are offered.
---`name` is a command name as `RegisterCommand` takes it, `help` at most 160 characters and `params` the usage that
---follows the name - a text, or a list of words - at most 96.
---
---A suggestion made for a name replaces the server's own for that name, and a registered command's replaces yours; one made
---for a player replaces every other for that player. At most 256 for everyone and 64 for one player. A reload of the mode
---empties them: suggest again in `OnGameModeInit` or `OnPlayerConnect`.
---
---The answer is `true`, or `false` and the reason: `"a command name is 1-32 of a-z, 0-9, _ and -"`, `"the help is over 160
---characters"`, `"the usage is over 96 characters"`, `"too many suggestions (256 at most)"`, `"too many suggestions for one
---player (64 at most)"` or `"no such player"`.
---@param name string the command's name, without the slash
---@param help? string|nil one line on what it does
---@param params? string|table|nil the usage - `"<player>"` - as a text or a list of words
---@param pid? number|nil the player; `nil` for everyone
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function AddChatSuggestion(name, help, params, pid) end

---Takes back a suggestion made with `AddChatSuggestion`.
---
---For everyone, or - with a player - the one made for that player. A registered command's suggestion and the server's own
---are not this one's: `UnregisterCommand` takes the command's away.
---@param name string the command's name
---@param pid? number|nil the player; `nil` for the one made for everyone
---@return boolean `false` when there was no such suggestion
function RemoveChatSuggestion(name, pid) end

---Shows or hides the chat on a player's screen.
---
---Hidden, none of the chat's lines show on the player's screen and **Enter** opens no chat box (a box open at that moment
---closes). Messages still reach them and show again once the chat is back. Use it for a login screen, a cutscene or
---anything that wants the whole screen. It lasts until you change it or the player leaves; every visit starts with the chat
---shown. Players can also hide the chat themselves in the launcher's options - the chat shows only while both allow it,
---and `GetPlayerChatVisible` reports your side alone.
---@param pid number the player
---@param visible boolean `true` to show the chat, `false` to hide it
---@return boolean `false` when not connected
function SetPlayerChatVisible(pid, visible) end

---Whether the chat shows on a player's screen as far as the mode goes (`SetPlayerChatVisible`).
---
---`true` unless the mode hid it. A player who hid the chat in the launcher's options still reads `true` here - the server
---does not know that setting.
---@param pid number the player
---@return boolean `false` also when not connected
function GetPlayerChatVisible(pid) end

-- ======== Vitals ================================================================
-- The server owns every player's **health, stamina, injuries and bleeding** (`[combat]` in `server.toml`; the
-- Combat guide has how a hit becomes damage). Health and stamina are full at every spawn; `0` health is dead
-- until the respawn. The character's stats, skills, XP and perks are a group of their own, from `SetPlayerStat` on.

---The player's health.
---@param pid number the player
---@return number `0` .. `GetPlayerMaxHealth`; `-1` when not connected
function GetPlayerHealth(pid) end

---The player's maximum health (100).
---@param pid number the player
---@return number `-1` when not connected
function GetPlayerMaxHealth(pid) end

---Sets the player's health; 0 kills.
---
---Clamped to `0 .. max`; the player's client shows the new value. `0` kills the player at once - `OnPlayerDeath` with
---attacker `-1`, the respawn after `[combat] respawn_seconds`. A dead player's health stays `0` until they respawn; use
---`HealPlayer` or `SpawnPlayer` to bring one back. A player who is not in the world yet is ignored (the call still returns
---`true`).
---@param pid number the player
---@param health number the new health
---@return boolean `false` when there is no such player; `true` otherwise, also for a player not yet in the world, whom the call ignores
function SetPlayerHealth(pid, health) end

---Whether the player's health is 0 and they wait for the respawn.
---@param pid number the player
---@return boolean
function IsPlayerDead(pid) end

---The player's stamina - the bar they see.
---
---Swings, hits taken, blocks, shots, sprints and jumps cost it; it regenerates after a pause (Combat).
---What the player sees on their stamina bar **is** this number.
---@param pid number the player
---@return number `0` .. `GetPlayerMaxStamina`; `-1` when not connected
function GetPlayerStamina(pid) end

---The player's maximum stamina (`[combat] max_stamina`).
---@param pid number the player
---@return number `-1` when not connected
function GetPlayerMaxStamina(pid) end

---Sets the player's stamina.
---
---Clamped to `0 .. max`. A swing thrown with less stamina than it costs lands weakly - a mode may tire a player on purpose.
---A player who is not in the world yet is ignored (the call still returns `true`).
---@param pid number the player
---@param stamina number the new stamina
---@return boolean `false` when there is no such player; `true` otherwise, also for a player not yet in the world, whom the call ignores
function SetPlayerStamina(pid, stamina) end

---The player's injured body parts.
---
---A list of body parts, `BODY_PART_HEAD` .. `BODY_PART_LEG_RIGHT` (`1` .. `6`); `{}` when whole. An injured arm makes the
---swings weaker and costlier, an injured head or torso halves the stamina regeneration. A hit of at least
---`[combat] injury_threshold` injures the part it struck; `OnPlayerInjury` says so.
---@param pid number the player
---@return table a list of body part ids
function GetPlayerInjuries(pid) end

---Whether the player has an injury - anywhere, or on one part.
---@param pid number the player
---@param part? number a body part `1` .. `6`; without it, any part
---@return boolean
function IsPlayerInjured(pid, part) end

---The name of a body part id.
---@param part number `1` head, `2` torso, `3` left arm, `4` right arm, `5` left leg, `6` right leg
---@return string `"head"`, `"torso"`, `"arm_left"`, `"arm_right"`, `"leg_left"`, `"leg_right"`; `""` for anything else
function GetBodyPartName(part) end

---How fast the player is bleeding, in health per second.
---
---A stab or a slash the armour let enough of through opens a wound (`SetBleedRules`); each wound bleeds on its own for the
---rules' seconds and stops by itself, and the open ones add up (at most the rules' `maxRate`). `0` means not bleeding. A
---bleed-out is a death by the last attacker. A bandage stops it, so do `HealPlayer` and the respawn.
---@param pid number the player
---@return number health lost per second; `0` = not bleeding
function GetPlayerBleeding(pid) end

---Whether the player is bleeding.
---@param pid number the player
---@return boolean
function IsPlayerBleeding(pid) end

---Sets how fast the player bleeds, in place of their open wounds.
---
---One wound of `rate` health a second for `seconds` (left out = the rules' seconds, `SetBleedRules`) replaces every open
---wound, capped by the rules' `maxRate`; `0` stops the bleeding, as a bandage does. The player's client shows it. A bleed-out
---is a death by the last attacker.
---@param pid number the player
---@param rate number health lost per second; `0` stops the bleeding
---@param seconds? number how long it bleeds; left out = the rules' seconds
---@return boolean `false` when the player is dead or not in the world
function SetPlayerBleeding(pid, rate, seconds) end

---How cuts bleed on this server - the rate, how long, and how much armour holds.
---
---A stab or a slash that lands opens a wound that bleeds `perDamage` health a second per point of the blow's damage for
---`seconds`, then stops by itself; a later cut opens a wound of its own (it does not restart the others), and together they
---bleed at most `maxRate` a second. **Armour**: a cut bleeds only when the armour on the struck part let at least
---`minThrough` of it through (`0` .. `1`) - plate, or mail over a gambeson, holds more than half - else the `armouredCuts`-th
---cut the armour held since the last wound opens one all the same (a gap found; `0` = never through the armour). A smash
---never bleeds. **Shots**: `ranged = false` keeps arrows, bolts and bullets from ever opening a wound (players' and actors'
---alike); by default they bleed as any stab. A key left out keeps the server's own: `perDamage`, `maxRate` and `seconds` are
---`[combat] bleed_per_damage`, `max_bleed` and `bleed_seconds`, `minThrough` is `0.5`, `armouredCuts` `3`, `ranged` `true`;
---`SetBleedRules(nil)` goes back to them all.
---The rules cover players and actors alike; open wounds keep their rate and time. A single blow's bleeding is the hit
---callback's to decide (`OnPlayerDamage`'s second return value).
---@param rules table `{perDamage=, maxRate=, seconds=, minThrough=, armouredCuts=, ranged=}`; `nil` = the server's own
function SetBleedRules(rules) end

---The bleeding's rules in force.
---
---Every key set: the mode's where `SetBleedRules` gave one, else the server's own.
---@return table `{perDamage=, maxRate=, seconds=, minThrough=, armouredCuts=, ranged=}`
function GetBleedRules() end

---The game's health perks on this server - Revenant's regeneration, Diehard's save from a killing blow and the prayer's Guardian Angel.
---
---The server owns every player's health, so a perk whose effect is a health change cannot work in the player's own game online:
---the server plays it instead, to every player who holds the perk (their game reports it, and so do `SetPlayerProgress` and
---`AddPlayerPerk`). Revenant and Diehard are **on by default**, with the game's own numbers; the Guardian Angel is **off** until
---the mode sets `guardianAngel = true`.
---**Revenant**: health comes back `revenantRate` a second (`0.125`) up to `revenantCap` of the maximum (`0.5` = 50 of 100),
---`revenantIICap` with Revenant II (`0.75`) - never in a fight (with a player, an NPC actor or an animal), in the game's own
---combat mode, while bleeding or knocked out, nor for `revenantPause` seconds (`5`) after a blow taken. A potion's healing adds
---to it.
---**Diehard** (the game's "Hard to kill"): a blow from a player, an NPC actor or an animal that would kill the player leaves them
---at 1 health and heals `diehardHeal` (`25`) over `diehardSeconds` (`2`); another killing blow while that heal runs is survived
---the same way, and once it ends the perk rests `diehardCooldown` seconds (`3000`) before it saves again. A fall, a bleed-out or
---`SetPlayerHealth` is never saved, and the player's death callback does not run for a save.
---**Guardian Angel**: a player with Fundamentals of Divinity who prays at a shrine gets the game's Guardian Angel; it saves them
---from one killing blow the way Diehard does (1 health, the same heal, killing blows inside it survived too), and then it is
---spent and gone from their game. The game's own limit of 12 game hours (24 with Fundamentals of Divinity II) still applies. A
---player who also holds Diehard is saved by Diehard first; their prayer adds no second save. A mode can give the angel itself
---with `GivePlayerBuff` (`"perk_basic_theology"`) - it saves the same way, Fundamentals of Divinity or not, while the angel is
---on. Turn it on in `OnGameModeInit`: a player already in the game when it is turned on counts their prayer from their next join.
---`revenant = false` or `diehard = false` switches that effect off. A key left out keeps the game's number;
---`SetPerkEffects(nil)` goes back to them all (the angel off).
---@param rules table `{revenant=, revenantRate=, revenantCap=, revenantIICap=, revenantPause=, diehard=, diehardHeal=, diehardSeconds=, diehardCooldown=, guardianAngel=}`; `nil` = the game's own
function SetPerkEffects(rules) end

---The health perks' rules in force.
---
---Every key set: the mode's where `SetPerkEffects` gave one, else the game's own numbers.
---@return table `{revenant=, revenantRate=, revenantCap=, revenantIICap=, revenantPause=, diehard=, diehardHeal=, diehardSeconds=, diehardCooldown=, guardianAngel=}`
function GetPerkEffects() end

---Makes the player whole - health, stamina, injuries, bleeding, buffs, drink.
---
---Full health and stamina, every injury healed, the bleeding stopped, every buff the server gave taken back, sober; the
---player's client shows it and the others see the body straighten. The `/heal` built-in does the same.
---@param pid number the player
---@return boolean `false` when not connected
function HealPlayer(pid) end

-- ======== Combat ================================================================
-- A player's game only reports what its swing or its arrow hit; the server decides what that did and tells the mode. The
-- Combat guide walks through the model - the tables, stamina, injuries and bleeding, perfect blocks,
-- master strikes and clinches, fights and the lock-on, teams and pvp. The callbacks let a mode change or cancel every hit; the functions manage fights.

---**Called by the server** - The server accepted a hit on a player - change the damage, cancel it, or let it through.
---
---Called before the damage comes off the health. `attacker` is the pid who struck, or `-1` for damage without one (an NPC
---actor's blow when the mode has no `OnActorAttack`, `SetPlayerHealth`). `zone` is the attack zone the attacker's game
---recorded; `part` the body part struck, `1` .. `6` (`0` unknown; `GetBodyPartName`); `weapon` the attacker's weapon by its
---table name (`shortswordBroad`, `bow_c + arrow_normal`; `""` bare-handed or without the tables); `dtype` `"stab"`, `"slash"`,
---`"smash"` or `""`; `bleeds` whether the blow opens a bleeding wound by the server's rules (`SetBleedRules`: a cut the
---armour let enough of through) and `armour` the share of it the armour on that part took (`0` .. `0.85`). **Return a
---number** to change the damage (`0` cancels the hit, so do a stamina cost, an injury and a bleed), **`false`** to cancel it,
---nothing to keep it - and a **second value** `true` / `false` to decide the bleeding yourself (`return nil, false` keeps the
---damage and opens no wound). Hits between teammates never get here, nor a swing the victim met
---with a perfect block or blocked on their own screen; a master strike's counter does, with the defender as `attacker`
---(the torso, × `[combat] master_strike_scale`), and so does a blow inside a clinch (the torso, × `[combat] clinch_scale`)
---unless the victim countered it. Two players clinch only while `[combat] clinch` and `[combat] pvp` are on, in the same virtual
---world, already in a fight, within three metres, neither riding, and not within a second of the end of their last clinch. A
---melee hit between two players is judged on the victim's screen: it comes when the victim's game says the blow landed - a
---moment after it did on the attacker's screen - with the body part it struck there; a blow the attacker saw land that the
---victim's game never shows within `[combat] verdict_window_ms` is a miss (`unanswered_blow`). A player whose game has
---judged no blow yet this session (a bot) is hit as the attacker saw it, up to `parry_window_ms` after the blow
---(`counter_parry_window_ms` for a counter); a clinch blow waits up to `clinch_parry_window_ms` for the victim's counter (the
---Combat guide).
---
---Return value: a number replaces the damage (`0` cancels); `false` cancels the hit; nothing keeps it. A second value `true` / `false` decides the bleeding
---@param pid number the victim
---@param attacker number who struck; `-1` = nobody
---@param damage number what the victim is about to lose
---@param zone number the attack zone the attacker's game recorded
---@param part number the body part struck, `1` .. `6`; `0` unknown
---@param weapon string the weapon's table name; `""` bare-handed
---@param dtype string `"stab"`, `"slash"`, `"smash"` or `""`
---@param bleeds boolean whether the blow opens a bleeding wound by the server's rules (`SetBleedRules`)
---@param armour number the share of the blow the armour on the struck part took, `0` .. `0.85`
function OnPlayerDamage(pid, attacker, damage, zone, part, weapon, dtype, bleeds, armour) end

---**Called by the server** - A hit injured one of the player's body parts.
---
---A hit of at least `[combat] injury_threshold` injures the part it struck. An injured arm makes the player's swings weaker
---and costlier; an injured head or torso halves the stamina regeneration. `HealPlayer` and the respawn heal it.
---@param pid number the victim
---@param attacker number who struck; `-1` = nobody
---@param part number the body part, `1` .. `6`
function OnPlayerInjury(pid, attacker, part) end

---**Called by the server** - The player's health reached 0.
---
---A hit, a bleed-out (the last attacker is named) or `SetPlayerHealth(pid, 0)` (attacker `-1`). Every client shows the death;
---the respawn follows after `[combat] respawn_seconds` at the player's spawn point - with `0` there the mode calls
---`SpawnPlayer` itself. Every fight of the player ends (`OnFightEnd` with `"death"`).
---@param pid number who died
---@param attacker number who killed them; `-1` = nobody
function OnPlayerDeath(pid, attacker) end

---**Called by the server** - A player wants to search a dead player's body - return `false` to refuse.
---
---Nothing has opened yet. Return `false` and nothing opens, **without a word** to the searcher; a text after the `false` is
---shown in their chat (`return false, "Not your kill."`). Otherwise the game's own loot window opens on what the dead player carries (`[combat] loot_bodies`:
---everything, or everything but what they wear, and the purse) and whatever the searcher takes is gone from the dead player's
---game, item by item. The list is what the server's records say the dead player carried, and the searcher is credited only with
---what the dead player's game really gave up - a victim who left or came back to life voids the search. The respawn waits
---while the search is open. `victim` is `-1` for a body that stayed after its player respawned and left the
---server (`[combat] corpse_seconds`). With `loot_bodies = "none"` nobody is asked: bodies cannot be searched at all.
---
---Return value: `false` refuses saying nothing, `false, "text"` refuses and tells the searcher that text; anything else lets them search
---@param pid number the searcher
---@param victim number whose body it is; `-1` = its player has left
function OnPlayerLootBody(pid, victim) end

---**Called by the server** - A dead player respawns and their body stays behind as a corpse - fill it here if it should hold anything.
---
---Only on a server with `[combat] corpse_seconds` above 0: the body lies where it fell for that long, on the screens of the
---players who saw it. **It holds nothing and the player keeps everything** unless the mode says otherwise here: this runs
---before the respawn, the player's inventory still the one they died with - `SetCorpseItems` puts things on the corpse
---(anyone may then search it, `[combat] loot_bodies` allowing) and `SetPlayerInventory` / `EmptyPlayerInventory` take
---them from the player. The two are separate on purpose: putting a thing on the corpse does not take it from the player.
---@param pid number the player who respawns
---@param corpse number the corpse's id, for `SetCorpseItems`, `GetCorpseItems` and `RemoveCorpse`
function OnPlayerCorpse(pid, corpse) end

---**Called by the server** - Two players are in a fight from now on.
---
---Their clients let the game's lock-on pick each other's body from here. `reason` is `"hit"` (a swing of one reached the
---other's body, or one pulled the other off their horse), `"command"` (`/fight <name>`) or `"mode"` (`StartFight`). Both players read a chat line about it.
---@param a number one player
---@param b number the other
---@param reason string `"hit"`, `"command"` or `"mode"`
function OnFightStart(a, b, reason) end

---**Called by the server** - A fight between two players is over.
---
---`reason` is `"timeout"` (`[combat] fight_timeout` seconds without a blow), `"death"`, `"left"` (a disconnect), `"peace"`
---(`/peace`) or `"mode"` (`EndFight`). Both clients drop the lock.
---@param a number one player
---@param b number the other
---@param reason string `"timeout"`, `"death"`, `"left"`, `"peace"` or `"mode"`
function OnFightEnd(a, b, reason) end

---**Called by the server** - A player's melee blow struck the level itself - a tree, a rock, a wall.
---
---The player's own game saw their blade (or fist) meet the level rather than a body, and says what it met - named the way a
---client script's GetLookTarget names a look. Once a swing at most; the server
---checks that the point is within the drawn weapon's reach of the player, then calls this. Nothing else happens: whether a blow on
---a tree chops it, plays a sound or does nothing is the mode's.
---
---The game decides what a blade meets: a trunk, a rock or a wall, yes - a swing at the bare ground lands nowhere and calls
---nothing, and a player standing right up against a big rock or a wall gets the game's own refusal (the cross on the
---crosshair) until they step back.
---
---`hit` has `kind` (`"terrain"`, `"static"` - a building, a wall, a rock -, `"vegetation"` - a tree or a bush, and many of the
---level's small stones - or `"object"`, a level object with a script), `x`, `y`, `z` (the point struck, metres), `normal`
---(`{x, y, z}`), `surface` (the game's surface type: `"mat_wood"`, `"mat_rock"` ...) and `weapon` (the drawn weapon by its table
---name, `"fists"` without one). A tree, a bush or a piece of scenery also has `mesh` (the model, lower case - its folder is a
---tree's species), `bbox` (`{min = {x, y, z}, max = {x, y, z}}`) and `center`: the mesh and the centre are what
---`RemoveLevelObject` takes to take it away. `mesh` is `nil` when the game cannot tell which piece of the level was struck. An
---object has `name` (its level name - a door's or a chest's key) and `class`.
---
---It is the player's game's word: a modified game could report a blow that never happened, within the weapon's reach of where
---the player stands. Count blows, add a cooldown, and check the rest as you would any input from a player.
---@param pid number the player
---@param hit table `{kind, x, y, z, normal, surface, weapon, mesh, bbox, center, name, class}`
function OnPlayerHitScenery(pid, hit) end

---Keeps a player from attacking at all, or lets them again.
---
---With `false` the player's game starts no swing, punch, kick, clinch, stealth attack, shot or weapon draw - its own controls
---for them do nothing - and a weapon in their hands is put away (again whenever one comes out). The server refuses whatever
---swing, shot or blow still arrives, and a master strike of theirs counts as a plain perfect block. They can still block,
---parry, dodge, walk and talk, and they can be hit. It lasts through deaths and respawns until the mode sets it back; a player
---who joins starts allowed. For handcuffs, a jail, a safe zone or a tavern where nobody draws. `false` when the player is not
---in the world yet.
---@param pid number the player
---@param canAttack? boolean `false` keeps them from attacking, `true` (the default) lets them
---@return boolean
function SetPlayerCanAttack(pid, canAttack) end

---Whether the player may attack.
---
---`true` unless `SetPlayerCanAttack` said otherwise.
---@param pid number the player
---@return boolean
function CanPlayerAttack(pid) end

---Puts two players in a fight so their games can lock on to each other.
---
---From here either one's game may pick the other's body as the opponent - the direction indicators, the combat stance. The
---server starts a fight by itself when a swing reaches a body and on `/fight <name>`; this is the mode's way (`reason`
---`"mode"`). On a fight that is already running it **restarts the `[combat] fight_timeout` clock** - a duel mode calls it
---every second so two circling duelists never lose the lock. `false` when pvp is off, one of the two is dead or not in the
---world, or they are in different virtual worlds. Teammates can be put in a fight, but their hits stay refused.
---@param a number one player
---@param b number the other
---@return boolean `true` when the two fight now
function StartFight(a, b) end

---Ends the fight between two players.
---
---Both clients drop the lock; `OnFightEnd` fires with `"mode"`. Nothing happens when the two were not fighting.
---`/peace` ends every fight of the caller the same way.
---@param a number one player
---@param b number the other
---@return boolean `false` when one of them is not connected
function EndFight(a, b) end

---Whether two players are in a fight right now.
---@param a number one player
---@param b number the other
---@return boolean
function AreFighting(a, b) end

---Everyone the player is fighting right now.
---@param pid number the player
---@return table a list of pids, `{}` at peace
function GetPlayerOpponents(pid) end

---The weapon the damage model charges the player's hits to.
---
---The table name of the melee weapon the player has equipped and drawn (`shortswordBroad`, `longSwordDuel` ...), as the
---`weapon` argument of `OnPlayerDamage` names it; `""` bare-handed, with the weapon sheathed, or without the tables export.
---`GetItemInfo` turns the name into its catalogue entry.
---@param pid number the player
---@return string the weapon's name; `""` when none
function GetPlayerWeapon(pid) end

---What a player holds in their hands right now.
---
---The item classes (GUIDs) in the player's right and left hand as their game last said - a drawn sword and a shield, a bow
---and its arrow, a hammer and tongs at the anvil; `""` for an empty hand. This is what they **hold**, where
---`GetPlayerEquipment` is everything they wear and carry in their slots, sheathed or not. It follows a draw, a switch or a
---holster within a fraction of a second. A lit torch is not counted. `GetItemInfo` turns a class into its catalogue entry.
---@param pid number the player
---@return string , `string` - the right hand's item class and the left hand's; `""` for an empty hand or a player not connected
function GetPlayerHandItems(pid) end

---Whether a player has a weapon drawn.
---
---`true` while the player's game says a weapon is out and ready - a sword drawn, a bow readied; raised fists do not count.
---@param pid number the player
---@return boolean `true` with a weapon drawn; `false` sheathed or not connected
function IsPlayerWeaponDrawn(pid) end

---What a corpse holds.
---
---A corpse is a dead player's body left after the respawn (`[combat] corpse_seconds`; its id comes with
---`OnPlayerCorpse`). It holds what the mode put on it with `SetCorpseItems`, less what searches have taken since. One of
---the mode's tagged items (`GivePlayerTaggedItem`) on it is an entry of its own, and goes to whoever takes it with its tag.
---@param corpse number the corpse's id
---@return table a list of `{class=, amount=, health=, quality=}` (`quality` when known; a tagged item also `id=, name=, text=`); `nil` when there is no such corpse (it is gone)
function GetCorpseItems(corpse) end

---What a corpse holds from now on - the list anyone who searches it takes from.
---
---Replaces the corpse's list. A class is any key of the item catalogue; the money is the item class
---`money` in tenths of a Groschen (`{class = "money", amount = 150}` is 15 Groschen). With items on it the corpse gets the
---game's loot prompt on every screen that keeps it (`[combat] loot_bodies` not `"none"`); an empty list takes the prompt
---away. **Nothing is taken from the player** - move things with `SetPlayerInventory` / `EmptyPlayerInventory` in the
---same call, or they are on the corpse and on the player both.
---@param corpse number the corpse's id
---@param items table a list of `{class=, amount=}`, as `GetPlayerInventory` returns it
---@return boolean `false` when there is no such corpse
function SetCorpseItems(corpse, items) end

---Takes a corpse away now, with whatever it still holds.
---
---It goes from every screen at the next second, as when its `[combat] corpse_seconds` run out. Refused while someone is
---searching it.
---@param corpse number the corpse's id
---@return boolean `false` when there is no such corpse or someone is searching it
function RemoveCorpse(corpse) end

-- ======== Recipes ===============================================================
-- The **recipes** a character knows are the ones the alchemy table's book and the anvil's book show - the recipes
-- list has all of them, 31 alchemy recipes and 61 blacksmithing ones. In the game a character learns one by reading a recipe
-- document; a game mode can also teach one itself (`GivePlayerRecipe`) - a recipe bought from the mode's own shop, found in its own
-- inventory system, earned in a quest - and take one away (`RemovePlayerRecipe`).
-- 
-- **A recipe is named** by its key (`"alchemy:1"`, `"smithing:r_axework02"` - the first column of the list), by its English name
-- (`"Hair o' the Dog"`, any case; `alchemy:` or `smithing:` in front picks between two of one name) or by the class name of the
-- document that teaches it (`"recipe_hairodogPotion"`). Every function that gives a recipe back gives its key; `GetRecipeInfo`
-- says the rest. The server knows the recipes without the game's tables export.
-- 
-- **Saving them.** Nothing is kept between visits unless the mode keeps it. `OnPlayerLearnRecipe` is the moment a player's game
-- taught them one - save it then - and `SetPlayerRecipes` puts the saved list back at the next login, **exactly**: every other
-- recipe is taken away, also the ones the player's game still holds from an earlier character (the game keeps the alchemy book for as
-- long as it runs). `GetPlayerRecipes` lists what a character knows. A mode that teaches recipes its own way can refuse the game's:
-- return `false` from `OnPlayerLearnRecipe` and the recipe is taken away again (or hold the document's reading before it happens
-- with `SetItemUseCheck`).
-- 
-- A blacksmithing recipe is a perk of the character in the game, so it is in `GetPlayerPerks` too; an alchemy recipe learned from a
-- document is not. Keep recipes with the recipe functions, not the perk ones.

---**Called by the server** - The player's game taught them a recipe - save it, or return `false` to take it away again.
---
---Called when a player's character learned an alchemy or blacksmithing recipe in their game - they read a recipe document, or
---the game taught one its own way - a moment after it happened. `recipe` is the recipe's key, `kind` is `"alchemy"` or
---`"smithing"`.
---
---Return `false` and the recipe is taken away again: the book forgets it (the document stays read). Anything else keeps it.
---
---Not called for the mode's own `GivePlayerRecipe` and `SetPlayerRecipes`, nor for the recipes the character already knew
---when the player joined.
---
---Return value: `false` takes the recipe away again; anything else keeps it
---@param pid number the player
---@param recipe string the recipe's key, `"alchemy:1"`
---@param kind string `"alchemy"` or `"smithing"`
function OnPlayerLearnRecipe(pid, recipe, kind) end

---Every recipe of the game - their keys, the alchemy ones first.
---@param kind? string `"alchemy"` or `"smithing"` for one kind; nothing for both
---@return table `{key, ...}`
function GetRecipes(kind) end

---A recipe's key, kind, name, document and what it makes.
---
---`recipe` is its key, its English name, the class name of the document that teaches it or one of its perks' GUIDs. The table
---holds `key`, `kind` (`"alchemy"` or `"smithing"`), `id` (the game's own recipe id), `name` (English), `document` (the class
---name of the recipe document; `""` for a recipe no document teaches), `perks` (the GUIDs of the perks that teach it) and
---`products` (the item class GUIDs it makes - an alchemy recipe's by quality, the weakest first).
---@param recipe string a recipe's key, name or document
---@return table or `nil` - `{key, kind, id, name, document, perks = {guid, ...}, products = {guid, ...}}`; `nil` for no such recipe
function GetRecipeInfo(recipe) end

---The recipes the player's character knows.
---
---The keys of every recipe the character knows - from what their game reported, with the mode's own gives and takes at once.
---Right after the join it holds only what the mode gave: what the character knew already comes with their game's first report,
---a few seconds after the spawn.
---@param pid number the player
---@param kind? string `"alchemy"` or `"smithing"` for one kind; nothing for both
---@return table `{key, ...}`; empty for a player who is not there
function GetPlayerRecipes(pid, kind) end

---Whether the player's character knows a recipe.
---@param pid number the player
---@param recipe string a recipe's key, name or document
---@return boolean `false` for a recipe the character does not know, no such recipe, or a player not connected
function HasPlayerRecipe(pid, recipe) end

---Teaches the player's character a recipe - the book shows it from now on.
---
---Silently, with no notice: the alchemy table's or the anvil's book shows the recipe the next time the player opens it. Giving a
---recipe the character knows is fine. Called before the player is in the world, the recipe is taught right after their spawn.
---`OnPlayerLearnRecipe` is not called for it.
---@param pid number the player
---@param recipe string a recipe's key, name or document
---@return boolean `false` for no such recipe or a player not connected
function GivePlayerRecipe(pid, recipe) end

---Takes a recipe from the player's character - the book forgets it.
---
---The book leaves it out the next time the player opens it (a book open at the moment keeps the list it opened with).
---@param pid number the player
---@param recipe string a recipe's key, name or document
---@return boolean `false` for no such recipe or a player not connected; a recipe the character does not know is fine
function RemovePlayerRecipe(pid, recipe) end

---Exactly these recipes - the saved ones back at a login, every other one taken away.
---
---For a character's restore: the recipes listed are taught and every other one is taken away - also what the player's game still
---holds from an earlier character, which goes once their game has reported (a few seconds after the spawn). A recipe the list
---names that does not exist is skipped with a line in the server's log. Called before the player is in the world, the recipes
---are taught right after their spawn.
---@param pid number the player
---@param recipes table a list of recipe keys, names or documents - `{"alchemy:1", "smithing:r_axework02"}`
---@return boolean `false` when `recipes` is no table, or for a player not connected
function SetPlayerRecipes(pid, recipes) end

-- ======== Stats, skills, XP and perks ===========================================
-- A player's **progression** is what the game's character screen shows: the **stats** - `strength`, `agility`, `vitality` and
-- `speech`, with the story's `storyprogress` and the `prestige` of the Blacksmith - and the **skills** (`marksmanship`,
-- `weapon_sword`, `alchemy` ... thirty in all; the names), each with a **level** from `0` to `30`
-- and the **XP** gathered toward the next one; the **main level**, the one figure the screen shows for the whole character; the
-- **perk points** the levels bring and the **perks** a character earns (the perks); and two states of the
-- character, the **nourishment** and the **energy** (the Rest). All of it is the game mode's: a mode reads what a player has,
-- sets any of it, decides whether and how much XP the players gain, and saves it with its character - the server keeps nothing
-- between visits.
-- 
-- **The record.** The server keeps a record of each player's progression as their game reports it - and, where the progression
-- check acts under `[audit] mode = "enforce"` (below), as the server can explain it: a level, a perk or a number
-- of perk points the moment it changes, XP and the two states within seconds, the whole of it again every minute and after every
-- spawn. `GetPlayerStat`, `GetPlayerSkill`, `GetPlayerLevel`, `GetPlayerPerkPoints`, `GetPlayerPerks` and
-- `GetPlayerProgress` read the record. A stat or skill it has not heard of yet reads as level `0`, so a mode that saves a
-- character waits for the player's first report (`OnPlayerProgressChange`) before it trusts what it reads.
-- 
-- **The main level.** The game shows one level for the whole character and works it out itself from the levels of the stats and
-- skills, so it is **read only**: `GetPlayerLevel` answers it (so does `GetPlayerStat` with `mainlevel`), and it rises and
-- falls as the levels beneath it do, whether the player earned them or the mode set them. `SetPlayerStat` and
-- `AddPlayerStatXP` refuse the name, and it gathers no XP. A rise the player earns reaches `OnPlayerLevelUp` as the stat
-- `mainlevel`. `storyprogress` is another thing: the story's own progress, a stat like the four core ones.
-- 
-- **Perk points.** The game gives a character perk points as its levels rise, and the player spends them on perks. Every stat
-- and skill holds its own unspent points, and the main level holds a pool for the points that belong to no stat or skill.
-- `GetPlayerPerkPoints` reads a count and `SetPlayerPerkPoints` sets it exactly, `0` .. `999`, with the name `mainlevel` for
-- the pool. `GetPlayerProgress` and `SetPlayerProgress` carry the points as `points`, and a change of points counts as a
-- change of levels for `OnPlayerProgressChange`: something to save now.
-- 
-- **Setting.** `SetPlayerStat`, `SetPlayerSkill` and `SetPlayerProgress` are **exact**: the level and the XP are what they
-- say, raising or **lowering** the character, with no level-up notice, and the record holds them at once. They are the only
-- calls that lower a level. `AddPlayerStatXP` and `AddPlayerSkillXP` give XP the game's own way - the notice, the perk
-- points - and only ever raise. `[spawn] stat_level` in server.toml raises the four
-- core stats to at least that level at every spawn (`0`, the default, leaves them alone; set it only for a mode that does not own
-- the levels). A set made before the player is in the world - at the login - waits for their spawn and is applied right after
-- it, in the order it was made. Every player who was not set starts as the level's own character: level 5 in the four core stats and
-- in most skills, level 0 in the rest, no perk points.
-- 
-- **XP is off unless the mode turns it on.** The game awards XP on its own - a kill, a hit, a distance walked, a book read. A
-- server gives none of it to begin with: `SetXPRate` is how a mode turns it on (`1` is the game's own amounts, `0` none, up to
-- `100`), `SetPlayerXPRate` gives one player a rate of their own, and `OnPlayerGainXP` lets the mode judge each award. XP the
-- mode hands out itself (`AddPlayerSkillXP`) does not pass through any of this. The shipped modes choose differently:
-- `freeroam.lua` and the built-in freeroam set the rate to `1` and keep nothing of a player's progress between visits,
-- `duel_arena.lua` sets `0` so the duelists stay equal, and `basicrp.lua` sets `1` and saves everything with the character.
-- 
-- **Saving a character.** Read it with `GetPlayerProgress` - when `OnPlayerProgressChange` says a level, a perk or perk points
-- changed, on a timer for the XP, and in `OnPlayerDisconnect` - and put it back with `SetPlayerProgress` when the player
-- logs in. Never write before the restore has gone out (or, for a character with nothing saved yet, before the game's first
-- report has arrived): a player whose game has not reported reads as an empty record, and saving that over the stored character
-- loses it. The snapshot holds the main level too, but the restore puts back only its pool of perk points: the level itself
-- follows from the levels that were restored.
-- 
-- **Names** are lower case; case, spaces and hyphens are forgiven, and a few words the game's menus use are understood: `warfare`
-- (`fencing`), `horsemanship` (`horse_riding`), `sword` / `swords` (`weapon_sword`), `polearm` / `polearms` (`weapon_large`),
-- `unarmed` (`weapon_unarmed`), `dagger` (`weapon_dagger`), `shield` (`weapon_shield`) and `bow` / `archery` (`marksmanship`).
-- The stats are `strength`, `agility`, `vitality`, `speech`, `storyprogress`, `prestige` and the read-only `mainlevel`. A stat
-- function given a skill's name - or the other way round - refuses it; the perk points calls take either kind. A perk is its
-- GUID, or with the game's tables export (Exporting the game's tables) its name or English name
-- as the perks list spells them. A horse has stats too - `SetHorseStat`, in the Horses group.
-- 
-- **The check.** A trainer writes a level, XP, perk points, a perk, the nourishment or the energy into a player's game as
-- easily as a player earns them, so the server judges what the game reports against what it can explain: the XP the game
-- awarded (the player's game counts each award it makes and tells the server), what the mode gave (`AddPlayerSkillXP`,
-- `SetPlayerStat`, `SetPlayerProgress` ...), the potions the player drank, the perks they hold, and the perk points their
-- levels pay. A rise nothing explains is an **excess**, and `[audit] mode` in
-- server.toml decides what happens to it. With `observe`, the default, the server logs
-- that it would put the excess back, asks `OnPlayerProgressViolation` for the XP and levels and changes nothing in the player's
-- game - and **the record this group reads still follows the game's report**, a forged value included, so a mode that saves
-- characters should run `enforce` before it trusts the record. With `enforce`
-- it puts the excess back - the player's game is told the figure the server can explain - and the record this group reads, and
-- so what a mode saves, holds that figure: a forged value is never the one that is saved. A game that writes the same forged
-- value back again and again after it was put back is cheating beyond doubt: `OnPlayerCheatDetected` hears
-- `progress_write_repeat` as a proven one and `[audit] action` follows. Progress the server cannot see being earned - a teacher,
-- a quest script, an event's reward - is put back like any excess unless the mode **vouches** for it in
-- `OnPlayerProgressViolation`; a server with story quests on that enforces must. Everything the mode itself orders - every set
-- and every `AddPlayerSkillXP` - counts as the character's from the moment it is sent, so a restore at the login is never an
-- excess. The nourishment and the energy fall steadily with the game's clock, so a value over its maximum is put back and one that
-- stands still while the clock runs is judged too, and the carry weight is checked (`GetPlayerWeight`). **This version acts only
-- on the rules that are measured** - an impossible XP or level, a clear rise (300 XP or more that nothing explains, over three
-- times what the server explains or three levels above it - not with story quests on), perk points the levels do not pay for,
-- a perk bought below its level or with points nothing paid for, a nourishment or an energy over its maximum; the rest is judged
-- and logged as "would ...", puts nothing back, and reaches the mode at most as a hint in `OnPlayerCheatDetected`
-- (the server configuration lists them). A set of the mode's own
-- that the player's game did not confirm is sent again after about 45 seconds, in either mode.
-- `GetPlayerProgressAudit` shows what the check counted for one player.

---**Called by the server** - The player's game awarded XP on its own - return false to refuse it, or a number to give that much instead.
---
---The game awards XP as the character does things: a kill, a hit, a distance walked, a book read. Every award goes through
---the XP rate first (`SetXPRate`); a rate of `0` gives nothing and this callback is never asked. `xp` is the award **times
---the rate**, for the stat or skill `name` (`kind` says which). Return `false`, or a number of `0` or less, to refuse it; a
---number to give that much instead; nothing (or `true`) to give `xp`. What is given arrives the game's way - the level-up
---notice, the perk points. A number you return is capped at `100000`. Some awards never get here: the server drops one above
---`10000` XP (before the rate), more than 40 a second from one player, and one for the main level or for a name that is neither
---a stat nor a skill.
---
---**Defining this callback costs a round trip.** The players' games hold every award until the server answers, so the XP
---shows a moment after the deed, and a fight sends several awards a second. A mode that only wants more or less XP sets the
---rate and leaves this out; one that has a rule to apply answers from memory here, never from a database query. XP the mode
---gives itself (`AddPlayerSkillXP`) does not come here.
---
---Return value: `false` refuses the award; a number gives that much instead (`0` or less refuses); nothing or `true` gives `xp`
---@param pid number the player
---@param kind string `"stat"` or `"skill"`
---@param name string the stat's or skill's lower-case name (`"marksmanship"`)
---@param xp number the XP the game awarded, times the XP rate
function OnPlayerGainXP(pid, kind, name, xp) end

---**Called by the server** - The player earned a level in a stat or a skill, or a level of the character.
---
---The player's game reported a level higher than the record had - the XP the game awarded (`SetXPRate`) or the mode's own
---`AddPlayerSkillXP` filled the bar. The record already holds the new level when this runs. It does **not** run for a level
---the mode set (`SetPlayerStat`, `SetPlayerProgress`); it needs a level the server already had to compare with, so the
---first report of a visit raises none. `OnPlayerProgressChange` follows for the same report, so a mode that saves
---characters needs only that one. A level the mode vouches for in `OnPlayerProgressViolation` under `[audit] mode =
---"enforce"` is announced here too, as a level the player's game earned.
---
---**The main level** comes here too, as the stat `mainlevel`: the level the game shows for the character rose because the
---levels beneath it did. The game works it out from those, so a rise the mode's own sets cause - a restore, `SetPlayerStat`,
---the `[spawn] stat_level` floor - a moment later is not a level the player earned, and is not announced: for about ten
---seconds after such a set the main level is taken into the record quietly.
---@param pid number the player
---@param kind string `"stat"` or `"skill"`
---@param name string the stat's or skill's lower-case name (`"mainlevel"` for the main level)
---@param level number the new level
function OnPlayerLevelUp(pid, kind, name, level) end

---**Called by the server** - The player's game reported a change to their progression - the moment to save it.
---
---The report held something the record did not: `levels` is `true` when a **level, a perk or a number of perk points**
---changed - save the character now - and `false` when only XP or the nourishment and energy moved, which happens all the
---time: save those on a timer and in `OnPlayerDisconnect`. The first report of a visit, the whole of the progression,
---counts as `levels`: it is also the sign that `GetPlayerProgress` now holds the player's own values (a mode that restores
---a saved character has put the saved ones back before then; one whose character has nothing saved takes this as the moment
---saving may begin).
---
---Not called for the mode's own sets - `SetPlayerStat`, `SetPlayerPerkPoints`, `SetPlayerProgress`,
---`AddPlayerPerk` and the rest - only for what the player's game did, and for what the mode vouches for: under
---`[audit] mode = "enforce"`, an excess the mode vouches for in `OnPlayerProgressViolation` comes here with `levels`
---`true`, so the character is saved with it.
---@param pid number the player
---@param levels boolean `true` when a level, a perk or perk points changed, `false` for XP and the two states alone
function OnPlayerProgressChange(pid, levels) end

---**Called by the server** - The server found progress it cannot explain and is about to put it back - return `false` to vouch for it.
---
---A player's game reported XP, a level, perk points or a perk that nothing the server knows of explains: not what the game
---awarded, not what the mode gave, not a potion or a perk, not the points their levels pay. With `[audit] mode = "enforce"`
---the server is about to put it back; with `observe` it only logs that it would, and asks all the same for XP and levels.
---Nothing reaches the player's game before this returns. It is asked once for each excess, after the server has seen it a
---second time (about a second and a half later), and not again when it repeats. `kind` says what:
---
---- `"xp"` - a stat's or skill's XP, `"level"` - a level that rose with it (an XP or a level the game could never hold is
---  one of these too). Under `enforce` this version puts back a clear rise - 300 XP or more that nothing explains, and over
---  three times what the server explains or three levels or more above it - and only logs a smaller one;
---- `"points"` - perk points the levels do not pay for (asked only where the rule acts: under `enforce`);
---- `"perk"` - a perk bought below the level it needs (`name` is the perk's GUID), or one bought with points nothing paid for
---  (`name` is the stat or skill) - asked under `enforce`, where it is taken back;
---- `"baseline"` - a game that joined with more than a fresh character holds. It is asked in both audit modes; under `enforce`
---  this version puts back a clear excess (as for `"xp"`) and only logs a smaller one; a `false` makes the server take the
---  reported value as the player's own.
---
---`name` is the lower-case stat, skill or perk name (for a perk below its level, the perk's GUID). `reported` is what the player's
---game says and `allowed` what the server can explain: for `"xp"` and `"level"` the XP counted over all the levels together,
---for `"points"` the number of points, for a perk below its level the level it asks and the level the server explains.
---`GetPlayerProgressAudit`'s `gate_down` says the player's game reports its XP counting is not running: with a large excess,
---a trainer's mark the mode may act on itself.
---
---**Return `false` to vouch**: the server takes the reported value as the player's progress, and nothing is put back. That
---is the way for progress the server cannot see being earned - a teacher or trainer the mode runs, an event's reward, and above
---all **quest XP on a server with story quests on**, where the story's quests, lessons and scripts hand out XP and levels the
---server never sees. Without a vouch it is put back like any other excess once the check acts under `enforce`. Return nothing
---(or `true`) to let it be put back. Under `enforce`, a vouch is announced like progress the player's game earned: a level
---that rose reaches `OnPlayerLevelUp` and the change reaches `OnPlayerProgressChange` with `levels` `true`. At most 8 calls
---come in a burst and 30 a minute for one player; past that the excess is put back without asking, so answer from memory,
---never from a database query.
---
---Where the check acts, the record - `GetPlayerStat`, `GetPlayerProgress` and the rest - holds the figure the server
---explains, so a mode that saves characters never saves the forged value, and `OnPlayerLevelUp` never announces a level that
---was put back.
---
---Return value: `false` vouches for it - the server takes the reported value; nothing or `true` lets it be put back
---@param pid number the player
---@param kind string `"xp"`, `"level"`, `"points"`, `"perk"` or `"baseline"`
---@param name string the stat's, skill's or perk's lower-case name
---@param reported number what the player's game says (the XP over all levels together, the number of points)
---@param allowed number what the server can explain, in the same unit
function OnPlayerProgressViolation(pid, kind, name, reported, allowed) end

---Sets a stat of the player's character to a level, and the XP toward the next, exactly.
---
---`stat` is `strength`, `agility`, `vitality`, `speech`, `storyprogress` (the story's progress) or `prestige` (the Blacksmith
---Prestige). A skill's name is refused - use `SetPlayerSkill` - and so is `mainlevel`: the main level is the figure the game
---works out from the other levels, so a mode moves it by setting those and reads it with `GetPlayerLevel`. `level` is
---`0` .. `30` (a fractional one is rounded down), and `xp` the XP already gathered toward the next level (`0` by default, also
---for a missing or non-numeric value). An `xp` at or above what the next level takes is cut to just under it, where the server
---knows that figure: once the player's game has reported the level and this call leaves it as it is. The set is **exact**:
---the level is what it says, a higher one lowered included, and the game shows no level-up notice. The record (`GetPlayerStat`) holds it at once; the main level follows a moment later, and
---`OnPlayerLevelUp` does not announce that rise.
---
---A player who was not set starts as the level's own character (level 5 in the four core stats and in most skills, level 0 in
---the rest), so a mode that wants another start
---sets it - a saved character's at the login with `SetPlayerProgress`, a class's here. Called before the player is in the
---world, the set waits for their spawn and is applied right after it. With `[spawn] stat_level` above `0` the four core
---stats are raised to at least that level at every spawn, so a set below it lasts only until the next one. A hunting bow
---needs strength 13 to be held drawn.
---@param pid number the player
---@param stat string the stat's name
---@param level number `0` .. `30`
---@param xp? number the XP gathered toward the next level
---@return boolean `false` for a name that is no stat (a skill's too, and `mainlevel`), a level that is missing, not a number or outside `0`..`30`, an XP below `0` or infinite, or a player not connected
function SetPlayerStat(pid, stat, level, xp) end

---Sets a skill of the player's character to a level, and the XP toward the next, exactly.
---
---`skill` is one of the game's thirty skills - `marksmanship`, `weapon_sword`, `heavy_weapons`, `horse_riding`, `alchemy`,
---`stealth` ... (Stats and skills); a stat's name is refused - use `SetPlayerStat`.
---Everything else is as there: `level` `0` .. `30`, `xp` gathered toward the next (a missing one is `0`, one at or above what
---the next level takes is cut to just under it), the set exact, lowering too, no level-up notice, waiting for the spawn when
---the player is not in the world yet. `fencing` (Warfare) is the game's parent of the weapon skills and works its level out
---from theirs, so it is refused (`false`, and `AddPlayerSkillXP` too) - set `weapon_sword` and the others instead; its perk
---points are its own (`SetPlayerPerkPoints`).
---@param pid number the player
---@param skill string the skill's name
---@param level number `0` .. `30`
---@param xp? number the XP gathered toward the next level
---@return boolean `false` for a name that is no skill (a stat's too, and `fencing`), a level that is missing, not a number or outside `0`..`30`, an XP below `0` or infinite, or a player not connected
function SetPlayerSkill(pid, skill, level, xp) end

---The level of a stat, as the server last heard or set it.
---
---What the player's game last reported, or what the mode last set - and, where the progression check acts under
---`[audit] mode = "enforce"`, never more than the server can explain. `0` means the server does not know it: the player's
---game has not reported yet (the first report comes a few seconds after the spawn), or the name is no stat. The name
---`mainlevel` answers the main level, as `GetPlayerLevel` does.
---@param pid number the player
---@param stat string the stat's name
---@return number the level, `0` .. `30` (`mainlevel`: the figure the game works out); `0` = not known (not reported yet, a skill's name, or a player not connected)
function GetPlayerStat(pid, stat) end

---The level of a skill, as the server last heard or set it.
---
---What the player's game last reported, or what the mode last set - and, where the progression check acts under
---`[audit] mode = "enforce"`, never more than the server can explain. `0` means the server does not know it: the player's
---game has not reported yet, or the name is no skill.
---@param pid number the player
---@param skill string the skill's name
---@return number `0` .. `30`; `0` = not known (not reported yet, a stat's name, or a player not connected)
function GetPlayerSkill(pid, skill) end

---The player's main level - the level the game shows for the whole character.
---
---The one level the character screen shows for a character, which the game works out itself from the levels of the stats and
---skills: it rises and falls as they do, and no call sets it. This is the level of the player's game as it last reported it
---(`0` until the first report, a few seconds after the spawn). The same figure is `GetPlayerStat` with `mainlevel`.
---`OnPlayerLevelUp` announces a rise the player earns as the stat `mainlevel`.
---@param pid number the player
---@return number the main level; `0` = not reported yet, or a player not connected
function GetPlayerLevel(pid) end

---The XP a stat has gathered toward its next level, and what that level takes.
---@param pid number the player
---@param stat string the stat's name
---@return number xp `xp, next` - the XP gathered toward the next level, and the XP the next level takes in all; `next` is `0` at the top level, `0, 0` when the server does not know the stat yet
---@return number next
function GetPlayerStatXP(pid, stat) end

---The XP a skill has gathered toward its next level, and what that level takes.
---@param pid number the player
---@param skill string the skill's name
---@return number xp `xp, next` - the XP gathered toward the next level, and the XP the next level takes in all; `next` is `0` at the top level, `0, 0` when the server does not know the skill yet
---@return number next
function GetPlayerSkillXP(pid, skill) end

---Gives a stat XP the game's own way.
---
---As if the character had earned it: the bar fills, and a level it reaches shows the game's level-up notice and brings the
---perk points that level carries. `xp` is above `0` and at most `100000`. It only ever raises (lower a level with
---`SetPlayerStat`), and it is the mode's own giving, so it does not pass the XP rate (`SetXPRate`) or
---`OnPlayerGainXP`. The record follows with the player's next report: `GetPlayerStat` right after still shows the old
---level, and a level earned this way arrives as `OnPlayerLevelUp` like any other. Called before the player is in the world,
---it is given right after their spawn. The main level (`mainlevel`) has no XP of its own - it rises with the other levels - and
---is refused.
---@param pid number the player
---@param stat string the stat's name
---@param xp number above `0`, at most `100000`
---@return boolean `false` for a name that is no stat (a skill's too, and `mainlevel`), an amount outside that, or a player not connected
function AddPlayerStatXP(pid, stat, xp) end

---Gives a skill XP the game's own way.
---
---The same as `AddPlayerStatXP` for a skill: the bar fills, a level reached shows the level-up notice and brings its perk
---points, `xp` is above `0` and at most `100000`, the XP rate and `OnPlayerGainXP` are not asked, and the record follows
---with the player's next report. `fencing` (Warfare) is refused: the game works its level out from the weapon skills, so give
---XP to those.
---@param pid number the player
---@param skill string the skill's name
---@param xp number above `0`, at most `100000`
---@return boolean `false` for a name that is no skill (a stat's too, and `fencing`), an amount outside that, or a player not connected
function AddPlayerSkillXP(pid, skill, xp) end

---The perk points a stat, a skill or the main level has not spent yet.
---
---Every stat and skill holds the perk points the game gave it and the player has not spent yet. The name `mainlevel` is the
---main level's **pool**: the points that belong to no stat or skill. They are the player's game's own counts, as it last
---reported them or the mode last set them (`SetPlayerPerkPoints`). `0` means none - or that the server does not know yet:
---the player's game has not reported, or the name is neither a stat nor a skill.
---@param pid number the player
---@param name string a stat's or skill's name, or `mainlevel` for the pool
---@return number `0` .. `999`; `0` = none, or not known (not reported yet, an unknown name, or a player not connected)
function GetPlayerPerkPoints(pid, name) end

---Sets the perk points a stat, a skill or the main level has not spent yet.
---
---`name` is a stat's or skill's name, or `mainlevel` for the main level's pool (the points that belong to no stat or skill);
---`points` is `0` .. `999`. The count is what it says - a smaller one takes points away - and the **level is left as it
---is**. The player's game puts the points on the character, and the record (`GetPlayerPerkPoints`) holds them at once.
---Called before the player is in the world, the set waits for their spawn and is applied right after it, in the order it
---was made.
---
---`SetPlayerProgress` sets the points too, together with the levels; this is the call for the points alone (`SetPlayerStat`
---and `SetPlayerSkill` leave them). Like the other sets it does not reach `OnPlayerProgressChange`, which is for what the
---player's game did.
---@param pid number the player
---@param name string a stat's or skill's name, or `mainlevel` for the pool
---@param points number `0` .. `999`
---@return boolean `false` for a name that is neither a stat nor a skill, a number outside `0`..`999`, or a player not connected
function SetPlayerPerkPoints(pid, name, points) end

---The perks the player's character holds.
---
---A list of perk GUIDs (lower case, with dashes), as the player's game last reported them and the mode last changed them;
---empty until the game has reported. `GetPerkName` turns one into its English name, and the perks list
---has them all.
---@param pid number the player
---@return table a list of perk GUIDs; `{}` for none, or for a player not connected
function GetPlayerPerks(pid) end

---Whether the player's character holds a perk.
---@param pid number the player
---@param perk string a perk GUID, or its name or English name when the server has the game's tables export
---@return boolean `false` for a perk the character lacks, a name the server cannot resolve, or a player not connected
function HasPlayerPerk(pid, perk) end

---Gives the player's character a perk.
---
---`perk` is the perk's GUID, or - when the server has the game's tables export (Exporting the
---game's tables) - its name or its English name, as the perks list spells them, in any case. The record
---holds it at once. A perk the mode gives costs the character no perk point and, like every order of the mode's, counts as theirs
---from the moment it is sent: the progression check takes nothing back for it. Giving a perk the character already holds is fine. Called before the player is in the world, the perk
---is given right after their spawn.
---@param pid number the player
---@param perk string a perk GUID, or its name or English name
---@return boolean `false` for a name the server cannot resolve (a GUID always passes), or a player not connected
function AddPlayerPerk(pid, perk) end

---Takes a perk from the player's character.
---
---`perk` as for `AddPlayerPerk`. Taking a perk the character does not hold is fine.
---@param pid number the player
---@param perk string a perk GUID, or its name or English name
---@return boolean `false` for a name the server cannot resolve (a GUID always passes), or a player not connected
function RemovePlayerPerk(pid, perk) end

---The English name of a perk.
---
---`perk` is a GUID or the game's name for the perk. The names come with the game's tables export
---(Exporting the game's tables); without it - or for a GUID the export does not list - the
---answer is `nil`.
---@param perk string a perk GUID or name
---@return string|nil the English name; `nil` when the server has none
function GetPerkName(perk) end

---How well fed the player's character is.
---
---The character's nourishment (food) in the game's own scale and the most it can hold, as the player's game last reported
---them - and, under `[audit] mode = "enforce"`, never above the game's own maximum of 150, since a value over it is put back.
---The game runs it down as the character goes about and up as they eat. After a `SetPlayerNourishment` made before the
---player's game has reported, the value is the one set and the maximum is `0` until the first report - check `max` before
---you divide by it.
---@param pid number the player
---@return number|nil value `value, max` - the nourishment and its maximum, which is `0` while only the mode's own set is known; `nil` until the player's game has reported or the mode has set it, or for a player not connected
---@return number|nil max
function GetPlayerNourishment(pid) end

---Sets how well fed the player's character is.
---
---`value` is `0` or more, clamped to the maximum once the server knows it (`GetPlayerNourishment` gives both) - and, under
---`[audit] mode = "enforce"`, to the game's own maximum of 150 whatever their game reported, since no honest set goes higher
---(`observe` leaves the mode's own value as it is); the game runs it on from there. A set of the mode's own voids the
---nourishment check's stretch of judging for that value, so setting it never reads as a trainer. Called before the player is in
---the world, it is applied right after their spawn.
---@param pid number the player
---@param value number the nourishment, `0` or more
---@return boolean `false` for a value below `0` or not a number, or a player not connected
function SetPlayerNourishment(pid, value) end

---How rested the player's character is.
---
---The character's energy (the Rest) in the game's own scale and the most it can hold, as the player's game last reported
---them - and, under `[audit] mode = "enforce"`, never above the game's own maximum of 100, since a value over it is put back.
---The game runs it down as the character stays awake and up as they sleep. After a `SetPlayerEnergy` made before the
---player's game has reported, the value is the one set and the maximum is `0` until the first report - check `max` before
---you divide by it.
---@param pid number the player
---@return number|nil value `value, max` - the energy and its maximum, which is `0` while only the mode's own set is known; `nil` until the player's game has reported or the mode has set it, or for a player not connected
---@return number|nil max
function GetPlayerEnergy(pid) end

---Sets how rested the player's character is.
---
---`value` is `0` or more, clamped to the maximum once the server knows it (`GetPlayerEnergy` gives both) - and, under
---`[audit] mode = "enforce"`, to the game's own maximum of 100 whatever their game reported (`observe` leaves the mode's own
---value as it is); the game runs it on from there. A set of the mode's own voids the energy check's stretch of judging for that
---value, so setting it never reads as a trainer. Called before the player is in the world, it is applied right after their
---spawn.
---@param pid number the player
---@param value number the energy, `0` or more
---@return boolean `false` for a value below `0` or not a number, or a player not connected
function SetPlayerEnergy(pid, value) end

---Everything a mode saves with a character - stats, skills, perk points, perks, nourishment and energy.
---
---One table:
---
---- `stats` and `skills` - `{strength = {level = 12, xp = 340.5, next = 620, points = 2}, ...}`, one entry for each the
---  server knows. `level` is the level, `xp` the XP gathered toward the next level, `next` the XP the next level takes in all
---  (`0` at the top level, or before the game has reported it) and `points` the perk points not spent yet (`0` for none);
---- `stats.mainlevel` - the main level, among the stats: `level` is the figure the game works out from the other levels, `xp`
---  and `next` are `0` (it gathers no XP) and `points` is the pool of perk points that belong to no stat or skill;
---- `perks` - a list of perk GUIDs;
---- `nourishment` and `energy` - numbers, or absent (`nil`) until the player's game has reported them.
---
---`SetPlayerProgress` takes the same shape back. A player whose game has not reported yet gives empty `stats` and
---`skills` and no `perks`: **never save that over a stored character** - wait for `OnPlayerProgressChange`'s first call,
---and for a character you restored, for the restore itself. The table is a copy; changing it changes nothing.
---@param pid number the player
---@return table|nil `{stats, skills, perks, nourishment, energy}`, every stat and skill `{level, xp, next, points}`; `nil` for a player not connected
function GetPlayerProgress(pid) end

---Puts a saved progression back on the player's character - a whole restore.
---
---`progress` has the shape `GetPlayerProgress` returns, and every part of it is optional: a part left out is left alone.
---
---- `stats` and `skills` - each value is a level (`12`) or `{level = 12, xp = 340.5, points = 2}`; every one is an exact set,
---  as `SetPlayerStat` and `SetPlayerSkill` make it, lowering too. `points` are the perk points not spent yet, set
---  exactly as `SetPlayerPerkPoints` sets them - none counts as `0`, so the points a fresh character starts with never
---  outlive the restore of one who had spent theirs. A name the server does not know, an entry without a `level`, a `level`
---  outside `0` .. `30`, an `xp` below `0` or `points` above `999` skips the whole entry, which is logged. `warfare`
---  follows the weapon skills: only its `points` are put back.
---- `stats.mainlevel` - the main level is the game's to work out, so only its `points`, the pool of perk points that
---  belong to no stat or skill, are put back; whatever `level` the entry holds is ignored. Restoring the stats and skills
---  moves the main level by itself.
---- `perks` - a list of GUIDs (or names): when it is there, the character ends up with exactly those perks, `{}` meaning
---  none (with the caveat below). Every player is given the perfect block, the riposte and the master strikes when they
---  first spawn, and the list `GetPlayerProgress` returns holds them; a list of the mode's own takes them away unless it
---  names them too.
---- `nourishment` and `energy` - numbers, as `SetPlayerNourishment` and `SetPlayerEnergy` take them.
---
---The restore belongs at the login, before the player's first spawn: the orders wait for the spawn and go out right after it,
---in order. The perks the character holds beyond the list are taken away only once the server has heard which perks they
---hold (the player's game reports them after the spawn); a restore at the login therefore adds the missing ones, and a
---second call after `OnPlayerProgressChange`'s first one makes the list exact.
---@param pid number the player
---@param progress table `{stats = {...}, skills = {...}, perks = {...}, nourishment = n, energy = n}`, a stat or skill `level` or `{level, xp, points}`
---@return boolean `false` for an argument that is no table, or a player not connected
function SetPlayerProgress(pid, progress) end

---What the server judges the player carries, the most they may carry, and whether that is too much.
---
---The carry-weight check's own figures, worked out from the list of items the server follows in the player's bag and the
---weights of the game's item list, and never from the weight figure their game shows. `carried` is the weight of that bag -
---what they wear counts, as it does for the game; the money and any item the game's list gives no weight are left out, so it
---is meant to be at or under the game's own figure - and `capacity` the most the game lets a character carry as the server can
---bound it: 90 and 10 for each point of strength the server holds for them, with the perks, the strength potions and the
---drinks it knows of (a drink lifts a player's strength for a while, and the server allows for that for at least ten minutes after
---the drink; a lower capacity from the player's game counts when it is recent and plausible, a higher one never does).
---`overloaded` is `true` once they have carried more than 105 % of that for three seconds, and `false` again after a
---second and a half under it; it is `false` while the check is not judging them - dead, flying, on a cart, at a dice table,
---while their game's reports of its items have stopped or stalled, while their game says its item reporting cannot run
---(under `[audit] mode = "observe"`), and while the server has given them the game's debug buff that lifts the carry
---capacity by 1000 (`GivePlayerBuff`).
---
---**Nothing is ever taken from a heavy player.** The game itself only holds them back - it refuses a sprint and getting on a
---horse, and lets them jump, so a jump is never held against them - and the check watches whether a player over the limit
---sprints or mounts a horse; a trainer that hides the weight still carries it. In this version those checks are counted and
---logged only: they pull nobody back and the `weight` hint is not told to `OnPlayerCheatDetected` yet. The answer is `nil`
---while the server cannot tell: before the player is in the world, before the player's first whole report of their
---progression (a few seconds after the spawn) and before it follows their bag (which waits for the spawn's clearing of the
---character's starting items too), with the audit off, and without the game's tables export
---(Exporting the game's tables), whose item list holds the weights.
---@param pid number the player
---@return number|nil carried `carried, capacity, overloaded` - the weight, the most the server judges they may carry and whether they carry more; `nil` while the server cannot tell, or for a player who is not there
---@return number|nil capacity
---@return boolean|nil overloaded
function GetPlayerWeight(pid) end

---What the progression check counted for the player this session.
---
---A table of counts, for a mode's own rules and for a status page, since the player joined:
---
---- `excesses` - the rises of XP, levels, perk points or perks the server could not explain;
---- `set_backs` - how many of them it put back (under `observe`, how many it logged that it would put back);
---- `vouched` - how many `OnPlayerProgressViolation` vouched for;
---- `rewrites` - the times the player's game wrote the same forged value back after it was put back;
---- `probes` - how often the server asked the player's game for a fresh report to be sure;
---- `stale_reports` - the reports it dropped as older than its newest order;
---- `gate_down` - the player's game says its own XP counting is not running, so the awards it makes cannot be seen
---  (everything the player earns is then an excess once the XP rule acts);
---- `first_session` - the player's game says this is the first session of this run of the game, so it came fresh from the menu.
---
---`nil` for a player who is not there.
---@param pid number the player
---@return table|nil `{excesses, set_backs, vouched, rewrites, probes, stale_reports, gate_down, first_session}`; `nil` for a player not connected
function GetPlayerProgressAudit(pid) end

---Sets how much of the XP the game awards on its own the players gain.
---
---The game awards XP by itself - a kill, a hit, a distance walked, a book read - and the server gives **none of it** unless a
---mode says so: the rate is `0` when the server starts. `rate` is a multiplier: `1` is the game's own amounts, `2` double,
---`0.5` half, `0` none, up to `100`. It applies to every player now and to everyone who joins, except a player with a rate of
---their own (`SetPlayerXPRate`). Set it in `OnGameModeInit`.
---
---It governs only the awards the game makes. XP the mode hands out (`AddPlayerStatXP`, `AddPlayerSkillXP`) and the
---levels it sets are unaffected. With `OnPlayerGainXP` defined every award reaches it already multiplied by the rate; at
---`0` none does.
---@param rate number `0` .. `100`; `1` = the game's own
---@return boolean `false` for a rate outside `0`..`100` or not a number
function SetXPRate(rate) end

---The server-wide XP rate.
---@return number the rate `SetXPRate` set; `0` until a mode sets one
function GetXPRate() end

---Gives one player an XP rate of their own, over the server-wide one.
---
---The same multiplier as `SetXPRate`, for this player alone: `0` .. `100`. `nil` takes the override away and the player
---follows the server-wide rate again. It lasts until the player leaves.
---@param pid number the player
---@param rate number|nil `0` .. `100`; `nil` = follow the server-wide rate
---@return boolean `false` for a rate outside `0`..`100`, or a player not connected
function SetPlayerXPRate(pid, rate) end

---The XP rate that applies to a player.
---@param pid number the player
---@return number the player's own rate, else the server-wide one; `0` for a player not connected
function GetPlayerXPRate(pid) end

-- ======== Buffs and the drink ===================================================
-- A **buff** is the game's own timed or permanent modifier on a character - a potion's effect, an injury, drunkenness, a perk's
-- bonus. The server gives and takes them by **id, name or GUID** from the buff list; the player's client
-- adds the game's buff once and removes it by GUID. The server also keeps a **blood-alcohol level** per player from the drinks
-- their game consumed, and judges when they are drunk. A player's game consuming anything - a potion, food, an ointment - goes
-- through the server (`OnPlayerUseItem`), which applies the tables' effect (Consumables).

---**Called by the server** - The player's game used an item - a potion, food, a book, a letter, a map; return `false` to cancel its effect, or (for a checked item) the use itself.
---
---A potion drunk, food eaten, an ointment applied - and a book read, a letter or a map opened, a recipe learned: every use the
---player's inventory makes comes here (a repair kit's repair is no use: `OnPlayerItemWear` hears it). For a consumable the
---server looked the class up in the game's tables
---(Consumables) and is about to add `health` to its own vitals (a potion's heal-over-time runs at
---`[combat] potion_speed` times the game's pace) and give the buff `buff` (`GivePlayerBuff`). Return `false` to cancel both
---- the item is gone from the player's inventory either way, their game consumed it. Anything else (a book, a letter, a map)
---comes with `health` 0 and no buff, after the game used it - its `false` changes nothing.
---
---**Deciding before the use.** For an item class or category named with `SetItemUseCheck` this comes *before* the game uses
---the item: the player's game holds the use and waits, and `false` refuses it - the book stays shut, the bread uneaten, the item
---where it was. Anything else lets the game use it (and the server's effect follows without a second call). Tell the player
---why yourself (`ShowNotification`, `SendClientMessage`).
---
---A use of an item the server's records say the player never held - or any use in the first seconds of a visit, before the
---server follows the player's bag - is refused first under `[audit] mode = "enforce"` (`observe` only logs that it would be).
---Food eaten from a cooking pot or a table is no item of the bag: the server takes it as food from the world, at most 50 health a
---minute and never a buff. A drink raises the alcohol level on the side (`OnPlayerDrunk`).
---
---Return value: `false` cancels the health and the buff - and, for a checked item, the use itself; anything else lets them through
---@param pid number the player
---@param class string the item's class GUID (`GetItemName` turns it into a name)
---@param health number the health the server is about to add (a negative number hurts); 0 for anything that is no consumable
---@param buff string the buff GUID the server is about to give; `""` = none
---@param id string the item's id when it is one of the mode's tagged items (`GivePlayerTaggedItem`), `""` otherwise
function OnPlayerUseItem(pid, class, health, buff, id) end

---**Called by the server** - The player got drunk, or sobered up.
---
---`true` when the blood-alcohol level crossed `[combat] drunk_threshold` upwards (the game's drunkenness is on, the others see
---the body sway); `false` when it fell back under half of it (the hangover follows for `[combat] hangover_seconds`).
---@param pid number the player
---@param drunk boolean `true` = drunk now, `false` = sober again
function OnPlayerDrunk(pid, drunk) end

---Gives the player a buff of the game's tables.
---
---`buff` is a key of the buff list: the id, the name (`well_rested`, case-insensitive) or the GUID.
---The player's client adds the game's buff once; the record lasts until `RemovePlayerBuff`, the `seconds` given, `HealPlayer`
---or the respawn. `seconds` is the server's own clock - `0` or none means no clock; the game's own duration (the list's
---`duration` column, in game minutes) may end a timed buff's *visible* effect earlier, and the server does not re-apply it.
---`false` for an unknown key or a player not in the world.
---@param pid number the player
---@param buff string|number the buff's name, id or GUID
---@param seconds? number take it back after this long; `0` or none = keep it
---@return boolean `true` when given
function GivePlayerBuff(pid, buff, seconds) end

---Takes a buff off the player.
---
---Removes the server's record and every copy of the buff on the player's character, including ones the game gave by itself.
---@param pid number the player
---@param buff string|number the buff's name, id or GUID
---@return boolean `true` when the key resolved and the player is connected
function RemovePlayerBuff(pid, buff) end

---Whether the server gave the player this buff and has not taken it back.
---@param pid number the player
---@param buff string|number the buff's name, id or GUID
---@return boolean
function HasPlayerBuff(pid, buff) end

---The buffs the server gave the player, as GUIDs.
---@param pid number the player
---@return table a list of buff GUIDs; `{}` when none
function GetPlayerBuffs(pid) end

---Takes every server-given buff off the player.
---@param pid number the player
function ClearPlayerBuffs(pid) end

---The buff classes the server has claimed.
---
---A claimed class is one the server takes over: every client undoes the game's own application of any buff of that class
---unless the server gave it. `[combat] claimed_buffs` sets the list at startup; `ClaimBuffClasses` changes it.
---@return table a list of class names (`"Potion"`, `"Poison"` ...); `{}` when nothing is claimed
function GetClaimedBuffClasses() end

---Names the buff classes the server takes over from the game.
---
---With a class claimed, a buff of that class a player's game applies by itself - a potion drunk, a poison, the game's own
---drunkenness - is undone on their client within a second unless the server gave it (`GivePlayerBuff`). The way a mode keeps
---the game's own potions from opening a hole in the server-owned health: with `Potion` claimed, a potion only works through the
---server's consumption path. The class names are the pages of the buff list -
---`Potion`, `Poison`, `Alcohol`, `Hangover`, `Unconsciousness`, `Plague` ...; an unknown one is logged and ignored. The whole
---list replaces the previous one and goes to every client; `{}` claims nothing. Nothing is claimed by default.
---@param classes table a list of class names
function ClaimBuffClasses(classes) end

---The player's blood-alcohol level, 0 to 1.
---
---Each drink adds its alcohol content × `[combat] alcohol_per_content`; time takes `[combat] alcohol_decay` off per second.
---Drunk from `[combat] drunk_threshold` up, sober again from half of it down (`OnPlayerDrunk`).
---@param pid number the player
---@return number `0` .. `1`
function GetPlayerAlcohol(pid) end

---Whether the player is drunk.
---@param pid number the player
---@return boolean
function IsPlayerDrunk(pid) end

---Sets the player's blood-alcohol level; the drunk state is judged at once.
---
---Above the threshold the player is drunk on the spot - the game's drunkenness buff on their character, the sway on the
---others' screens, `OnPlayerDrunk(pid, true)`; `0` sobers them (the hangover follows as after a real night).
---@param pid number the player
---@param level number `0` .. `1`
function SetPlayerAlcohol(pid, level) end

-- ======== Items and inventory ===================================================
-- What a player carries, what the server gives them, and the pickups lying in the world. An item is named by any key of
-- the item catalogue - the id, the game's name, the English name or the class GUID; the client reports
-- equipment and inventory as class GUIDs (`GetItemName` turns one into a name).
-- 
-- **The server keeps the books.** Every item a player carries has to be explained by a record the server holds: what it gave
-- (`GivePlayerItem`, `SetPlayerInventory`, the spawn outfit), a pickup it placed, a take from a chest or a body, a shop, a drop
-- picked up again, the game's own making (`OnPlayerNativeItem`). The player's game reports each change with where the item
-- came from, and the server checks it against the records - under `[audit] mode = "enforce"` an item nothing explains is taken
-- out of the player's game, and a drop, a use, a shot or a sale of more than the records explain is refused
-- (the configuration has what each mode does). The functions below read and
-- write those records, not the game's own list: **what a mode gives or takes is in the records at once** - a
-- `GetPlayerInventory` right after a `GivePlayerItem` already shows the item, and a `SetPlayerInventory` called twice orders
-- nothing twice - while the player's game carries the order out a moment later. Under `observe` the readers show what the player's
-- game holds (the mode's own gives and takes on their way counted), so an item a cheat tool conjured is visible there too.

---**Called by the server** - What the player carries or their purse changed - the moment to save it.
---
---What the server's records hold of the player's bag or purse changed: an item picked up, dropped, put in a chest, bought,
---eaten or sold, a Groschen spent, what they wear, an item the mode gave or took (`GivePlayerItem`, `SetPlayerInventory` -
---the gives and takes still on their way count, so this runs when the mode orders the change, not when the player's game has
---done it), an item's condition or quality (a sword forged at the anvil comes with its quality a moment after it is made), a
---tagged item's name, text, weight or price (`SetPlayerItemTag`, `SetPlayerItemWeight`,
---`SetPlayerItemPrice`) - at most once a second for one player. Read the new state with `GetPlayerInventory` and `GetPlayerMoney`. A mode
---that keeps what players carry saves here: what a player hands to a chest, the ground or a shop is the server's at once, so
---saving on a timer alone leaves a window in which a crash gives the item back twice. Their horse's saddlebags are
---`OnHorseItemsChange`'s.
---@param pid number the player
function OnPlayerInventoryChange(pid) end

---**Called by the server** - The player's outfits changed - the moment to save them.
---
---The game keeps three **outfits** (the inventory's flags A, B and C): each one the clothing, armour and weapons it wears, and
---the player switches between them. The player's game reports them when they change - an outfit put together or changed, a
---switch to another - and this runs once the server has the new state; read it with `GetPlayerOutfits`. The game keeps an
---outfit as the items themselves and a login makes every item anew, so only the outfit the bag's restore dressed comes back
---unless the mode saves them and hands them back with `SetPlayerOutfits`. Not for the mode's own `SetPlayerOutfits`.
---@param pid number the player
function OnPlayerOutfitChange(pid) end

---**Called by the server** - The player picked a pickup up - return `false` to take it back.
---
---The player's client already holds the item when this runs. The server first checks the claim against its own record of the
---pickup: it must still be there, in the player's view and in their world, within about eight metres of them, and nobody
---may have taken it first - a claim that fails any of these (or that the mode refuses here) has its item taken out of
---the player's game at once, in every `[audit]` mode. Return `false` and the item goes back the same way and the pickup stays in
---the world for everyone. Otherwise the pickup is gone for everyone and the item is the player's - the item check counts it as
---explained. A mode that refuses the pickup to give the item itself reads `GetPickupHealth` and `GetPickupQuality` first and
---passes both to `GivePlayerItem`, or the item comes new and at its class's own quality.
---
---Return value: `false` refuses the pickup; anything else lets them keep it
---@param pid number the player
---@param id number the pickup entity (`GetEntityTemplate` is its class GUID)
function OnPlayerPickup(pid, id) end

---**Called by the server** - The player dropped an item and the world made a pickup of it.
---
---The player's own game dropped the item; the server made pickup `id` of it so everyone sees it lying there and anyone may take
---it. Nothing to veto - the dropper's screen already shows it; a mode that wants it gone calls `DestroyEntity`. A drop the
---server refuses makes no pickup and this does not run: a dead player's, one farther than six metres from where the player is,
---an item class the server cannot read, a flood of drops (more than four seconds' worth waiting), a drop while the world is full
---(`[world] max_entities`), and - under `[audit] mode = "enforce"` - more than the records explain, or one in the first seconds
---of a visit. The item then lies on the dropper's screen alone, and taking it back is no violation. A stack the records explain
---only in part becomes a pickup of that part.
---
---A player's pickups are made one per quarter of a second at most: a drop that comes sooner (two items dropped at once) waits
---its turn, so this can run a moment after the drop itself. A drop its dropper takes back before its turn never becomes a
---pickup and this does not run; a player who leaves with drops still waiting gets them made at once, before
---`OnPlayerDisconnect`.
---@param pid number the player
---@param id number the new pickup entity
function OnPlayerDrop(pid, id) end

---**Called by the server** - One of the player's items wore down or was mended.
---
---The player's game changed the condition of an item in their bag by at least a whole percent: a blow, a block or a shot wore
---it (`after` is lower), or a smith, a whetstone or a repair kit mended it (`after` is higher). Both are the percent the game's
---inventory shows, 0..100 (`GetPlayerItemHealth`). How
---fast items wear at all is `SetItemWear`'s; this is where a mode decides about one change: return nothing to let it be,
---`false` to keep the item as it was (their game is set back), or a number to set the condition to (their game is set to it).
---An item that arrives (a give, a pickup, a chest's) and the mode's own `SetPlayerItemHealth` are no wear and do not come
---here; nor does a horse's saddlebags' item. A worn piece's new condition reaches the other players' screens with it, at most
---once a second.
---
---**Repair kits.** A kit's repair comes here twice: the repaired item's mend (`after` higher) and the kit's own loss - a kit's
---charge is its condition (its category is `"Ointment"`). To undo a repair, keep both: `false` for the item's
---mend and for the kit's loss. The grindstone's sharpening is a mend too.
---
---Return value: `nil` to let it be, `false` to keep `before`, or a number - the condition the item should have
---@param pid number the player
---@param class string the item class GUID
---@param before number the condition before, 0..100
---@param after number the condition their game holds now, 0..100
function OnPlayerItemWear(pid, class, before, after) end

---**Called by the server** - The player started a crafting station - the alchemy table, the anvil or the grindstone.
---
---`station` is `"alchemy"` (the alchemy table), `"smithing"` (the anvil) or `"sharpening"` (the grindstone - `class` is the
---weapon the player chose to sharpen; `""` for the others). For a station named with `SetCraftCheck` this comes **before** the
---station starts: the player's game waits for the answer, and `false` keeps the station from starting - nothing is used, no
---ingredient and no time. Without `SetCraftCheck` it comes after the start and its answer changes nothing.
---
---What a station makes is the game's own work: a potion, a sword, a horseshoe reach `OnPlayerNativeItem` as the player's game
---makes them (`craft` for the alchemy table, `unmapped` for the anvil), where the mode adopts them or has them removed; a forged
---item's quality is in `GetPlayerInventory` (`quality`) once the player's game has said it, and `OnPlayerInventoryChange`
---follows - save it there; the grindstone's sharpening is a mend (`OnPlayerItemWear`). The repair kits (the sewing kit too) are no station: a kit's repair
---comes to `OnPlayerItemWear` as the item's mend and the kit's spent charge.
---
---Return value: `false` keeps a checked station from starting; anything else lets it start
---@param pid number the player
---@param station string `"alchemy"`, `"smithing"` or `"sharpening"`
---@param class string the weapon's class GUID at the grindstone, `""` otherwise
function OnPlayerCraft(pid, station, class) end

---What the player wears and holds - clothing, armour, the weapons in the slots.
---
---Class GUIDs. Once the server follows the player's items - a moment after the spawn - this is derived from the item records:
---what their game marks as worn or equipped, and under `[audit] mode = "enforce"` only classes the records hold one of, so a
---sword conjured into a hand is no weapon of record. A hint from their game that arrives before then is ignored, so the list is
---empty for a new player; for a player whose items the server cannot judge (no tables export), it is what their game reports.
---The damage model reads the armour from here;
---`GetPlayerWeapon` names the weapon it charges the hits to.
---@param pid number the player
---@return table a list of item class GUIDs; `{}` before the first report
function GetPlayerEquipment(pid) end

---The player's whole inventory as the server's records hold it.
---
---One entry per stack: the class GUID, how many, and the items' **condition** in percent (`health`: 0 = broken, 100 = new;
---items of one class in different conditions come as one entry per condition). Every piece the player wears
---(`GetPlayerEquipment`) comes as an entry of its own with `amount = 1`, `worn = true` and its own condition - so the list
---handed to `SetPlayerInventory` later dresses them the same and restores how worn each piece was. The player's game reports
---every whole percent its items wear or are mended (`OnPlayerItemWear`). It is what the server accepted as the player's - plus the gives
---still on their way, less the takes on theirs - so a `GivePlayerItem` or `SetPlayerInventory` of the mode's own shows
---here at once, a save in the middle of a restore writes the bag the mode meant, and an item a cheat tool conjured is not in it
---under `enforce`. Under `observe` it is what the player's game holds. `{}` before the player's items are known - a moment
---after the spawn. **The money is not in the list**: the purse is `GetPlayerMoney`'s, and a horse's saddlebags are
---`GetHorseItems`'s. Each of the mode's **tagged items** (`GivePlayerTaggedItem`) comes as an entry of its own with
---`amount = 1` and its `id`, `name` and `text` - and its own `weight` and `price` when it has them (`SetPlayerItemWeight`,
---`SetPlayerItemPrice`) - save them with the rest and `SetPlayerInventory` gives the same items back.
---
---An entry's **`quality`** is its items' quality as the game shows it: `1` to `4` (I to IV; a masterwork forged at the anvil is
---the best its class can be). Items of one class at different qualities come as one entry per quality. It is left out (`nil`)
---while the player's game has not said it - a moment after an item arrives - and for an item the game keeps at its class's own
---quality. Save it with the rest: `SetPlayerInventory` makes the items at it again.
---@param pid number the player
---@return table a list of `{class=, amount=, health=, quality=, worn=}` (`quality` when known; `worn` only on what they wear; `id`, `name`, `text`, `weight`, `price`, `model` on a tagged item)
function GetPlayerInventory(pid) end

---Makes the player's inventory exactly this list - taking what they hold beyond it and giving what they miss.
---
---Compared by item class with what the server's records hold (`GetPlayerInventory`, the gives and takes still on their way
---counted): a class they hold more of than the list says is taken down to the list's number, a class they hold less of is
---given up to it, a class the list does not name is taken whole. A class is any key of
---the item catalogue; an unknown one is logged and skipped. **The money stays** - the purse is
---`GivePlayerMoney`'s. Everything moves by the same road as `GivePlayerItem`: what is given is the server's record from
---this moment and counts as the character's the moment it is given, though the player's game makes it a moment later (an
---item that was saved but is no longer in the game is dropped from the records after half an hour, never reported made), and
---what is taken is an exact order the game carries out. An entry's `health` is the condition its items should have (0..100,
---`100` when left out): a missing item is made at it, and an item they already hold is set to it. Its `quality` (1..4, left out =
---the class's own) is the same: a missing item is made at that quality, one they hold is set to it. An entry with `worn = true` is
---put on (given first when they miss it; nothing happens when they wear one of the class already). Nothing is taken off: what they
---wear and the list keeps stays on, and what the list leaves out goes (the game takes it off them). Called twice before the
---first call's orders are done, it orders nothing twice, so it is safe at any moment - a spawn, a death, a login - and the
---restore of a saved character may follow it with `GetPlayerInventory` and save at once. The log says
---`SetPlayerInventory: N given, M taken`. An entry with an `id` is one of the mode's **tagged items**
---(`GivePlayerTaggedItem`): one they hold with that id is kept (its `name` and `text` updated), a missing one is made with
---its tag, and a tagged item they hold whose id the list does not name is taken - that exact item.
---@param pid number the player
---@param items table a list of `{class=, amount=, health=, quality=, worn=}` (`amount` 1 and `health` 100 when left out, `quality` the class's own, `worn` to put it on; `id`, `name`, `text` for a tagged item), as `GetPlayerInventory` returns it
---@return boolean `false` when not connected
function SetPlayerInventory(pid, items) end

---Takes every item the player holds - or all but what they wear.
---
---`SetPlayerInventory` with an empty list: everything the records hold of the player's bag is taken. With `keepWorn` the
---clothing, armour and weapons they wear (`GetPlayerEquipment`) stay on them and only the rest goes. **The money stays** -
---take it with `GivePlayerMoney` (`GivePlayerMoney(pid, -GetPlayerMoney(pid))`).
---@param pid number the player
---@param keepWorn? boolean `true` leaves what they wear on them
---@return boolean `false` when not connected
function EmptyPlayerInventory(pid, keepWorn) end

---The player's three outfits - what each one wears and which one they wear now.
---
---The game's outfits (the inventory's flags A, B and C) as the player's game last reported them, or as the mode last set them
---with `SetPlayerOutfits`: `current` is the one they wear (`1`, `2` or `3`) and `[1]`, `[2]`, `[3]` the item class GUIDs each
---one wears - clothing, armour and the weapons of its weapon sets - one entry per item (a class twice for two of it). An outfit the
---player never put together is an empty list. `nil` before the player's game reported them, a few seconds after the spawn.
---@param pid number the player
---@return table or `nil` - `{current = 1..3, [1] = {class, ...}, [2] = {...}, [3] = {...}}`
function GetPlayerOutfits(pid) end

---Hands the player's three outfits back - after the bag's restore, at a login.
---
---The table `GetPlayerOutfits` returns, saved with the character. Call it **after** `SetPlayerInventory`: the player's game
---waits until the bag's restore has settled, then dresses the `current` outfit again out of what the player carries - a class
---they no longer carry is left out of it - and each of the other two the first time the player switches to it; until then its
---reports carry those two as you set them, so a player who logs out without opening them keeps them. The result is reported
---(`OnPlayerOutfitChange` follows when it differs from the set). Called before the player is in the world, it goes out right
---after their spawn. What the player's game reported before it carried the set out is not taken, so the fresh game's empty
---outfits never overwrite it. A class is any key of the item catalogue.
---@param pid number the player
---@param outfits table `{current = 1..3, [1] = {class, ...}, [2] = {...}, [3] = {...}}`, at most 64 items an outfit
---@return boolean `false` when not connected or the table is not three outfits with `current` 1..3
function SetPlayerOutfits(pid, outfits) end

---Puts items in the player's inventory - or takes them out.
---
---`amount` (default `1`) of the item; a **negative** amount takes that many away (never more than the records hold, the ones
---they do not wear first). `item` is any key of the item catalogue: the id, the game's name
---(`shortswordBroad`), the English name (`Duelling longsword`) or the class GUID; an unknown key is logged and nothing
---happens. A gift is a record of the server's: the item counts as the player's the moment it is given, their game makes it a
---moment later and tells the server, and the item check never sees it as unexplained. A take is an exact order the player's
---game carries out - an item they carry in a hand or wear is released first. The `/give` built-in is the same call.
---@param pid number the player
---@param item string|number the item's name, id, English name or GUID
---@param amount? number how many (`1`); negative takes
---@param health? number the condition the items are made at, 0..100 (`100`, new)
---@param quality? number the quality the items are made at, 1..4 (I..IV; left out = the class's own - a quality past what the class can be is its best)
---@return boolean `false` when not connected
function GivePlayerItem(pid, item, amount, health, quality) end

---The condition of the player's item of a class.
---
---In percent: 0 = broken, 100 = new. When they carry several items of the class, the one they wear answers first, else the one
---they have had longest. The condition is the server's record: their game reports every whole percent its items wear or are
---mended, and a `GivePlayerItem` still on its way already answers with the condition it was given at.
---
---The percent is the one the game's inventory shows: each item is measured between its own worst and its best, so 100 is as good
---as that item can be (new, or fully repaired) whatever its kind and quality, and a number means the same wear on every item.
---
---The id of one of the player's tagged items (`GivePlayerTaggedItem`) in place of the class answers for that one item.
---@param pid number the player
---@param item string|number the item's name, id, English name or GUID - or a tagged item's id
---@return number 0..100; `nil` when they carry none of it
function GetPlayerItemHealth(pid, item) end

---Sets the condition of every item of a class the player carries.
---
---A smith's repair, a cursed blade, a restore: every item of the class in the player's bag - worn or not - is set to `health`
---(0..100, the inventory's percent: `100` = as good as the item can be) in the server's records at once, and their game sets it the
---game's own way a moment later (no `OnPlayerItemWear`
---comes of it). A `GivePlayerItem` of the class still on its way is made at the new condition too. A `0` breaks the item
---the way the game breaks one.
---
---The id of one of the player's tagged items (`GivePlayerTaggedItem`) in place of the class sets that one item alone - a tournament
---prize repaired, a cursed blade that never wears out - while the other items of its class keep their condition. It answers `1`.
---@param pid number the player
---@param item string|number the item's name, id, English name or GUID - or a tagged item's id
---@param health number the condition, 0..100
---@return number how many items were set (0 when they carry none, or the item is not in the catalogue)
function SetPlayerItemHealth(pid, item, health) end

---The quality of the player's item of a class - I to IV.
---
---`1` to `4` (the game's I to IV; a masterwork forged at the anvil is the best its class can be). When they carry several items of
---the class, the one they wear answers, else the best they carry. The quality is the server's record: the player's game says each
---item's quality when it arrives (a give, a pickup, a chest, the anvil), and a `GivePlayerItem` still on its way already answers
---with the quality it was given at. `0` while their game has not said it yet, or for an item the game keeps at its class's own.
---
---The id of one of the player's tagged items (`GivePlayerTaggedItem`) in place of the class answers for that one item.
---@param pid number the player
---@param item string|number the item's name, id, English name or GUID - or a tagged item's id
---@return number 0..4; `nil` when they carry none of it
function GetPlayerItemQuality(pid, item) end

---Sets the quality of every item of a class the player carries.
---
---A reward, a smith's work, a restore: every item of the class in the player's bag - worn or not - takes `quality` (1..4, I..IV) in
---the server's records at once, and their game sets it a moment later. Each item keeps its condition's percent of the new quality's
---best. A quality past what the class can be is its best; the player's game then says the quality it holds. A `GivePlayerItem` of
---the class still on its way is made at it too.
---
---The id of one of the player's tagged items (`GivePlayerTaggedItem`) in place of the class sets that one item alone. It answers `1`.
---@param pid number the player
---@param item string|number the item's name, id, English name or GUID - or a tagged item's id
---@param quality number the quality, 1..4
---@return number how many items were set (0 when they carry none, the item is not in the catalogue, or the quality is 0)
function SetPlayerItemQuality(pid, item, quality) end

---How fast items wear on this server.
---
---`rate` is a percent of the game's own wear: `100` the game's, `0` never, `50` half as fast, `200` twice as fast. It applies to
---one item class, a **kind** - `"weapon"` (swords, maces, axes, bows, crossbows, the dagger), `"shield"` or `"armor"` (armour,
---helmets, hoods) - or, without one, every item. The most specific rate set applies to an item: its class's, then its kind's,
---then every item's. Every player's game applies it to all the wear its own items take - a blow, a block, a shot, and the
---shoes' wear on the road; a repair is never scaled, nor a repair kit's spent charge (a kit is not made endless by a rate of
---`0`), and `OnPlayerItemWear` still hears every whole percent. At most 64 rates.
---
---**`"walk"`** is the road wear: what the shoes lose for the distance walked. Set, it takes that wear before any other rate -
---`SetItemWear(10, "walk")` keeps the shoes whole ten times longer on the road while a fight still wears them at their own
---rate. Unset, the road wear is the shoes' own rate (they are armour).
---@param rate number percent of the game's wear, 0..1000
---@param kind? string `"weapon"`, `"shield"`, `"armor"`, `"walk"` (the road wear), an item (name, id or GUID), or nothing for every item
---@return boolean `false` for an item the catalogue does not know or a rate out of range
function SetItemWear(rate, kind) end

---The wear rate that applies to an item class, a kind or every item.
---@param kind? string `"weapon"`, `"shield"`, `"armor"`, `"walk"` (the road wear: armour's rate when none was set), an item (name, id or GUID), or nothing for every item
---@return number percent of the game's own wear (`100` when nothing was set)
function GetItemWear(kind) end

---Decide before the game uses an item - a book read, a letter opened, food eaten.
---
---Names an item class, a **category** of the item list or every item (`"*"`) whose use waits for the
---mode: when a player uses such an item from their bag, their game holds the use and asks, and `OnPlayerUseItem` decides -
---`false` refuses it (nothing is read, eaten or applied; the item stays), anything else lets the game go on as usual. The
---categories that have a use: `"Document"` (books, letters, maps, recipes), `"Food"`, `"Herb"`, `"Ointment"` (bandages; a
---repair kit's repair is no use - `OnPlayerItemWear` hears it and may undo it), `"Poison"`. `on = false` takes a name back. A
---use waits for the round trip to the server, so name what the mode means to judge, not every item.
---@param item string an item (name, id or GUID), a category (`"Document"`, `"Food"` ...), or `"*"` for every item
---@param on? boolean `true` (the default) to decide first, `false` to take it back
---@return boolean `false` for an item or category the catalogue does not know
function SetItemUseCheck(item, on) end

---Whether a use of the item waits for the mode's word.
---@param item string an item (name, id or GUID)
---@return boolean `true` when `SetItemUseCheck` named it, its category or every item
function IsItemUseChecked(item) end

---Gives the player one item with the mode's own id, name and text - a letter, a contract, a key to one door.
---
---The game knows an item by its own number for one visit only; a **tagged item** carries the mode's identity instead. `id` is
---the mode's (unique among the player's items: a database row's key, `"letter-17"`), and `name` and `text` are what the game's
---own item panel shows for it instead of the class's name and description (leave them `""` for the class's own; `text` may hold
---line breaks). The item is one of its class in every other way. `GetPlayerInventory` lists it on its own with `id`, `name`
---and `text`, so a mode that saves the inventory saves it, and `SetPlayerInventory` gives it back at the next visit with the
---same tag; `OnPlayerUseItem` names its `id` when the player reads or uses it; `FindPlayerItem` finds it and
---`SetPlayerItemTag` renames it.
---
---The tag goes wherever the item goes: dropped and picked up, put in a chest or a saddlebag and taken out again, left on a
---corpse, stolen by a pickpocket - `GetContainerItems`, `GetHorseItems`, `GetCorpseItems` and `GetActorPocket` list it
---as an entry of its own with its `id`, `name` and `text`, and `SetContainerItems`, `SetHorseItems` and `SetActorPocket`
---take such an entry too (a letter left in a chest for someone to find). The inventory lists it in a row of its own under the
---mode's `name`. Reading it opens the game's book with the mode's `text`: plain text is one paragraph with its line breaks
---kept, and text with the game's own document tags (`<title>`, `<subtitle>`, `<paragraph>`, `<accent>`, `<br/>`,
---`<newpage/>`) is shown as written. Traders do not buy it (the player is told "that one is not for sale") unless it has a price
---of its own (`SetPlayerItemPrice`); a weight of its own is `SetPlayerItemWeight`'s, the look of another item
---`SetPlayerItemModel`'s. Lying on the ground it shows its `name` to every player who looks at it. Taking items of its class away
---(`GivePlayerItem` with a negative amount) takes the player's plain ones first. A tagged item can open a door or a chest
---(`SetDoorKey`, `SetContainerKey`), and a shop can sell tagged items (`SetShopTaggedItem`).
---@param pid number the player
---@param item string the item class - any key of the item catalogue
---@param id string the mode's own id for this one item
---@param name string the name the game's item panel shows (`""` = the class's)
---@param text string the description the item panel shows (`""` = the class's)
---@param health? number its condition, 0..100
---@param quality? number its quality, 1..4 (left out = the class's own)
---@return boolean `false` for an unknown class, an empty id, or an id the player holds already
function GivePlayerTaggedItem(pid, item, id, name, text, health, quality) end

---Renames one of the player's tagged items - a contract signed, a letter opened.
---
---Sets the `name` and `text` the game's item panel shows for the tagged item with that `id` (`GivePlayerTaggedItem`); the
---player's game shows them at once. `""` gives back the class's own.
---@param pid number the player
---@param id string the item's id
---@param name string the new name
---@param text string the new description
---@return boolean `false` when the player holds no item with that id
function SetPlayerItemTag(pid, id, name, text) end

---The player's tagged item with that id.
---@param pid number the player
---@param id string the item's id
---@return table `{class=, amount=1, health=, worn=, id=, name=, text=, weight=, price=, model=}` (`weight`, `price` and `model` only when it has its own), or `nil` when the player holds no item with that id
function FindPlayerItem(pid, id) end

---Gives one of the player's tagged items a weight of its own - a heavy relic, a feather-light charm.
---
---`weight` is in kilograms, 0 to 1000, in place of the class's own (`GetItemInfo` `weight`): the game's inventory shows it and
---counts it in what the player carries - an overloaded player cannot sprint or mount, as with the game's own items - and the
---server's carry-weight check weighs the item by it. `nil` gives the class's back. The weight belongs to the item: it goes with it
---into a chest, a saddlebag, a corpse or another player's bag, and `GetPlayerInventory` lists it as `weight`. Works on an item still
---on its way, right after `GivePlayerTaggedItem`.
---@param pid number the player
---@param id string the tagged item's id
---@param weight number|nil kilograms; `nil` = the class's own
---@return boolean `false` when the player holds no item with that id, or for a weight outside 0..1000
function SetPlayerItemWeight(pid, id, weight) end

---Gives one of the player's tagged items a price of its own - and puts it up for sale.
---
---`price` is in Groschen, 0 to 1,000,000, in place of the class's own: the game's item panel shows it, and a shop that buys the item's
---kind pays its sell factor of it (`CreateShop`). A tagged item **without** a price of its own is not for sale at all (a letter, a
---contract) - giving it one is how a mode lets players sell it. `nil` gives the class's back and takes it off sale. The price belongs
---to the item: it travels with it and `GetPlayerInventory` lists it as `price`. A piece bought from a shop's tagged row
---(`SetShopTaggedItem`) comes with the price it cost.
---@param pid number the player
---@param id string the tagged item's id
---@param price number|nil Groschen; `nil` = the class's own (not for sale)
---@return boolean `false` when the player holds no item with that id, or for a price outside 0..1,000,000
function SetPlayerItemPrice(pid, id, price) end

---Sets what every item of a kind weighs, for every player - lighter rocks, heavier armour.
---
---`weight` is in kilograms per piece, 0 to 1000, in place of the game's own (`GetItemInfo` `weight`). It holds for every player at
---once and for every item of the class wherever it is: the game's inventory, a horse's saddlebags, the item panel and what a player
---carries - an overloaded player cannot sprint or mount, as with the game's own weights - and the server's carry-weight check weighs
---it the same way. A tagged item with a weight of its own (`SetPlayerItemWeight`) keeps it. `nil` gives the class its own back. Set
---it in `OnGameModeInit` for a rule of the server; players who join later get it as they spawn. At most 1024 classes have a rule.
---@param item string|number the item class - its name, id, English name or GUID (the item catalogue)
---@param weight number|nil kilograms per piece; `nil` = the class's own
---@return boolean `false` for an unknown item, a weight outside 0..1000, or a 1025th class
function SetItemClassWeight(item, weight) end

---What an item of a kind weighs now - the mode's rule, else the game's own.
---@param item string|number the item class - its name, id, English name or GUID
---@return number kilograms per piece: the weight `SetItemClassWeight` set, else the game's; `nil` for an item the catalogue does not list
function GetItemClassWeight(item) end

---Sets what every item of a kind is worth, for every player.
---
---`price` is in Groschen per piece at the best quality and condition, 0 to 1,000,000, in place of the game's own (`GetItemInfo`
---`price`, which is in tenths). It holds for every player and every item of the class: the game's item panel and its own traders work
---from it - an item of a lower quality or a worn one is worth less, by the game's own scaling, as with the game's own price - and the
---server's shops pay their sell factor of it (`CreateShop`; a shop's own price for the class, `SetShopBuyPrice`, still comes first).
---A tagged item with a price of its own (`SetPlayerItemPrice`) keeps it. `nil` gives the class its own back. At most 1024 classes
---have a rule.
---@param item string|number the item class - its name, id, English name or GUID
---@param price number|nil Groschen per piece; `nil` = the class's own
---@return boolean `false` for an unknown item, a price outside 0..1,000,000, or a 1025th class
function SetItemClassPrice(item, price) end

---What an item of a kind is worth now - the mode's rule, else the game's own.
---@param item string|number the item class - its name, id, English name or GUID
---@return number Groschen per piece at the best quality and condition: the price `SetItemClassPrice` set, else the game's; `nil` for an item the catalogue does not list
function GetItemClassPrice(item) end

---Gives one of the player's tagged items the look of another item.
---
---`model` names another item (its name, id, English name or GUID - the item catalogue); the tagged item then looks
---like that one everywhere it is drawn: in the player's hands, on the belt and back, lying on the ground and on every other player's
---screen. Only the look changes - the item keeps its own stats, its kind and what it weighs and costs. `nil` gives the item its own
---look back. The look belongs to the item: it travels with it through chests, saddlebags and drops, and `GetPlayerInventory` lists it
---as `model` (the other item's GUID).
---
---Pick a model of the same kind - a sword's look on a sword, a shield's on a shield: the hands and the scabbard hold what the item's own
---kind holds, so a polearm's look on a dagger sits wrong. The look is meant for weapons, shields and things carried: worn clothes and
---armour take it on the other players' screens, but the wearer's own game still draws its own piece.
---@param pid number the player
---@param id string the tagged item's id
---@param model string|nil the item whose look it takes; `nil` = its own
---@return boolean `false` when the player holds no item with that id, or no item is called `model`
function SetPlayerItemModel(pid, id, model) end

---Decide before a crafting station starts.
---
---Names a crafting station whose start waits for the mode: `"alchemy"` (the alchemy table), `"smithing"` (the anvil),
---`"sharpening"` (the grindstone) or every station (`"*"`). When a player starts one, their game holds it and asks, and
---`OnPlayerCraft` decides - `false` keeps the station from starting (nothing is used). `on = false` takes a name back.
---@param station string `"alchemy"`, `"smithing"`, `"sharpening"` or `"*"`
---@param on? boolean `true` (the default) to decide first, `false` to take it back
---@return boolean `false` for a station of another name
function SetCraftCheck(station, on) end

---Whether a crafting station's start waits for the mode's word.
---@param station string `"alchemy"`, `"smithing"` or `"sharpening"`
---@return boolean
function IsCraftChecked(station) end

---The player's purse in Groschen, as far as the server stands behind it.
---
---While the server guards money (the default) the purse is the server's: a player starts each visit with nothing but what
---the mode gives with `GivePlayerMoney` and keeps it through a death, and this is that purse - under `[audit] mode =
---"enforce"` never more than the item check can explain, so a purse edited in memory reads as the money the player really
---has, here and at every shop; a mode that saves the purse saves no conjured money. A `GivePlayerMoney` counts
---at once, before the player's game has moved the coins. Under `observe` the purse is what the player's game holds. Half
---Groschen show as `12.5`.
---@param pid number the player
---@return number Groschen
function GetPlayerMoney(pid) end

---Puts Groschen in the player's purse - or takes them out.
---
---A negative amount takes, never more than the purse holds. The money is the game's own coin item, moved by the same road as
---`GivePlayerItem`: a gift is a record of the server's from the moment it is given, and a take is an exact order. Rounded to
---tenths of a Groschen, the game's own unit. A player starts each visit with an empty purse while the server guards money, so
---the starting money is given here - in `OnPlayerSpawn` for the first spawn, or when the mode's own login restores a saved
---purse. The restore `GivePlayerMoney(pid, saved - GetPlayerMoney(pid))` ends with the saved purse: `GetPlayerMoney` counts
---what was given a moment ago, so the difference is right before the player's game has made it.
---@param pid number the player
---@param groschen number how much; negative takes
---@return boolean `false` when not connected
function GivePlayerMoney(pid, groschen) end

---Puts an item on the ground for everyone to see and anyone to take.
---
---A pickup entity of `ENTITY_ITEM`: every client in range shows the item lying at the point; whoever takes it gets the item
---(`OnPlayerPickup`) and the pickup is gone for everyone. `item` is any key of the item catalogue.
---`world` is the virtual world (`nil` = the shared one), `health` the condition the item is made at on every screen and
---that whoever takes it keeps (1..100, new without). `nil` when the key is unknown or the world is full
---(`[world] max_entities`). The `/item` built-in places one in front of an admin. A player's drop keeps the dropped item's
---condition and quality by itself (`GetPickupHealth` and `GetPickupQuality` read them) - a mode that keeps dropped items
---in its own database and lays them again passes both back here, or the item comes back new and at its class's own quality.
---@param item string|number the item's name, id, English name or GUID
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw? number degrees (`0` without)
---@param world? number the virtual world; `nil` = the shared one
---@param health? number the item's condition, 1..100 (`100`, new)
---@param quality? number the item's quality, 1..4 (I..IV, a forged masterwork the top); `nil` = the class's own
---@return number the pickup's entity id; `nil` when it could not be made
function CreatePickup(item, x, y, z, yaw, world, health, quality) end

---Sets the condition a pickup's item has.
---
---1..100: every screen makes the item lying there at that condition, and whoever takes it keeps it. Set it right after the
---pickup is made (`CreatePickup` takes it as an argument too): a screen that shows the pickup already keeps the one it made.
---A player's drop has the dropped item's condition already.
---@param id number the pickup
---@param health number the condition, 1..100
---@return boolean `false` for an entity that is no item pickup
function SetPickupHealth(id, health) end

---The condition of a pickup's item.
---@param id number the pickup
---@return number 1..100; `nil` for an entity that is no item pickup
function GetPickupHealth(id) end

---Sets the quality a pickup's item has.
---
---1..4 (I..IV; `0` = the class's own): every screen makes the item lying there at that quality, and whoever takes it keeps it.
---Set it right after the pickup is made (`CreatePickup` takes it as an argument too): a screen that shows the pickup already
---keeps the one it made. A player's drop has the dropped item's quality already.
---@param id number the pickup
---@param quality number the quality, 1..4; `0` = the class's own
---@return boolean `false` for an entity that is no item pickup
function SetPickupQuality(id, quality) end

---The quality of a pickup's item.
---
---What a mode that handles drops or pickups itself reads to keep the item's quality - pass it to `CreatePickup` when it lays the
---item again, or to `GivePlayerItem` when it gives the item itself.
---@param id number the pickup
---@return number 1..4, `0` = the class's own; `nil` for an entity that is no item pickup
function GetPickupQuality(id) end

-- ======== GameText and HUD ======================================================
-- Two ways to put text on a player's screen besides the chat: a **GameText** - one big line for a moment ("Round 3", "You win",
-- a subtitle) - and a **HUD text** - a line the mode places at a fraction of the screen and keeps there, changing it whenever
-- (a clock, a score, a timer). Both draw under the game's own menus and vanish behind the loading screen. For anything richer a
-- client script draws it.

---One big line on the player's screen for a while.
---
---A line in a large serif, fading out over its last half second; a new one replaces the old. `style` is `GAMETEXT_CENTRE`
---(`0`, big in the middle), `GAMETEXT_TOP` (`1`, under the top edge) or `GAMETEXT_LOWER` (`2`, the lower third, like a
---subtitle).
---@param pid number the player
---@param text string the line
---@param ms? number how long it stays, milliseconds (`3000`; `100` .. `60000`)
---@param style? number `GAMETEXT_CENTRE` (the default), `GAMETEXT_TOP` or `GAMETEXT_LOWER`
---@return boolean `false` when not connected
function GameText(pid, text, ms, style) end

---One big line on every screen.
---@param text string the line
---@param ms? number milliseconds (`3000`; `100` .. `60000`)
---@param style? number `GAMETEXT_CENTRE`, `GAMETEXT_TOP` or `GAMETEXT_LOWER`
function GameTextForAll(text, ms, style) end

---A line of text at a screen position, shown to the players you choose.
---
---`x` and `y` are fractions of the screen from the top left - `0.5, 0.02` is the top centre, `0.99, 0.02` the top right with
---`HUD_ALIGN_RIGHT`, `0.02, 0.5` the left edge halfway down - so the line lands in the same place at every resolution. The
---element is shown to **nobody** until `ShowHudText` or `ShowHudTextForAll`; a change to its text or look is re-sent to
---everyone it is shown to. A shown element survives its player's respawns and goes with their disconnect; the mode's
---elements go with a reload. Ids start at `1`; there are 4096.
---@param x number `0` .. `1` of the screen width from the left
---@param y number `0` .. `1` of the screen height from the top
---@param text string the line
---@param color? number `0xRRGGBBAA` (white)
---@param scale? number `1` = the HUD's own text size; `0.5` .. `5`
---@param align? number `HUD_ALIGN_LEFT` (the default), `HUD_ALIGN_CENTRE` or `HUD_ALIGN_RIGHT` - which side of the line sits at `x`
---@return number the element's id; `nil` when the ids are used up
function CreateHudText(x, y, text, color, scale, align) end

---Removes a HUD text from every screen.
---@param id number the element
---@return boolean `false` when there is no such element
function DestroyHudText(id) end

---Changes a HUD text's text.
---
---Re-sent to everyone the element is shown to. A change every second is fine; every tick is not.
---@param id number the element
---@param text string the new line
---@return boolean `false` when there is no such element
function SetHudText(id, text) end

---A HUD text's current text.
---@param id number the element
---@return string `""` when there is no such element
function GetHudText(id) end

---Moves a HUD text.
---@param id number the element
---@param x number `0` .. `1` of the width
---@param y number `0` .. `1` of the height
---@return boolean
function SetHudTextPos(id, x, y) end

---Recolors a HUD text.
---@param id number the element
---@param color number `0xRRGGBBAA`
---@return boolean
function SetHudTextColor(id, color) end

---Resizes a HUD text.
---@param id number the element
---@param scale number `1` = the HUD's own size; `0.5` .. `5`
---@return boolean
function SetHudTextScale(id, scale) end

---Changes which side of a HUD text sits at its x.
---@param id number the element
---@param align number `HUD_ALIGN_LEFT`, `HUD_ALIGN_CENTRE` or `HUD_ALIGN_RIGHT`
---@return boolean
function SetHudTextAlign(id, align) end

---Shows a HUD text on one player's screen.
---
---Usually called from `OnPlayerSpawn` so a late joiner gets the mode's elements too - `ShowHudTextForAll` only reaches
---the players connected at the time.
---@param id number the element
---@param pid number the player
---@return boolean `false` when the element or the player does not exist
function ShowHudText(id, pid) end

---Takes a HUD text off one player's screen.
---@param id number the element
---@param pid number the player
---@return boolean
function HideHudText(id, pid) end

---Shows a HUD text to everyone connected now.
---@param id number the element
---@return boolean
function ShowHudTextForAll(id) end

---Takes a HUD text off every screen (the element stays for later).
---@param id number the element
---@return boolean
function HideHudTextForAll(id) end

---Whether a HUD text is on a player's screen.
---@param id number the element
---@param pid number the player
---@return boolean
function IsHudTextShown(id, pid) end

---Every HUD text the mode has made.
---@return table a list of element ids
function GetHudTexts() end

---A line in the game's own info slot under the compass.
---
---The toast the game uses for "You cannot do that now": a line in the game's typeface under the compass, for `ms`
---milliseconds, optionally on a dark backing. Lines queue in the HUD; a higher `priority` goes before the ones waiting.
---The server puts its own fight messages there ("You are fighting Hans"), so a mode's lines share the slot with them.
---@param pid number the player
---@param text string the line
---@param ms? number how long it stays, milliseconds (`3000`; `0` = the HUD's own default, up to `60000`)
---@param priority? number `0` .. `255`, a higher one is shown first (`0`)
---@param background? boolean a dark backing behind the line (`false`)
---@return boolean `false` when not connected
function ShowInfoText(pid, text, ms, priority, background) end

---The info line on every screen.
---@param text string the line
---@param ms? number milliseconds (`3000`)
---@param priority? number `0` .. `255` (`0`)
---@param background? boolean a dark backing (`false`)
function ShowInfoTextForAll(text, ms, priority, background) end

---Takes the info line down before its time.
---@param pid? number the player (`-1` = everyone)
---@return boolean
function HideInfoText(pid) end

---The game's short notification at the top of the screen.
---
---The one-line toast the game shows for "Game saved" and the like - short, in the game's look, gone by itself. For a
---longer or a placed line use `ShowInfoText`; for a title with a line under it, `ShowObjectiveEvent`.
---@param pid number the player
---@param text string the line, kept short
---@return boolean `false` when not connected
function ShowNotification(pid, text) end

---The short notification on every screen.
---@param text string the line
function ShowNotificationForAll(text) end

---A line in the game's log toast.
---
---The game's own log line (the slot that reports a reputation change or a found item): `kind` and `level` pick its icon and
---color as the game's tables have them - `0, 0` is the plain line. The server puts "X was kicked" there for everyone.
---@param pid number the player (`-1` = everyone)
---@param text string the line
---@param kind? number the game's log type (`0`)
---@param level? number the game's log level (`0`)
---@return boolean
function ShowGameLog(pid, text, kind, level) end

---A log line on every screen.
---@param text string the line
---@param kind? number the game's log type (`0`)
---@param level? number the game's log level (`0`)
function ShowGameLogForAll(text, kind, level) end

---The quest-style banner - a title with a line under it.
---
---The game's own objective banner (the one that announces "New objective" with the quest's name and the objective's
---text): `title` goes where the quest's name goes, `text` where the objective's does, `kind` is `OBJECTIVE_NEW`,
---`OBJECTIVE_DONE` or `OBJECTIVE_FAILED` - the game colors and sounds them its own way. The duel arena announces its
---rounds and results with it.
---@param pid number the player (`-1` = everyone)
---@param title string the banner's title
---@param text string the line under it
---@param kind? number `OBJECTIVE_NEW` (the default), `OBJECTIVE_DONE` or `OBJECTIVE_FAILED`
---@return boolean
function ShowObjectiveEvent(pid, title, text, kind) end

---The banner on every screen.
---@param title string the banner's title
---@param text string the line under it
---@param kind? number `OBJECTIVE_NEW`, `OBJECTIVE_DONE` or `OBJECTIVE_FAILED`
function ShowObjectiveEventForAll(title, text, kind) end

---A tutorial box with a text that stays a while.
---
---The game's own tutorial box - the framed panel that explains a mechanic - with your text, for `ms` milliseconds or
---until `HideTutorial` takes it down by its `id`. A second call with the same id replaces the text. Good for rules,
---a countdown with a hint, or anything a player should read at leisure; the party invitation is one of these.
---@param pid number the player (`-1` = everyone)
---@param id string a name of your own for the box, to hide it later
---@param text string the text (a newline starts a new line)
---@param ms? number how long it stays, milliseconds (`8000`; up to `60000`)
---@return boolean
function ShowTutorial(pid, id, text, ms) end

---The tutorial box on every screen.
---@param id string the box's name
---@param text string the text
---@param ms? number milliseconds (`8000`)
function ShowTutorialForAll(id, text, ms) end

---Takes a tutorial box down by its name.
---@param pid number the player (`-1` = everyone)
---@param id string the box's name as `ShowTutorial` got it
---@return boolean
function HideTutorial(pid, id) end

---Shows or hides one of the game's own HUD pieces - the compass, the health bars, the hints - on a player's screen.
---
---The game draws its own HUD - the compass, the bars, the prompts, the toasts - and a mode can take one **piece** of it
---away for a player and give it back, without touching the rest. The pieces have names, and each name is a constant:
---
---| piece | what it is |
---|---|---|
---| `HUD_COMPASS` | the compass strip |
---| `HUD_STATS` | the health and stamina bars - one piece, they hide together |
---| `HUD_SUBTITLES` | the subtitles |
---| `HUD_HINTS` | the action hints, the "press a key" prompts |
---| `HUD_CURSOR` | the crosshair dot and the item card |
---| `HUD_BUFFS` | the icons of the buffs |
---| `HUD_INFO_TEXT` | the info line under the compass - where `ShowInfoText` draws |
---| `HUD_GAME_LOG` | the game's log toast - `ShowGameLog` |
---| `HUD_COMMON_EVENT` | one of the game's two event banners - `ShowNotification` and `ShowObjectiveEvent` draw in them |
---| `HUD_FANCY_EVENT` | the other event banner |
---| `HUD_TUTORIAL_MESSAGE` | the tutorial box - `ShowTutorial`, the party's invitation and the death box |
---
---**Five of these are the slots of the mode's own toasts**: hiding `HUD_INFO_TEXT`, `HUD_GAME_LOG`,
---`HUD_COMMON_EVENT`, `HUD_FANCY_EVENT` or `HUD_TUTORIAL_MESSAGE` hides what the mode and the server show there as well - a
---hidden tutorial box takes a party invitation and the death box with it. Hide those pieces only when the mode shows nothing
---in them.
---
---The name is read loosely - case, `_`, `-` and spaces do not count, so `"InfoText"` is `HUD_INFO_TEXT` - and a name that is
---no piece is refused with `"no such piece"`. The setting is the `hud` component's option of that name
---(`SetPlayerInterfaceOptions` sets the same thing, and `SetInterfaceOptionsForAll` does it for everyone); it holds until the
---mode changes it, the player leaves or the mode is reloaded, and a player's game puts the piece back as it found it
---when the session ends - a player's own choice in the game's settings survives.
---
---The answer is `true` when the request was handed to the player's game, or `false` and the reason: `"no such player"` or
---`"no such piece"`.
---@param pid number the player
---@param piece string a piece - `HUD_COMPASS`, `HUD_STATS` ... - as the constants of this page name them
---@param visible boolean `true` shows the piece (the default state), `false` hides it
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"no such piece"`, `"no such player"`)
---@return string reason
function SetPlayerHudVisible(pid, piece, visible) end

-- ======== Compass markers =======================================================
-- A **compass marker** is a point in the level a mode shows to the players it chooses, as a blip on the game's own compass
-- strip at the point's bearing, drawn with the game's quest symbol or its point-of-interest symbol. Like the HUD
-- texts, a marker is shown to nobody until `ShowMarker`; a change to it is re-sent to everyone it is shown to; a shown
-- marker survives its player's respawns and goes with their disconnect; the mode's markers go with a reload. Ids start at `1`;
-- there are 1024. The party members' blips need no marker: the server puts them on the compass by itself (`[ui] party_compass`).
-- The world map is the server's call too: every player sees the whole map from the start unless `[ui] map_fog` keeps the game's
-- fog of war over what they have not walked, and then `RevealPlayerMap` lifts it for one of them.

---A compass marker at a point, shown to the players you choose.
---@param x number metres, the level's world space
---@param y number metres
---@param z number metres
---@param kind? number `MARKER_QUEST` (the default, the quest symbol) or `MARKER_POINT` (the point-of-interest symbol)
---@param color? number `0xRRGGBBAA`; `0` keeps the symbol's own color (the default)
---@param text? string a label of up to 64 characters, kept for the clients that show one
---@return number the marker id, or `nil` when the 1024 are used up
function CreateMarker(x, y, z, kind, color, text) end

---Removes a marker from every compass and frees its id.
---@param id number the marker
---@return boolean
function DestroyMarker(id) end

---Moves a marker; everyone it is shown to sees it move.
---@param id number the marker
---@param x number metres
---@param y number metres
---@param z number metres
---@return boolean
function SetMarkerPos(id, x, y, z) end

---Changes the symbol a marker is drawn with.
---@param id number the marker
---@param kind number `MARKER_QUEST` or `MARKER_POINT`
---@return boolean
function SetMarkerKind(id, kind) end

---Changes a marker's color.
---@param id number the marker
---@param color number `0xRRGGBBAA`, `0` = the symbol's own
---@return boolean
function SetMarkerColor(id, color) end

---Changes a marker's label.
---@param id number the marker
---@param text string up to 64 characters
---@return boolean
function SetMarkerText(id, text) end

---A marker's point, kind, color and label.
---@param id number the marker
---@return table `{x, y, z, kind, color, text}`, or `nil` for no such marker
function GetMarkerInfo(id) end

---Puts a marker on a player's compass.
---@param id number the marker
---@param pid number the player
---@return boolean
function ShowMarker(id, pid) end

---Takes a marker off a player's compass (the marker stays for later).
---@param id number the marker
---@param pid number the player
---@return boolean
function HideMarker(id, pid) end

---Puts a marker on every compass.
---@param id number the marker
---@return boolean
function ShowMarkerForAll(id) end

---Takes a marker off every compass.
---@param id number the marker
---@return boolean
function HideMarkerForAll(id) end

---Whether a marker is on a player's compass.
---@param id number the marker
---@param pid number the player
---@return boolean
function IsMarkerShown(id, pid) end

---Every marker the mode has made.
---@return table a list of marker ids
function GetMarkers() end

---Shows one player the whole world map, without the fog of war.
---
---For a server that keeps the game's fog of war over the parts of the map a player has not walked (`map_fog = true` under
---`[ui]` in `server.toml`) and lifts it for someone - a map bought, a quest done. Without the fog (the default) every
---player's map shows everything from the start and this changes nothing. It works one way: a revealed map cannot be
---clouded again, and a player who comes back in a new game has the fog again, so call it again (from `OnPlayerSpawn`,
---say). A player still loading gets the whole map as soon as they are in the world. `"places"` (or `"all"`) also asks the
---player's game to find the places of the level, so the revealed map shows their names
---(what a player discovered); no player's game does that part in this version, and the map is
---revealed without the names.
---@param pid number the player
---@param what? string|nil `"places"` or `"all"` to ask for the places too; anything else, or nothing, reveals the map alone
---@return boolean `false` when there is no such player
function RevealPlayerMap(pid, what) end

-- ======== Effects and sounds ====================================================
-- One-shot things at a point in the world for everyone nearby: a **particle effect** of the game's own libraries (smoke, fire,
-- sparks), a **decal** on the ground or a wall, a **sound** from the game's audio triggers. They reach the players within
-- `[effects] range` metres (150; `0` = everyone in that virtual world) and are fire-and-forget - a player who arrives later sees
-- and hears nothing. Each returns how many players got it. A name the game does not know is not an error on the server: it only
-- warns in the clients' logs.

---Plays one of the game's particle effects at a point for everyone nearby.
---
---`name` is a particle effect of the game's libraries by its full name - `WH_Particels.smokes.smithery`,
---`professions.blacksmith.forge_fire`, `cinematics.fires.fire_big_a` ... (the particle effects list
---all 2,600). `scale` `1` plays it as authored. `dir` is the effect's
---**up** - `{x, y, z}` or three numbers; straight up (`0, 0, 1`) without it. A looping effect plays until the player's level
---unloads. `world` is the virtual world (`0`, the shared one, without it).
---@param name string the particle effect's full name
---@param x number metres
---@param y number metres
---@param z number metres
---@param scale? number `1` = as authored
---@param dir? table|number the effect's up as `{x=, y=, z=}` (or three numbers `dx, dy, dz` in its place); straight up without
---@param world? number the virtual world (`0`)
---@return number how many players got it; `0` for an empty name or nobody in range
function SpawnEffect(name, x, y, z, scale, dir, world) end

---Puts a decal of a material on whatever is at a point.
---
---A mark on the ground under a spawn, a stain on a wall: `material` is one of the game's decal materials
---(the decal materials: `Materials/decals/decal_blood_a`, `decal_burned_ash`, `chalk_cross` ...), `size` metres across,
---`seconds` how long it stays (`0` = the engine's own default). `normal` is which way the decal faces - `{x, y, z}` or three
---numbers; a floor (`0, 0, 1`) without it. The same reach and return as `SpawnEffect`.
---@param material string the decal material
---@param x number metres
---@param y number metres
---@param z number metres
---@param size? number metres across (`1`)
---@param seconds? number how long it stays; `0` = the engine's default
---@param normal? table|number which way it faces as `{x=, y=, z=}` (or three numbers `nx, ny, nz`); a floor without
---@param world? number the virtual world (`0`)
---@return number how many players got it
function SpawnDecal(material, x, y, z, size, seconds, normal, world) end

---Plays one of the game's sounds at a point for everyone nearby.
---
---`trigger` is an audio trigger of the game's sound banks by name - `lightning`, `c_neck_snap`, `male_spit`,
---`special_barber_scissors` ... (the audio triggers list all 15,000) - played the game's own way from a short-lived emitter at the point:
---each player hears it from where it is. The emitter stays `seconds` (`0` = 10); a looping trigger ends with it. The same
---reach and return as `SpawnEffect`.
---@param trigger string the audio trigger's name
---@param x number metres
---@param y number metres
---@param z number metres
---@param seconds? number how long the sound source stays; `0` = 10
---@param world? number the virtual world (`0`)
---@return number how many players heard it
function PlaySound(trigger, x, y, z, seconds, world) end

-- ======== Map icons =============================================================
-- The **world map** and the compass show the game's own icons: towns, shops, services, camps. A mode puts icons of the same kind
-- there - a player's shop, a guild hall, a quest giver - with a type's icon and legend name (`CreateMapIcon`), and takes the level's
-- own away where they mean nothing on its server - the tailor who no longer sells, a smithy that is a player's house now
-- (`HideLevelMapIcons`). Both are for everyone or for one player, and a player who joins later gets them at the spawn. They last for
-- the server's run: a mode makes them again in `OnGameModeInit`.
-- 
-- The types and every level's own shop and service icons, with their ids and places, are on the
-- map icons reference page. For a blip on the compass alone, see the compass markers.

---An icon of the game's own kind on the world map and the compass.
---
---`opts`:
---
---- `type` - a map icon type's name (`"tailor"`, `"blacksmith"`, `"pub"` ...) or its GUID: its icon and its legend name;
---- `icon` - the legend's icon number instead of the type's;
---- `name` - the name on the map (`""`: the type's legend name);
---- `visible` - `false` shows it to nobody until `SetMapIconVisibleFor` (`true` by default).
---
---An icon needs a picture: a type with one, or an icon number. The level's map shows only the kinds its legend has (the monastery's
---map has no shops - a pin or a camp shows anywhere). At most 1024 icons.
---@param x number metres
---@param y number metres
---@param z number metres
---@param opts table the options above
---@return number the icon's id; `nil` and the reason
function CreateMapIcon(x, y, z, opts) end

---An icon anew - moved, renamed, another type.
---
---The same numbers and `opts` as `CreateMapIcon`, whole.
---@param id number the icon
---@param x number metres
---@param y number metres
---@param z number metres
---@param opts table the options
---@return boolean `true`; `false` and the reason
function SetMapIcon(id, x, y, z, opts) end

---Takes an icon off every map.
---@param id number the icon
---@return boolean `false` when there is none of that id
function DeleteMapIcon(id) end

---An icon as it stands.
---@param id number the icon
---@return table `{id, x, y, z, type, icon, name, visible}`; `nil` when there is none
function GetMapIcon(id) end

---Every icon of the mode's, by id.
---@return table a list of `GetMapIcon`'s tables
function GetMapIcons() end

---Shows an icon to one player, or hides it from them.
---
---Over the icon's own `visible`; `nil` follows it again. Kept while they are connected.
---@param pid number the player
---@param id number the icon
---@param visible boolean|nil `true`, `false` or `nil`
---@return boolean `false` when the icon or the player is not there
function SetMapIconVisibleFor(pid, id, visible) end

---Hides some of the level's own map icons from everyone.
---
---`opts`: `mark` - one icon by its id (the reference page lists them; the same on every game); or `type` (a name or a GUID) with
---`x`, `y` and `radius` - the icons of that type around a place (no `radius`: the whole level); or `x`, `y` and `radius` alone -
---every icon around a place. The icon goes from the map and the compass, and a player cannot discover the place while it is hidden; it
---comes back as the player had it when the rule goes. At most 256 rules.
---@param opts table the rule
---@return number the rule's id, for `ShowLevelMapIcons`; `nil` and the reason
function HideLevelMapIcons(opts) end

---Hides some of the level's own map icons from one player.
---
---The same `opts` as `HideLevelMapIcons`; the rule goes when they leave.
---@param pid number the player
---@param opts table the rule
---@return number the rule's id; `nil` and the reason
function HideLevelMapIconsFor(pid, opts) end

---Takes a hiding rule away - its icons come back.
---
---An icon another rule still hides stays hidden.
---@param rule number the rule's id
---@return boolean `false` when there is no such rule
function ShowLevelMapIcons(rule) end

---The game's map icon types.
---@return table `{{name, guid, icon, legend, service}, ...}` by name (`legend`: the English legend name; `service`: a shop or a service; `icon` `-1`: no picture)
function GetMapIconTypes() end

-- ======== Script events =========================================================
-- A mode that needs something on the client the server cannot draw - a marker in the world, a sound, a bit of UI, a value read
-- from the game - keeps a client script in the `client/` folder next to itself (the server sends it
-- to every player who joins) and talks to it through **named events with a string payload**, both ways: `SendClientEvent`
-- down, `SendServerEvent` up into `OnClientEvent`. The payload is whatever string the two halves agree on - a number, a
-- comma list, JSON. For values every client should simply *know* - a team, a round, a flag carrier - the
-- state bags are the better fit. The `marker` example mode in the server folder is the round trip whole.
-- 
-- **The limits count bytes of UTF-8**, not characters - a Cyrillic or Chinese letter is two or three bytes. An event's name is
-- at most 64 bytes both ways; the payload is at most **60000 bytes** from the server to a client and **4096 bytes** from a
-- client to the server. The server **refuses** a bigger event and never cuts it - a cut payload is broken JSON - so send large
-- data in several smaller events. `SendClientEvent` says with `false` when it refused one, and the server log names the event
-- (the first twenty refusals, then every hundredth).
-- 
-- A server with a web interface has a second listener for these events, and a second sender: its **pages**. An event of
-- `SendClientEvent` also reaches every page whose `events_in` in `ui.toml` lets it receive the name (by default the names that
-- start with the frame's own name and a dot: `shop.open` for a frame called `shop`), and a page's `emitServer` arrives in
-- `OnClientEvent` with the frame's name as its `source`. The payload may be a table, which travels as its JSON. The names
-- that start with `kcdmp:` belong to the game itself and are refused. From a player, a client script's events and a page's
-- events share **one budget**: at most 30 events and 64 KB (name and payload together) a second in all; a page's payload is
-- at most 16384 bytes.

---**Called by the server** - A player's client script sent an event.
---
---The client's `SendServerEvent(name, payload)` lands here. `payload` is whatever string the client sent - trust it no
---further than any other input from a player (parse defensively, check the pid may do what it asks). At most 30 events a
---second per client, a name of at most 64 bytes and a payload of at most 4096 bytes (bytes of UTF-8, not characters); an
---event over any of these limits is dropped and never reaches the mode, and the server log says so once a second at the most.
---
---A page of the web interface sends events too: its `KcdMp.emitServer(name, value)` lands here with the frame's name as
---`source` (a text goes as it is, any other value as its JSON - read it with `JsonDecode`). A page's payload may be up
---to 16384 bytes and its names are limited by the frame's `events_out` in `ui.toml`, which the player's game enforces -
---the server only checks that the frame exists and that the name is one a page may send. A client script's events
---and a page's share one budget of 30 events and 64 KB a second for the player; what is over it is dropped and counted,
---never a reason to kick. `source` is what the player's game says, so use it to route, not to trust.
---@param pid number whose client sent it
---@param name string the event's name
---@param payload string the string the client sent; `""` when none
---@param source string `"lua"` for a client script's `SendServerEvent`, the frame's name for a page's `emitServer` - the player's game's word, advisory
function OnClientEvent(pid, name, payload, source) end

---A named event with a string payload to one player's client script.
---
---The client script's `OnServerEvent(name, payload)` receives it; a client
---without a script, or without a handler for the name, ignores it. `payload` is a string - format it however the two halves
---agree. Nothing is queued for a client that has not loaded the level yet.
---
---The name may be at most 64 bytes and the payload at most 60000 bytes of UTF-8. A bigger event is **refused**: nothing is
---sent, the function returns `false` and the server log names the event - it is never cut, because a cut payload is broken
---JSON. Split large data over several events.
---
---A **table** is sent as its JSON (`JsonEncode` has the rules); the client script reads it with `JsonDecode` and a
---page of the web interface receives it already read. The event also reaches **every page** of the player's web interface
---whose `events_in` lets it receive the name. The names that start with `kcdmp:` belong to the game itself: sending one
---is refused with `false, "reserved name"`, and so is a table that cannot be written as JSON (the reason is
---`JsonEncode`'s).
---@param pid number the player
---@param name string the event's name (at most 64 bytes)
---@param payload? string|table the string to send (`""` without; at most 60000 bytes) - or a table, which is sent as its JSON
---@return boolean `false` when the player is not connected or the event was refused for its size, for a reserved name or for a table that cannot be written as JSON (the reason is then a second value)
function SendClientEvent(pid, name, payload) end

---The same event to every connected client.
---
---The limits are those of `SendClientEvent`: a name of at most 64 bytes and a payload of at most 60000 bytes of UTF-8.
---A bigger event is refused - nobody gets it, and the function returns `false`.
---
---The payload may be a table, sent as its JSON, and the event reaches the pages of the players' web interfaces like
---`SendClientEvent`'s; a name that starts with `kcdmp:` is refused with `false, "reserved name"`.
---@param name string the event's name (at most 64 bytes)
---@param payload? string|table the string to send (`""` without; at most 60000 bytes) - or a table, which is sent as its JSON
---@return boolean `false` when the event was refused for its size, for a reserved name or for a table that cannot be written as JSON (the reason is then a second value)
function SendClientEventToAll(name, payload) end

-- ======== State bags ============================================================
-- String keys and values the mode sets on the **world**, a **player** or an **entity**, and **every client's script reads** -
-- `GetGlobalState(key)`, `GetPlayerState(pid, key)`, `GetEntityState(id, key)`, with a change hook on each
-- (the client API). The way a mode's client half learns a team, a round, a marker, a flag carrier
-- without a script event per client: the global and the players' bags reach every client from its join on, an entity's follows
-- its spawn to whoever sees it. Numbers and booleans become strings; `nil` removes a key. Nothing is persisted - a player's bag
-- goes with the session, an entity's with the entity, all of them with a reload. Limits: a key of 1-48 characters, a value of at
-- most 1 KB, 64 keys a bag (a set beyond them returns `false` and logs). The mode's *private* storage is
-- `SetPlayerData` / `SetEntityData`.

---Sets a key of the world's bag, read by every client.
---@param key string 1-48 characters
---@param value string|number|boolean|nil kept as a string; `nil` removes the key
---@return boolean `false` when the key or the value is out of bounds or the bag is full
function SetGlobalState(key, value) end

---A key of the world's bag.
---@param key string the key
---@return string|nil
function GetGlobalState(key) end

---The whole world bag.
---@return table `{key = value, ...}`
function GetGlobalStates() end

---Sets a key of a player's bag, read by every client.
---
---Every client has every player's bag from its join on - `GetPlayerState(pid, key)`; the client's own pid is
---`GetPlayerId()`. Gone with the player's session.
---@param pid number the player
---@param key string 1-48 characters
---@param value string|number|boolean|nil kept as a string; `nil` removes the key
---@return boolean `false` when not connected or out of bounds
function SetPlayerState(pid, key, value) end

---A key of a player's bag.
---@param pid number the player
---@param key string the key
---@return string|nil
function GetPlayerState(pid, key) end

---A player's whole bag.
---@param pid number the player
---@return table `{key = value, ...}`
function GetPlayerStates(pid) end

---Sets a key of an entity's bag, read by every client that sees the entity.
---
---The bag travels with the entity's spawn to whoever comes into range and is dropped when it leaves their view -
---`GetEntityState(id, key)` while the entity is in view. Gone with the entity. An NPC actor's pose rides in its bag
---under the key `anim` (`SetActorAnim`).
---@param id number the entity
---@param key string 1-48 characters
---@param value string|number|boolean|nil kept as a string; `nil` removes the key
---@return boolean `false` when there is no such entity or out of bounds
function SetEntityState(id, key, value) end

---A key of an entity's bag.
---@param id number the entity
---@param key string the key
---@return string|nil
function GetEntityState(id, key) end

---An entity's whole bag.
---@param id number the entity
---@return table `{key = value, ...}`
function GetEntityStates(id) end

-- ======== Storage and persistence ===============================================
-- Two places to keep a value, by how long it should live. **Data** (`SetPlayerData`, `SetEntityData`, `SetZoneData`) is the
-- mode's private bag on a player, an entity or a zone - any Lua value, gone with the player's session, the entity or a reload;
-- nothing leaves the server. Anything that should outlive the session - accounts, scores, factions, the place a player left -
-- goes into the mode's own database when the owner connected one; the server itself remembers nothing about a
-- player between visits. What every *client* should read is the state bags instead. The rule that keeps the
-- tick fast: read from the database once, on the connect, into `SetPlayerData` and your own tables; write on change and on the
-- disconnect.

---Stores a value on the player, private to the server, for the session.
---
---Any Lua value - a string, a number, a boolean, a table. Cleared when the player disconnects and on a reload. Never
---replicated: for a value the clients read use `SetPlayerState`; for one that should survive the visit, the mode's
---database. The natural cache for a player's row: load it here on the connect, answer every callback from
---here, write it back on the disconnect.
---@param pid number the player
---@param key string the key
---@param value any the value; `nil` removes the key
---@return boolean `false` when not connected
function SetPlayerData(pid, key, value) end

---A value stored on the player with SetPlayerData.
---@param pid number the player
---@param key string the key
---@return any the value; `nil` when unset or not connected
function GetPlayerData(pid, key) end

---Stores a value on a world entity, private to the server.
---
---Any Lua value; gone with the entity and on a reload. For a value the clients read use `SetEntityState`.
---@param id number the entity
---@param key string the key
---@param value any the value; `nil` removes the key
---@return boolean `false` when there is no such entity
function SetEntityData(id, key, value) end

---A value stored on an entity with SetEntityData.
---@param id number the entity
---@param key string the key
---@return any the value; `nil` when unset or no such entity
function GetEntityData(id, key) end

-- ======== The game mode's database ==============================================
-- A mode keeps what should outlive a session - accounts, factions, scores, the rules on doors and chests - in a database of its
-- own: MySQL / MariaDB or PostgreSQL, the one thing a server owner connects in `server.toml` (`[gamemode.database]`; the
-- databases guide sets one up). `GetDatabase` hands out the handle, or `nil` when the owner
-- configured none: say so and run without. The server's own state - doors, chests, taken items, bans - lives apart and is never
-- reachable through it. Every query runs off the tick and answers in a callback; **parameters only** (`@name` in the SQL, the
-- values in a table - never concatenate a value into the SQL text); a failing query hands its error to the callback and the
-- server goes on. The sync pair is for the mode's init alone.

---The mode's database handle, or `nil` when the server has none.
---
---The handle is one table with these methods (`db:Query(...)`, with the colon). The answers arrive later, on the server's own
---thread, in the callback: a query never waits on the tick.
---
---| Method | What it does | The callback |
---|---|---|---|
---| `db:Query(sql, params, cb)` | rows | `cb(rows, err)` - `rows` a list of `{column = value}` tables (a NULL column absent from its row) |
---| `db:Execute(sql, params, cb)` | a write | `cb(affected, insertId, err)` - `insertId` on MySQL / MariaDB (PostgreSQL uses `RETURNING`) |
---| `db:Scalar(sql, params, cb)` | the first column of the first row | `cb(value, err)` |
---| `db:Batch({ {sql, params}, ... }, cb)` | several writes in one transaction, all or nothing | `cb(ok, err)` |
---| `db:QuerySync(sql, params)` | rows, now | returns `rows, err` - **during `OnGameModeInit` only**, refused anywhere else |
---| `db:ExecuteSync(sql, params)` | a write, now | returns `affected, insertId, err` - the same rule |
---
---`params` is `{name = value}` for `@name` in the SQL (or `nil`): strings, numbers (an integer stays an integer), booleans,
---and DB_NULL for a NULL (a `nil` value would vanish from the table). Values come back as strings, numbers, booleans;
---dates as ISO 8601 text. `db.driver` is `"mysql"` or `"postgres"`: the SQL is yours and your engine's. The owner's
---`timeout_seconds`, `max_rows` and `slow_query_ms` bound every call; a callback that errors is logged like any script error.
---The rule that keeps the tick fast: read a player's row once on the connect into `SetPlayerData` and your tables, answer
---every callback from memory, write on change and on the disconnect (a batch is one round trip).
---@return table|nil the handle, with `driver` and the methods above; `nil` without a `[gamemode.database]`
function GetDatabase() end

-- ======== World entities ========================================================
-- A **world entity** is something the server owns and every client in range sees: a horse (`ENTITY_HORSE`), a pickup
-- (`ENTITY_ITEM`), an NPC actor (`ENTITY_NPC`), a prop (`ENTITY_PROP`), a dog (`ENTITY_DOG`), a horse-drawn cart (`ENTITY_CART`, made
-- by `CreateCart`) or an animal (`ENTITY_ANIMAL`, made by `CreateAnimal`) - the kinds.
-- Its `id` is unique while it lives and `nil` from every reader once it is gone. A horse is simulated by its **controller** - the
-- client of the player who rides or minds it - and carries at most one **rider**; a loose horse is handed to the nearest player
-- within 30 m once a second. Entities live within a virtual world. These are the calls every kind
-- shares; horses, pickups, props, dogs, actors,
-- carts and animals have their own.

---Every entity in the world, or every entity of one kind.
---@param kind? number `ENTITY_HORSE`, `ENTITY_ITEM`, `ENTITY_NPC`, `ENTITY_PROP`, `ENTITY_DOG`, `ENTITY_CART` or `ENTITY_ANIMAL`; without it, every kind
---@return table a list of entity ids
function GetEntities(kind) end

---An entity's position and heading.
---@param id number the entity
---@return number x `x, y, z, yaw` in metres and degrees; `nil` when there is no such entity
---@return number y
---@return number z
---@return number yaw
function GetEntityPos(id) end

---Moves an entity.
---
---Its controller, if any, puts the real thing there; a static prop or a loose horse is moved outright on every screen. A
---ridden horse takes its rider along. Without `yaw` it keeps its heading.
---@param id number the entity
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw? number degrees
---@return boolean `false` when there is no such entity
function SetEntityPos(id, x, y, z, yaw) end

---What an entity is.
---@param id number the entity
---@return number `ENTITY_HORSE`, `ENTITY_ITEM`, `ENTITY_NPC`, `ENTITY_PROP`, `ENTITY_DOG`, `ENTITY_CART` or `ENTITY_ANIMAL`; `nil` when there is no such entity
function GetEntityKind(id) end

---What an entity is made of - the item class, the soul, the mesh path.
---
---A pickup: its item class GUID (`GetItemName` names it). A horse or a dog: the soul GUID (`GetSoulInfo`). A prop: the
---mesh path. An actor: its soul GUID.
---@param id number the entity
---@return string `""` when there is no such entity
function GetEntityTemplate(id) end

---An NPC actor's label; empty for everything else.
---@param id number the entity
---@return string the name over the actor's head; `""` for other kinds or no such entity
function GetEntityName(id) end

---Removes an entity from the world, for everyone.
---
---A horse under a rider dismounts them; a pickup vanishes; an actor's corpse is gone; a dog leaves. Anything a mode created
---is also removed by a reload.
---
---A horse in a running pull-down (`IsPlayerInPullDown`) is not removed at once - the game's pair is playing on it on the
---players' screens: it is destroyed when the pull-down ends, about six and a half seconds after it started, and the call
---returns `true` meanwhile with the horse still there.
---
---A body somebody carries, or an actor that carries one (`GetEntityCarrier`), ends the carry first: every screen lets go at
---once and `OnPlayerCarryEnd` hears `"destroyed"` - then the entity goes. A dead player's corpse is an entity: it goes with its corpse.
---@param id number the entity
---@return boolean `false` when there is no such entity
function DestroyEntity(id) end

---The player whose client simulates the entity.
---
---A horse's controller is the player who rides or minds it; a dog's is its master for life; a pickup, a prop and an actor have
---none (the server itself moves an actor).
---@param id number the entity
---@return number a pid; `nil` when nobody controls it
function GetEntityController(id) end

---Hands the simulation of an entity to a player, or to nobody.
---
---The way a horse changes hands: the new controller's client spawns and drives the real thing, the others see a puppet.
---`nil` gives it to nobody - it stands still until the minder hands it to the nearest player. Refused while someone else
---rides it.
---
---A horse in a running pull-down (`IsPlayerInPullDown`) keeps its controller until the pull-down ends, about six and a half
---seconds after it started: the call returns `true` and the hand-over is done then - unless the new controller has left by
---then or the horse has another rider by then - and an order for the player who controls it meanwhile cancels the waiting one.
---@param id number the entity
---@param pid number|nil the new controller; `nil` = nobody
---@return boolean `false` when refused
function SetEntityController(id, pid) end

---The player in the saddle of a horse.
---@param id number the entity
---@return number a pid; `nil` when nobody rides it (or it is not a horse)
function GetEntityRider(id) end

---Seconds since the entity's pose was last reported.
---
---A controlled horse reports its pose all the time, so its idle time stays near zero; a loose one counts up from the moment
---it was left. Since the creation for anything that never reported.
---@param id number the entity
---@return number seconds
function GetEntityIdleTime(id) end

---The virtual world the entity is replicated in.
---@param id number the entity
---@return number the world, `0` = the shared one; `nil` when there is no such entity
function GetEntityVirtualWorld(id) end

---Moves an entity into another virtual world.
---
---Only the players of that world see it from the next snapshot on. A ridden horse is refused - it is where its rider is.
---@param id number the entity
---@param world number the world; `0` = the shared one
---@return boolean `false` when refused or no such entity
function SetEntityVirtualWorld(id, world) end

---The entity nearest to a player, of a kind, within a radius.
---
---Horizontal distance, in the player's own virtual world only.
---@param pid number the player
---@param kind number|nil an entity kind; `nil` = any
---@param radius? number metres; without it, any distance
---@return number the entity `id` and its `distance` in metres; `nil` when none
---@return number
function GetNearestEntity(pid, kind, radius) end

-- ======== Carts =================================================================
-- Horse-drawn carts, entities of `ENTITY_CART`, of two **kinds**: the `"wagon"` (four wheels, two horses, six seats) and the
-- `"cart"` (two wheels, one horse between its shafts, three seats); `GetEntityTemplate` answers a cart's kind. A **route** is a road the server drives its carts along - a loop, or there and
-- back with a turn at each end - at a steady pace (`[carts] speed`, a horse's canter by default), slowing for its **stops** and
-- waiting there; a wagoner sits on the bench and players ride along. A **free cart** stands until a player takes the reins at
-- its bench; their client then drives it (the keys) and everyone sees it move.
-- Players get in with the game's own prompt - the reins by the bench of a free cart nobody drives, a seat anywhere else - and
-- out with the game's dismount key. **Seats**: `0` is at the reins, `1` the bench beside it; in the back of the wagon `2` and
-- `3` sit at its tail (right and left), `4` and `5` ahead of them; on the two-wheeled cart `0` is at the reins on the bed's
-- front edge, `1` and `2` on its right and left side rail. The mode sees every seat (`GetCartSeatPlayer`), moves a
-- seated player to another (`SetPlayerCartSeat`), keeps seats from the prompt (`SetCartSeatLocked`) and chooses the seat
-- a player gets (`OnPlayerEnterCart`). **Parts**: a cart is the game's own parts - a wagon's `body`, front `axle`, `wheels`,
-- `load` and the two horses' coats (`horse1`, `horse2`), a two-wheeler's `body`, `wheels`, `load` and `horse1` - each the mode's to set (`SetCartPart`) and to read in any
-- callback (`GetCartParts`); every screen shows the same, at once (personal carts has the
-- catalogue, a cart dealer and a cartwright). The owner records routes in the game with `/cartroute` (the routes guide) into the routes file
-- the server reads at its start; a mode adds its own with `AddCartRoute` (kept until the server stops unless
-- `SaveCartRoutes` writes them to the file) and places free carts with `CreateCart`. A seated player's position is the
-- seat's; a teleport, a death or the cart's end takes them out first.

---**Called by the server** - A player asks to get into a cart - return `false` to keep them out, or a seat number to seat them there.
---
---Runs when the player uses the cart's prompt, before they climb in: `seat` is the one they would get - `0` at the reins of
---a free cart, else a free seat that is not locked (`SetCartSeatLocked`): from the bench's prompt the one beside the
---reins first, from the back's the back on the player's side. Return `false` to keep them out, another seat's number to
---seat them there instead (it must be free - a locked one is fine, the reins of a route cart are not; a taken one keeps
---them out, told so), anything else to let them in on `seat`. Their game climbs onto the seat and `GetPlayerCart`
---answers from now on. It does not run for the mode's own `PutPlayerInCart`. What the cart is - its route
---(`GetCartRoute`), its parts (`GetCartParts`), who sits where (`GetCartSeatPlayer`) - is there to read, as in every
---cart callback.
---
---Return value: `false` keeps them out; a number is the seat they get instead; anything else lets them in
---@param pid number the player
---@param id number the cart
---@param seat number the seat they would sit on (`0` = at the reins)
function OnPlayerEnterCart(pid, id, seat) end

---**Called by the server** - A player left their seat in a cart.
---
---Their own dismount, `RemovePlayerFromCart`, a teleport (`SetPlayerPos`), a death, leaving the server, or the cart
---destroyed - they are out by now (`GetPlayerCart` answers `nil`). A driver letting go of the reins leaves the free cart
---standing where it is.
---@param pid number the player
---@param id number the cart
---@param seat number the seat they sat on
function OnPlayerExitCart(pid, id, seat) end

---**Called by the server** - A seated player moved to another seat of their cart.
---
---After `SetPlayerCartSeat` (or `PutPlayerInCart` on the cart they sit in) - `GetPlayerCart` answers the new seat
---already. From or to seat `0` of a free cart they took or let go of the reins.
---@param pid number the player
---@param id number the cart
---@param from number the seat they left
---@param to number the seat they sit on now
function OnPlayerChangeCartSeat(pid, id, from, to) end

---**Called by the server** - A route's cart pulled up at one of its stops and waits there.
---
---`stop` is the stop's name from the route (`""` for one without). The cart waits the stop's `wait` seconds, longer while
---someone climbs in or out, or as long as `HoldCart` says.
---@param id number the cart
---@param route string the route's name
---@param stop string the stop's name
function OnCartStop(id, route, stop) end

---**Called by the server** - A cart's horses ran out of stamina - they walk until they have caught their breath.
---
---Runs once each time the team's stamina (`GetCartStamina`) reaches `0` on a cart a player drives. The team then walks,
---whatever the driver asks, until its stamina is back to `30`; a walk or a stop brings it back (2 a second). How fast it runs
---dry is the cart's weight against its horses' pull and `SetCartStaminaRate`.
---@param id number the cart
function OnCartHorsesTired(id) end

---Puts a free cart in the world - a wagon with its two horses or a two-wheeler with one, standing until a player takes the reins.
---
---`kind` is the cart's kind - `"wagon"` (`nil` or `""` too) or `"cart"`, the two-wheeler. `z` below `0` or `nil` = on the ground.
---`world` is the virtual world (`nil` = `0`). `parts` is what it looks like, as `SetCartParts` takes it - a slot left
---out, or a part the server does not know (a line in the log), is the default. A cart that would stand in another cart of
---the same virtual world is put beside it instead - the nearest free spot to its left or right, up to three widths away (a
---line in the log says how far). `nil` when carts are off (`[carts] enabled`), the kind is unknown, the world is full or
---other carts fill the spot and both sides of it.
---@param kind? string `"wagon"` or `"cart"`; `nil` = `"wagon"`
---@param x number metres - the front axle's point (on a two-wheeler, where its horse stands)
---@param y number metres
---@param z? number metres; `nil` or below `0` = on the ground
---@param yaw? number degrees, the way it faces (`0` = +Y)
---@param world? number the virtual world; `nil` = `0`
---@param parts? table `{body =, axle =, wheels =, load =, horse1 =, horse2 =}` - any of the kind's slots; `nil` = the default cart
---@return number the cart's entity id; `nil` when it could not be made
function CreateCart(kind, x, y, z, yaw, world, parts) end

---Makes a route and sets its carts going.
---
---`route` is a table: `name` (1-32 letters, digits, spaces and `-_.'`), `points` - the road as a list of `{x, y, z}` (or
---`{x = , y = , z = }`; a `z` left out or below `0` is the ground's), at least two points and 10 m of road - `mode` (`"loop"`,
---the default: from the last point back to the first; `"back"`: to the last point and back again, turning round at both
---ends), `speed` (m/s; `nil` = `[carts] speed`), `carts` (how many drive it, spread evenly; `1`), `kind` (`"wagon"` or `"cart"`),
---`driver` (`false` = no wagoner on the bench), `driverSoul` (the wagoner's soul; `""` = a villager's), `parts` (what its
---carts look like, as `SetCartParts` takes it) and `stops`: a list of `{point = , name = , wait = }` - `point` the number
---of the point in `points` it stands at (from 1), `wait` seconds (30). The corners are rounded over a few metres. A route of
---the same name is replaced; its carts move onto the new road and take its parts (of another kind, new carts take their places). The route lasts until the server stops -
---`SaveCartRoutes` writes it into the routes file.
---@param route table `{name =, points =, mode =, speed =, carts =, kind =, driver =, driverSoul =, parts =, stops =}`
---@return boolean `false` when the route makes no road, its name is not one, or carts are off
function AddCartRoute(route) end

---Takes a route away, and its carts with it.
---@param name string the route's name
---@return boolean `false` when there is no such route
function RemoveCartRoute(name) end

---Writes every route into the routes file the server reads at its start.
---
---The file is `[carts] routes` for this level; the owner's `/cartroute save` writes the same one.
---@return boolean `false` when there is no file (`[carts] routes = ""`) or it could not be written
function SaveCartRoutes() end

---Every route - from the file, the admins' `/cartroute` and the mode's own.
---@return table a list of routes as `AddCartRoute` takes them (with every point's `z` filled in; `parts` the slots the route names)
function GetCartRoutes() end

---Puts a cart on a route, or takes it off (a free cart again).
---
---On a route the cart joins it at the point `startPoint` (from 1; the first by default) and a wagoner takes the bench -
---a player at its reins is put out of the seat first. `nil` takes it off: it stops where it is, a free cart without a
---wagoner.
---@param id number the cart
---@param route? string the route's name; `nil` = off any route
---@param startPoint? number the route's point it joins at (from 1)
---@return boolean `false` when it is not a cart or there is no such route
function SetCartRoute(id, route, startPoint) end

---The route a cart drives.
---@param id number the cart
---@return string the route's name; `nil` for a free cart
function GetCartRoute(id) end

---One cart's own pace - a route cart's travelling speed, or the most a player may drive it at.
---
---The speed in m/s (at most 15); `0` gives it back to its route's or the server's.
---@param id number the cart
---@param speed number m/s; `0` = the route's or the server's
---@return boolean
function SetCartSpeed(id, speed) end

---Keeps a route's cart standing - or sends it on at once.
---
---It pulls up where it is (slowing like at a stop) and stands `seconds` seconds; `0` ends a hold or a stop's wait at once.
---@param id number the cart
---@param seconds number how long it stands (at most 3600); `0` = on its way now
---@return boolean `false` when it is not on a route
function HoldCart(id, seconds) end

---Sits a player in a cart.
---
---`seat` is the one they get (`nil` = the first free one from the bench beside the reins on that is not locked; a seat
---given by number may be locked); `0` puts them at the reins of a free cart, their client driving it. A player farther
---away than the prompt reaches is put beside the cart first. Their game climbs in as it would at the prompt;
---`OnPlayerEnterCart` is not asked. A player in this cart already is moved to the seat, as `SetPlayerCartSeat` does.
---`false` when the seat is taken, the reins of a route cart are asked for, the player is knocked out (`IsPlayerKnockedOut`), or
---the player or the cart is not in the world (or not in the same virtual world). A player who carries or is carried is seated,
---and the carry ends (`OnPlayerCarryEnd` says `"cart"`).
---@param pid number the player
---@param id number the cart
---@param seat? number the seat (`0` = at the reins); `nil` = the first free one
---@return boolean
function PutPlayerInCart(pid, id, seat) end

---Takes a player out of their cart - their game climbs down.
---@param pid number the player
---@return boolean `false` when they sit in no cart
function RemovePlayerFromCart(pid) end

---The cart a player sits in, and the seat.
---@param pid number the player
function GetPlayerCart(pid) end

---The players in a cart, the one at the reins first.
---@param id number the cart
---@return table a list of player ids (`{}` = empty)
function GetCartPassengers(id) end

---Moves a seated player to another seat of their cart.
---
---On the bench (`0`-`1`) or in the back (`2`-`5`) they move over at once; between the bench and the back their game climbs
---down and up again, so the cart must stand for that (on the two-wheeler: between the reins and a side rail). Seat `0` of a free cart hands them the reins; leaving it lets go of
---them (the cart stands). A locked seat (`SetCartSeatLocked`) is the mode's to give. `OnPlayerChangeCartSeat` follows.
---`false` when they sit in no cart, the seat is taken or there is none, the reins of a route cart are asked for, they are
---still climbing in (or moving already), or the cart moves on a move between the bench and the back.
---@param pid number the player
---@param seat number the seat (`0` = at the reins)
---@return boolean
function SetPlayerCartSeat(pid, seat) end

---How many seats a cart has.
---@param id number the cart
---@return number the seats (`6` for the wagon: `0` to `5`; `3` for the two-wheeler); `0` for anything that is not a cart
function GetCartSeatCount(id) end

---Who sits on one seat of a cart.
---
---A player still climbing in counts - the seat is theirs from the moment the server gave it.
---@param id number the cart
---@param seat number the seat (`0` = at the reins)
---@return number the player's id; `nil` when the seat is free (or there is none)
function GetCartSeatPlayer(id, seat) end

---Keeps a seat of a cart from the use key - or gives it back.
---
---The cart's prompt never hands a locked seat out and `PutPlayerInCart` without a seat skips it; the mode's own seats
---still go there (`PutPlayerInCart` with the seat, `SetPlayerCartSeat`, a seat `OnPlayerEnterCart` returns). With
---seat `0` locked the bench's prompt offers a seat instead of the reins - the driver is the mode's choice. Whoever sits
---there already stays. The locks last as long as the cart.
---@param id number the cart
---@param seat number the seat (`0` = at the reins)
---@param locked? boolean `false` unlocks it; `nil` = `true`
---@return boolean `false` when it is not a cart or there is no such seat
function SetCartSeatLocked(id, seat, locked) end

---Whether a seat of a cart is locked.
---@param id number the cart
---@param seat number the seat (`0` = at the reins)
---@return boolean `true` when `SetCartSeatLocked` locked it
function IsCartSeatLocked(id, seat) end

---Changes one part of a cart - its body, axle, wheels, load or a horse - on every screen at once.
---
---The game builds all its wagons on one chassis, so any part goes with any other. `slot` and `part` on a `"wagon"`:
---
---| Slot | Parts |
---|---|---|
---| `body` | `a` (the default), `b` (boards lying in its bed), `b_plain` (the same, empty), `c` (long, with ladder sides); `a_covered`, `b_covered`, `c_covered` - under a canvas cover |
---| `axle` | `b` (the default), `b_covered` - the front axle with the pole |
---| `wheels` | `b_covered` (the default), `b`, `polygonal` |
---| `load` | `none` (the default), `sacks`, `charcoal`, `carpets`, `stones`, `hay_small`, `hay_medium`, `hay_large`, `goods`, `junk`, `cabbage` |
---| `horse1`, `horse2` | the left and the right horse's coat: `black`, `bay_dun`, `chestnut`, `light_grey`, `buckskin`, `palomino`, `seal_brown`, `dark_grey`, `red_roan`, `brown` |
---
---On a two-wheeled `"cart"`:
---
---| Slot | Parts |
---|---|---|
---| `body` | `b` - the body with its shafts, the only one |
---| `wheels` | `b` - the only one |
---| `load` | `none` (the default), `goods` (barrels, a basket, sacks), `market` (baskets and a barrel), `sacks`, `cabbage` (wicker sides full of cabbages) |
---| `horse1` | the horse's coat, the same as a wagon's |
---
---`nil` or `""` gives the slot back its default (a horse its cart's own coat). The change shows at once, while the cart
---drives and with players in it too. A route's carts take the route's parts again when the route is replaced.
---@param id number the cart
---@param slot string `"body"`, `"axle"`, `"wheels"`, `"load"`, `"horse1"` or `"horse2"`
---@param part? string the part (any case); `nil` or `""` = the default
---@return boolean `false` when it is not a cart, or the slot or the part is none of its kind's
function SetCartPart(id, slot, part) end

---Changes several parts of a cart at once.
---
---Each `slot = part` as `SetCartPart` takes it; the ones it refuses leave their slot as it was.
---@param id number the cart
---@param parts table `{body =, axle =, wheels =, load =, horse1 =, horse2 =}` - any of them
---@return boolean `false` when any was refused (the others are set)
function SetCartParts(id, parts) end

---What a cart has in one slot.
---@param id number the cart
---@param slot string `"body"`, `"axle"`, `"wheels"`, `"load"`, `"horse1"` or `"horse2"`
---@return string the part (the default when it was never set); `nil` for no cart or a slot its kind has not
function GetCartPart(id, slot) end

---Every part of a cart - what it looks like, to show, to price or to save.
---@param id number the cart
---@return table `{body =, axle =, wheels =, load =, horse1 =, horse2 =}` (a two-wheeler's: `body`, `wheels`, `load`, `horse1`); `{}` for anything that is not a cart
function GetCartParts(id) end

---The slots a cart of a kind has - a shop's menu.
---@param kind? string the cart's kind; `nil` = `"wagon"`
---@return table the wagon's `{"body", "axle", "wheels", "load", "horse1", "horse2"}`, the two-wheeler's `{"body", "wheels", "load", "horse1"}`; `{}` for no such kind
function GetCartPartSlots(kind) end

---The parts a slot takes - a shop's shelf.
---@param slot string `"body"`, `"axle"`, `"wheels"`, `"load"`, `"horse1"` or `"horse2"`
---@param kind? string the cart's kind; `nil` = `"wagon"`
---@return table the part names, the default first (the horses' coats in the game's order); `{}` for a slot the kind has not
function GetCartPartNames(slot, kind) end

---Puts one of the game's models on a cart - it rides with it, on every screen.
---
---`model` is a mesh of the game's files (a path ending in `.cgf` or `.cga`, as the meshes list
---them). It sits in the cart body's own frame: `x` metres to its right, `y` ahead, `z` up from the body's origin (a wagon's
---bed is about `1` up, a two-wheeler's about `0.95`), within 8 m, turned by `pitch` / `roll` / `yaw` in degrees and scaled
---`0.05` - `10`. `material` puts one of the game's materials (a `.mtl` path) on it instead of its own. A prop is only drawn:
---nothing collides with it and nobody picks it up. A cart takes up to 16; they go with the cart. Change one with
---`SetCartProp`, take it off with `RemoveCartProp`; admins try models with `/cart prop <model> [x y z [yaw [scale]]]`.
---@param id number the cart
---@param model string the mesh, e.g. `"objects/manmade/common_furniture/barrels/barrel_beer.cgf"`
---@param x number metres to the body's right
---@param y number metres ahead
---@param z number metres up
---@param pitch? number degrees; `nil` = `0`
---@param roll? number degrees; `nil` = `0`
---@param yaw? number degrees; `nil` = `0`
---@param scale? number `nil` = `1`
---@param material? string a `.mtl` path of the game's; `nil` = the model's own
---@return number the prop's id on this cart (1-16), or `nil` (not a cart, a bad path or number, 16 already)
function AddCartProp(id, model, x, y, z, pitch, roll, yaw, scale, material) end

---Changes a prop of a cart in place - another model, place, turn, scale or material.
---
---The same numbers as `AddCartProp`; the prop keeps its id.
---@param id number the cart
---@param prop number the prop's id
---@param model string the mesh
---@param x number metres to the body's right
---@param y number metres ahead
---@param z number metres up
---@param pitch? number degrees
---@param roll? number degrees
---@param yaw? number degrees
---@param scale? number `nil` = `1`
---@param material? string a `.mtl` path; `nil` = the model's own
---@return boolean `false` for no such prop or a bad value
function SetCartProp(id, prop, model, x, y, z, pitch, roll, yaw, scale, material) end

---Takes a prop off a cart.
---@param id number the cart
---@param prop number the prop's id
---@return boolean `false` for no such prop
function RemoveCartProp(id, prop) end

---Takes every prop off a cart.
---@param id number the cart
---@return number how many there were
function ClearCartProps(id) end

---The props on a cart - for a mode that saves a player's cart.
---@param id number the cart
---@return table `{{id =, model =, x =, y =, z =, pitch =, roll =, yaw =, scale =, material =}, ...}` (`material` `nil` for the model's own); `{}` for none
function GetCartProps(id) end

---Gives a part of a cart another of the game's materials - its wood a different colour.
---
---`slot` is `"body"`, `"axle"`, `"wheels"` or `"load"`; `material` one of the game's `.mtl` files made for that part's
---mesh - another mesh's material draws it wrong (parts of it vanish). The `b` wagon parts (the bodies `"b"`, `"b_plain"`,
---`"b_covered"`, both axles, the wheels `"b"` and `"b_covered"`) take the game's wood variants
---`objects/manmade/vehicles/wagons/wagon_b_new.mtl` (their own), `wagon_b_darker.mtl`, `wagon_b_new_b.mtl`,
---`wagon_b_new_c.mtl`, `wagon_b_prague.mtl` and `wagon_b_gypsy.mtl`; the `a` and `c` bodies (`"a"` is the default) and the
---polygonal wheels have their own material only - give a cart a `b` body first (`SetCartPart`) to change its wood. The
---two-wheeler's take `objects/manmade/vehicles/carts/cart_a.mtl` to `cart_e.mtl` (`cart_b.mtl` its own). `nil` gives the
---part its own back. It stays when `SetCartPart` changes the slot. A free colour is not offered: the game's materials do
---not take one.
---@param id number the cart
---@param slot string `"body"`, `"axle"`, `"wheels"` or `"load"`
---@param material? string a `.mtl` path of the game's; `nil` = the part's own
---@return boolean `false` for no cart, a horse slot, a slot its kind has not or a bad path
function SetCartPartMaterial(id, slot, material) end

---The material a part was given, or `nil` for its own.
---@param id number the cart
---@param slot string `"body"`, `"axle"`, `"wheels"` or `"load"`
---@return string the `.mtl` path, or `nil`
function GetCartPartMaterial(id, slot) end

---Puts a player's horse in front of a cart, in place of its own horse or an empty slot.
---
---The horse (an `ENTITY_HORSE`, a player's or the mode's) leaves everyone's view as itself and the cart draws it in the
---slot with its coat; it keeps its owner, stats and saddlebags, and its strength counts in what the team pulls
---(`GetCartPull`). `slot` `1` is `horse1`, `2` `horse2` (a wagon's right), `0` the first slot without a player's horse -
---an empty slot (`"none"`, `SetCartPart`) first. Nobody rides a hitched horse, and a dead one is unhitched; moving it with
---`SetEntityPos` (a "call my horse" command) takes it out of the cart first. A cart made
---with no horses at all (`CreateCart` with `{horse1 = "none", horse2 = "none"}`) cannot move until one is hitched: its
---bench offers a seat, never the reins. Whether a player may hitch, and which horses suit a cart, is the mode's - a stable,
---a command, a price (`SetHorseType`).
---@param id number the cart
---@param horse number the horse
---@param slot? number `1`, `2`, or `0` / `nil` = the first free
---@return boolean `false` when it is not a cart or a horse, the slot is not the kind's or a player's horse is there, or the horse is ridden, dead or down, in front of another cart or in another virtual world
function HitchHorse(id, horse, slot) end

---Takes a player's horse from a cart; it stands beside it again.
---
---The slot is left empty (`"none"`) - give it the cart's own horse back with `SetCartPart` and a coat. `slot` `0` takes
---the first player's horse there is.
---@param id number the cart
---@param slot? number `1`, `2`, or `0` / `nil` = the first hitched
---@return number the horse, standing beside the cart; `nil` when no player's horse was there
function UnhitchHorse(id, slot) end

---The player's horse hitched in a slot of a cart.
---@param id number the cart
---@param slot number `1` or `2`
---@return number the horse, or `nil` (the cart's own horse, none, or not a cart)
function GetCartHorse(id, slot) end

---The cart a horse is hitched to, and its slot.
---@param horse number the horse
function GetHorseCart(horse) end

---Says how much a cart carries - the weight its horses pull.
---
---The mode keeps a cart's goods its own way; this is their weight in kilograms. The team pulls the cart's own weight (a
---wagon 350 kg, a two-wheeler 120), the load and 80 kg a seated player, against its horses' pull: a horse type's pull
---(`SetHorseTypeRule`: a cart's own horse 750 kg) with up to 30 % more or less for a player horse's strength. Up to
---0.6 of the pull the cart goes at its full pace; past it the top pace falls, to a walk at 1.6 times the pull and a crawl
---past 2.5. The heavier, the sooner the horses tire. `SetCartLoadFactor` says how much the weight counts.
---@param id number the cart
---@param kg number kilograms, `0` or more
---@return boolean `false` for no cart or a weight below `0`
function SetCartLoad(id, kg) end

---The weight the mode put on a cart (kilograms).
---@param id number the cart
---@return number kilograms; `0` for none or no cart
function GetCartLoad(id) end

---How much a cart's weight slows its horses - `0` never, `1` as it is, more for heavier going.
---@param id number the cart
---@param factor number `0` or more; `1` by default
---@return boolean `false` for no cart or a factor below `0`
function SetCartLoadFactor(id, factor) end

---How much a cart's weight counts against its horses.
---@param id number the cart
---@return number the factor, `1` by default; `0` for no cart
function GetCartLoadFactor(id) end

---How fast a cart's horses tire - `0` never, `1` as they do, more for sooner.
---
---A cart a player drives spends its team's stamina at a trot (an empty wagon: about eight minutes) and faster at a canter
---(about two), the heavier the faster; a horse's vitality makes it last longer. A walk or a stop brings it back.
---@param id number the cart
---@param rate number `0` or more; `1` by default
---@return boolean `false` for no cart or a rate below `0`
function SetCartStaminaRate(id, rate) end

---How fast a cart's horses tire.
---@param id number the cart
---@return number the rate, `1` by default; `0` for no cart
function GetCartStaminaRate(id) end

---Sets a cart team's stamina - fresh horses at a station, tired ones after a long road.
---@param id number the cart
---@param stamina number `0` - `100`
---@return boolean `false` for no cart
function SetCartStamina(id, stamina) end

---A cart team's stamina, `0` - `100`.
---@param id number the cart
---@return number the stamina; `0` for no cart
function GetCartStamina(id) end

---What a cart's team pulls against what it carries, and the pace that leaves - for a mode's own rules and messages.
---@param id number the cart
---@return table `{horses =, pull =, weight =, ratio =, maxSpeed =, stamina =, tired =}`: the horses in front of it, what they pull and what the cart weighs (kilograms), the weight against the pull (`math.huge` with no horse), the top pace it allows (metres a second), the team's stamina and whether it walks to rest; `nil` for no cart
function GetCartPull(id) end

-- ======== Horses ================================================================
-- A horse is a world entity of `ENTITY_HORSE` simulated by its **controller** - the client of the player who rides or minds it;
-- the others see a puppet following its pose. Its **soul** is the breed, a key of the Horse archetype of
-- the souls. Players get a horse with the `/horse` built-in (an admin command by default); a mode gives one
-- with `CreateHorse` and puts a player in the saddle with `MountPlayer`. A mounted player's position and velocity are the
-- horse's. A horse may have an **owner** (`SetHorseOwner`; a horse made for a player is theirs): it is their horse in the game -
-- its saddlebags open from their inventory and hold their things whoever happens to be simulating it, and they get on with the
-- game's plain "Mount" - while anyone else gets "Mount and steal" (`OnPlayerStealHorse` decides). **The saddlebags are the
-- server's record**: it keeps what each horse carries (`GetHorseItems`), whoever holds the bags, and fills the copy on the
-- screen of the player whose game holds them - the owner's, else the rider's, else the one whose game simulates the horse. What
-- that player moves between their bag and the saddlebags changes the record only for what the server's item records let go of, and
-- an item that appears in the saddlebags with nothing to explain it is taken out under `enforce` (the
-- item check). How players come by horses -
-- a horse seller, a stable, a reward - is the mode's to build; a player may own several. **The server forgets every horse when
-- it stops**: a mode that keeps them saves the breed (`GetEntityTemplate`), the coat (`GetHorseCoat`), the gear
-- (`GetHorseGear`), the saddlebags (`GetHorseItems`) and the stats it gave (`GetHorseStats`) - on `OnHorseItemsChange` and
-- `OnPlayerDisconnect` - and makes the horse again (`CreateHorse` with the breed and the coat, `SetHorseGear`,
-- `SetHorseItems`, `SetHorseStat`). The mode's own id for a saved
-- horse rides on it with `SetEntityData`: the entity id is new every time the horse is made. A rider whose head meets a low
-- branch at speed, or whom the horse throws, falls off as in the game - the fall, the lying still and the get-up are seen on every
-- screen and reach the mode as `OnPlayerThrown`; `ThrowPlayerFromHorse` does it on order, and `SetPlayerRiderHeadHit` /
-- `SetPlayerRiderThrow` switch it off. A player on foot can also pull a rider off the horse with the game's own take-down move
-- (the "Pull down" prompt on a rider's body): **off for everyone until a mode allows it** (`SetPlayerPullDown`); the server checks
-- the reach and pace, pvp, teams and parties, the mode has the last word and the chance (`OnPlayerPullDown`, `OnPlayerPulledDown`),
-- and `PullPlayerFromHorse` does it on order.

---**Called by the server** - The player is in the saddle of a horse.
---@param pid number the player
---@param id number the horse
function OnPlayerMount(pid, id) end

---**Called by the server** - The player got off the horse - or left while riding, or the horse was destroyed.
---@param pid number the player
---@param id number the horse
function OnPlayerDismount(pid, id) end

---**Called by the server** - The player was thrown off the horse they ride - a low branch, the horse, or the mode's own order.
---
---The game's own rider fall: a head hit on a branch or a beam at speed, a horse throwing its rider, or `ThrowPlayerFromHorse`.
---The rider's game plays the fall, the lying still and the get-up by itself, and every player who sees them sees the same fall on
---their body. It comes **before** `OnPlayerDismount` of the same fall. The server takes the rider's game's word for a fall
---only within 4 metres of where it last had them and not within 3 seconds of the one before; such a fall plays on the rider's
---own screen alone and is not told here. For the few seconds the fall lasts
---(`IsPlayerThrown`) the server lets the rider's body move faster than a walker may, in the measure of the saddle - a body
---tumbling along the ground is not a speed hack. Anything that moves the player on the server's word - a death, a respawn,
---`SetPlayerPos`, a new ride - ends that allowance early.
---
---`cause` is one of `THROW_HEAD_HIT` (a branch or a beam), `THROW_HORSE` (the horse threw them), `THROW_OTHER` (their game threw
---them and the server could not tell why) and `THROW_MODE` (`ThrowPlayerFromHorse`). `flung` is `true` for the game's strong
---throw, the one a rearing horse gives.
---@param pid number the rider
---@param id number the horse they fell from
---@param cause number `THROW_HEAD_HIT`, `THROW_HORSE`, `THROW_OTHER` or `THROW_MODE`
---@param flung boolean `true` when it was the game's strong throw
function OnPlayerThrown(pid, id, cause, flung) end

---**Called by the server** - A player on foot asks to pull a rider off their horse - return `false` to refuse, or the chance it works.
---
---The game's take-down move: the player on foot takes hold of a rider from the side of the horse, the two play the game's own
---pair, and the rider is thrown off and falls (or, when the pull fails, stays in the saddle). Only a player you allowed
---(`SetPlayerPullDown`) gets the prompt. By the time this runs the server has checked the ask - both players stand in the
---world (neither dead) in one virtual world, the puller is on foot and the rider is in the saddle of a horse, neither is in a
---pull-down or a fall, a cart, flying, a dice match, a shop or a dialogue, the puller's game can play the move, both are in view of
---each other, pvp is on and the two are neither teammates nor party members (as for a blow), no wall is between them when the
---server's line-of-sight rule is on, and the horse is within the weapon's reach and not faster than the weapon allows. The game's own numbers are a sword, an axe, a mace or a sabre 2.5 m
---and 6 m/s, a longsword 3 m and 7, a halberd 4 m and 8, bare hands 2 m and 4; the server allows 1.5 m more of reach and 1 m/s more
---of pace than those, because the positions it goes by are a few frames old, so a sword pulls a horse up to 4 m away that goes up
---to 7 m/s, and bare hands one up to 3.5 m away at up to 5 m/s. A dagger, a flail, a shield, a torch, a bow or a gun cannot pull
---anyone down (the server knows the weapon from the game's tables export; without the export every drawn weapon but a torch
---counts as a sword). Each refusal a rule makes (pvp, teams, parties, the weapon, the reach, the pace) tells the puller why in
---the chat, at most once every 15 seconds; a missing right, a busy or invalid pair of players and a wall in the way only reach
---the server's log.
---This is the mode's say on top: return `false` to refuse (nothing plays; the puller reads "You cannot pull Hans off the
---horse."), a number from `0` to `1` for the chance the pull works (`0` plays the failed pair, `1` always works; a number
---outside is held to the nearer end), anything else - nothing, `nil`, `true`, or an error in the callback - lets it stand at a
---chance of `1`. The server rolls the outcome itself, so every screen plays the same
---one. A cooldown, a protection time or a price belong here; `OnPlayerPulledDown` tells how it ended.
---
---A player the mode pulls with `PullPlayerFromHorse` does not come through here.
---
---Return value: `false` refuses; a number from `0` to `1` is the chance it works; anything else lets it stand
---@param pid number the player pulling
---@param victim number the rider
---@param id number the horse
function OnPlayerPullDown(pid, victim, id) end

---**Called by the server** - A pull-down is over - the rider was thrown off the horse, or the pull failed.
---
---`success` is `true` when the game's take-down threw the rider off the horse - it comes **before** the `OnPlayerDismount` of
---the same fall - and `false` when the pull failed and the rider is still in the saddle (told when the pair's animation ends,
---about four and a half seconds after the start). It does not run when the pull-down was cut short before its outcome showed: a
---death, a disconnect, a `SetPlayerPos`, a spawn, a cart seat, a flight. Nor does it run for a pull that was to land when the
---rider's game never took them out of the saddle (a game that failed to play it): a mode that sets something at
---`OnPlayerPullDown` - a busy flag, a pending price - should let it expire by time rather than wait for this callback. The two
---players are in a fight from the start of the pull-down (`OnFightStart`). For a few seconds around the pair
---(`IsPlayerInPullDown`) the server lets both bodies move as the game's pair moves them - an aligned step, a tumble - where a
---walker's speed would be refused; that holds within about eight metres of where they stood when it began, and the ground and the
---walls are checked as ever. The fall is the game's own ragdoll and get-up; whatever it costs the rider - health, a wound - is
---for the mode to decide here.
---@param pid number the player who pulled
---@param victim number the rider
---@param id number the horse
---@param success boolean `true` when the rider was thrown off, `false` when the pull failed
function OnPlayerPulledDown(pid, victim, id, success) end

---**Called by the server** - A player got on a horse another player owns - return `false` to put them off it.
---
---The game's own "Mount and steal": the thief is already in the saddle on their screen. Return `false` and they are put off
---it (the horse goes back to its owner if the owner is in the world, else it stands still) and the horse is not handed to
---them again for a minute. Anything else lets the theft stand - `OnPlayerMount` follows, and the horse stays its owner's
---(`SetHorseOwner` to give it to the thief). The saddlebags stay the owner's either way.
---
---Return value: `false` refuses; anything else lets them ride it
---@param pid number the thief
---@param id number the horse
---@param owner number whose horse it is
function OnPlayerStealHorse(pid, id, owner) end

---**Called by the server** - The player whistled for their horse with the game's own whistle.
---
---The game's call for the horse, on foot (at most once a second). Their own screen shows the whistle, but no horse comes by
---itself: bring theirs with `MoveActor` - it walks or gallops to them around the walls and stops where you send it - and play
---the whistle's sound for the others with `PlaySound` (`v_horse_whistle`). Nothing happens unless the mode does it.
---@param pid number the player
function OnPlayerWhistle(pid) end

---**Called by the server** - What a horse's saddlebags hold or what it wears changed - the moment to save it.
---
---The server's record of the saddlebags changed because the player whose game holds them (the owner, else the rider, else the
---one whose game simulates the horse) moved something between their bag and the saddlebags and the server accepted it, or
---that player's game reported a saddle or bridle put on or taken off. Read the new state with
---`GetHorseItems` and `GetHorseGear`. It does not run for the mode's own `SetHorseItems` / `SetHorseGear`, nor while a
---fill of the server's is still landing on the holder's screen. A mode that saves horses writes on this and on
---`OnPlayerDisconnect` instead of on a timer.
---@param id number the horse
function OnHorseItemsChange(id) end

---**Called by the server** - A player hit a horse - change the damage, cancel it, or let it through.
---
---The shape of `OnActorDamage` without the body part, and the same return rules: a number replaces the damage (`0`
---cancels), `false` cancels, nothing keeps it. The blow went through the same model as a hit on a person's body - the attacker's
---weapon, no armour on the horse, the same wherever it lands - and a horse takes a third of it: about 8 short-sword slashes kill
---one. The server has already refused a blow on the horse the attacker rides, and one on another
---player's horse (its rider's, else its owner's) where they could not hit that player - pvp off, the same team, the same party.
---At `0` health the horse dies (`OnHorseDeath`).
---
---Return value: a number replaces the damage (`0` cancels); `false` cancels the hit; nothing keeps it
---@param id number the horse
---@param attacker number the player who struck
---@param damage number what the horse is about to lose (of `100`)
---@param zone number the attack zone the attacker's game recorded
---@param weapon string the weapon's table name; `""` bare-handed
---@param dtype string `"stab"`, `"slash"`, `"smash"` or `""`
function OnHorseDamage(id, attacker, damage, zone, weapon, dtype) end

---**Called by the server** - A horse died.
---
---A blow took its last health (`attacker` the player), `SetHorseHealth` `0` did, or its own game killed it (a fall; `-1`).
---It lies on every screen, nobody can mount it, its rider is off it - thrown, where their throws are on (`SetPlayerRiderThrow`;
---`OnPlayerThrown` follows with `THROW_HORSE`), else set on foot beside it at once (`OnPlayerDismount` follows) - and the
---body is removed a minute later (`DestroyEntity` sooner). A mode that keeps horses marks it dead here.
---@param id number the horse
---@param attacker number the player whose blow killed it; `-1` = nobody
function OnHorseDeath(id, attacker) end

---Puts a horse in the world.
---
---`controllerPid` is the player whose client simulates it (usually the one it is for); with `nil` nobody does and it stands
---still until the server hands it to the nearest player within 30 m. `world` is the virtual world (`nil` = the controller's;
---`0` without one). `soul` is the breed - a Horse-archetype soul by name (`Horse2`, `Pebbles`), id or GUID from
---the horse souls; `nil` = the server's `[spawn] horse_soul`; a key that is not a horse makes no horse.
---`coat` is its colour with mane and tail, one of `GetHorseCoats`, on from the first moment; `nil` = a pick from the ten
---coats that changes with the horse's id (two horses can share one; the soul does not decide it), and a coat that is no coat
---makes no horse.
---`nil` when the world is full (`[world] max_entities`).
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw number degrees (`0` without)
---@param controllerPid? number the player whose client simulates it; `nil` = nobody yet
---@param world? number the virtual world; `nil` = the controller's
---@param soul? string|number the breed - a horse soul's name, id or GUID; `nil` = the server default
---@param coat? string the coat, one of `GetHorseCoats` (`"chestnut"`); `nil` = the pick that goes with the horse's id
---@return number the horse's entity id; `nil` when it could not be made
function CreateHorse(x, y, z, yaw, controllerPid, world, soul, coat) end

---Puts a player in the saddle of a horse.
---
---Control goes to the player and their client mounts the horse - it may be anywhere; the game walks or teleports the player
---onto it. `false` when it is not a horse, someone else rides it, the player is not in the world, the player is in a
---pull-down (`IsPlayerInPullDown`) or is knocked out (`IsPlayerKnockedOut`); also while the horse is part of a running
---pull-down that is not already the player's to control - it cannot change hands until the pull-down ends, a few seconds on.
---A player who carries or is carried is mounted, and the carry ends (`OnPlayerCarryEnd` says `"mounted"`).
---@param pid number the player
---@param id number the horse
---@return boolean
function MountPlayer(pid, id) end

---The horse the player rides right now.
---@param pid number the player
---@return number the horse's entity id; `nil` on foot
function GetPlayerMount(pid) end

---Has a rider's game throw them off their horse, the fall every player sees.
---
---The rider's own game plays the throw - the fall, the lying still, the get-up - so it is the game's real fall, not a teleport,
---and every player who has their body sees it. The order goes to their game; the throw itself follows a moment later, and
---`OnPlayerThrown` (cause `THROW_MODE`) tells you it happened. It may not happen at all: a game that cannot play the throw
---(an unsupported build) is refused up front, and one that declines it after all simply never answers - the order lapses after
---two seconds. By default the rider is flung backward off the horse's rear, the throw a rearing horse gives; `flung` set to
---`false` drops them where they sit instead, the fall of a head hit on a branch.
---
---`false` with the reason as the asker reads it when the player is not connected, not in the world, dead, not on a horse,
---already falling or being pulled off their horse (`OnPlayerPulledDown`), cannot be thrown by the rules
---(`SetPlayerRiderThrow`), or their game cannot play the throw.
---@param pid number the rider
---@param flung? boolean `true` or `nil` for the backward throw off the horse's rear (the default); `false` for the plain drop
---@return boolean `true` when the order went out; `false` and the reason when it did not
---@return string
function ThrowPlayerFromHorse(pid, flung) end

---Whether the player is in the fall of a rider thrown off their horse.
---
---`true` from the throw (`OnPlayerThrown`) for the few seconds the fall, the lying still and the get-up take - the span in
---which the server lets their body move faster than a walker may - and `false` otherwise, on foot or in the saddle.
---@param pid number the player
---@return boolean
function IsPlayerThrown(pid) end

---Turns the head hit on low branches and beams on or off for a rider - the game's own throw.
---
---The game throws a rider whose head meets a branch, a beam or a canopy at speed; it is on by default, as in the game.
---With `false` the rider passes under the obstacle instead - no fall, no `OnPlayerThrown` - while a horse throwing them
---and `ThrowPlayerFromHorse` still work (`SetPlayerRiderThrow` turns those off too). It lasts until you change it or the
---player leaves, through respawns, and is sent to their game with every spawn: call it once in `OnPlayerSpawn` for a mode
---where the trees are not a danger.
---@param pid number the rider
---@param enabled? boolean `false` for no fall from a head hit; `true` (the default, also when left out) for the game's own rule
---@return boolean `false` when the player is not connected
function SetPlayerRiderHeadHit(pid, enabled) end

---Turns the throws off for a rider - a head hit, the horse and ThrowPlayerFromHorse no longer take them off their horse.
---
---With `false` none of those throws this rider: not a head hit, not the horse, not `ThrowPlayerFromHorse` (which then
---answers `false` and the reason). On by default, as in the game. It lasts until you change it or the player leaves, through
---respawns, and is sent to their game with every spawn. `SetPlayerRiderHeadHit` alone keeps the rest.
---
---A pull-down is not a throw: it is another player's move, with its own switch (`SetPlayerPullDown`, who may pull) and its
---own veto (`OnPlayerPullDown`, which can refuse it for a rider), and neither that nor `PullPlayerFromHorse` reads this
---setting: a mode that keeps a rider in the saddle refuses their pull-downs there as well.
---@param pid number the rider
---@param enabled? boolean `false` for no head hit, horse or ThrowPlayerFromHorse throw; `true` (the default, also when left out) for the game's own rules
---@return boolean `false` when the player is not connected
function SetPlayerRiderThrow(pid, enabled) end

---Lets a player pull riders off their horses with the game's take-down move - off by default.
---
---With `true` the game shows its "Pull down" prompt on a rider's body for this player (on foot, near a horse, in the game's
---own reach), and their ask reaches `OnPlayerPullDown`. **Off for everyone until a mode turns it on**, like every new rule:
---without it no prompt shows and the server refuses the ask. It is per player, lasts until you change it or the player
---leaves, through respawns, and is sent to their game with every spawn - call it once in `OnPlayerSpawn` for a mode where
---riders can be taken off their horses. The rider needs nothing set: anyone in the saddle can be pulled down by a player you
---allowed, unless `OnPlayerPullDown` says otherwise.
---@param pid number the player who may pull
---@param enabled boolean `true` to allow; `false` (the default) for no pull-downs
---@return boolean `false` when the player is not connected
function SetPlayerPullDown(pid, enabled) end

---Whether the player may pull riders off their horses.
---@param pid number the player
---@return boolean `true` after `SetPlayerPullDown` allowed it, `false` otherwise (the default, and for a player who is not connected)
function GetPlayerPullDown(pid) end

---Has a player on foot pull a rider off their horse - the game's take-down, on order.
---
---The same move as the prompt, done on your word: the puller (on foot, beside the horse) and the rider play the game's pair
---on their own screens and on those of everyone who has all three bodies, the two are in a fight from the start (where
---`[combat] pvp` allows fights), and
---`OnPlayerPulledDown` tells the outcome. It skips the weapon's reach and the horse's pace, pvp, teams and parties, the wall
---check, the rider's `SetPlayerRiderThrow` rule, the player's right (`SetPlayerPullDown`) and `OnPlayerPullDown`.
---`success` `false` plays the failed pair - the rider stays in
---the saddle; `nil` or `true` throws them off.
---
---`false` and the reason ("The rider is not on a horse.", "They are 9.1 m apart (6 m at most)." ...) when the puller and the
---rider are one player, the rider is not in the saddle of a horse, the puller is dead or either player is not standing in the
---world, the rider is in another virtual world, either player is in a pull-down or a fall already, in a cart, flying, playing
---dice, in a shop or a dialogue, the puller is on a horse, the puller is more than 6 metres from the
---horse or the two do not have each other's bodies yet, or the puller's game cannot play the move (an
---unsupported build).
---@param victim number the rider
---@param puller number the player who pulls them off
---@param success? boolean `false` for the failed pair; `true` or `nil` (the default) for the pull that throws the rider off
---@return boolean `true` when the pull-down started; `false` and the reason when it did not
---@return string
function PullPlayerFromHorse(victim, puller, success) end

---Whether the player is pulling a rider down or being pulled off a horse right now.
---
---`true` from the start of a pull-down for both players - the one pulling and the rider - until a couple of seconds after the
---game's pair ends: the span in which the server lets both bodies move as the pair moves them. `false` otherwise.
---@param pid number the player
---@return boolean
function IsPlayerInPullDown(pid) end

---Makes a horse a player's - or nobody's.
---
---The owner's horse is theirs in the game on their screen (its saddlebags in their inventory, the plain "Mount") and its
---saddlebags hold their things whoever simulates it; they go to the new owner here - the horse keeps what it carries, and nobody's bag gains or loses by the handover. Anyone
---else gets on it as a thief (`OnPlayerStealHorse`). A horse made for a player (`CreateHorse` with a `pid`, the `/horse`
---built-in) is theirs from the start; `nil` makes it nobody's - then its bags go with its rider, else with whoever simulates it. A player may own
---several horses; the game shows one of them as "your horse" (the newest). The owner leaving the server makes it nobody's -
---after `OnPlayerDisconnect`, where it is still theirs: the place to save it or take it out of the world.
---@param id number the horse
---@param pid? number the new owner; `nil` = nobody
---@return boolean `false` when it is not a horse, or when `pid` is not a connected player
function SetHorseOwner(id, pid) end

---Whose horse it is.
---@param id number the horse
---@return number the owner's player id; `nil` = nobody's
function GetHorseOwner(id) end

---Every horse in the world the player owns.
---@param pid number the player
---@return table a list of horse entity ids (`{}` for none)
function GetPlayerHorses(pid) end

---What a horse's saddlebags hold.
---
---The server's record of the saddlebags: what `SetHorseItems` made them, changed by what the player whose game holds them
---moved in or out and the server accepted. The record is the server's whoever holds the bags, and a player whose game shows
---more in the saddlebags than this has the excess taken out under `[audit] mode = "enforce"`. **The server forgets every horse when it stops**, bags and all: a
---mode that keeps horses saves this list with `GetHorseGear` and the breed (`GetEntityTemplate`), and makes the horse again
---next time. One of the mode's **tagged items** (`GivePlayerTaggedItem`) in the bags is an entry of its own with its `id`,
---`name` and `text` - save them with it, and `SetHorseItems` puts it back with its tag.
---@param id number the horse
---@return table a list of `{class=, amount=, health=, quality=}` (`quality` when known; a tagged item also `id=, name=, text=`; `{}` = empty); `nil` when it is not a horse
function GetHorseItems(id) end

---Makes a horse's saddlebags hold exactly this list.
---
---What was in them is gone, the list's items are there - in the server's record and in the copy on the screen of the player
---whose game holds the bags (the owner, else the rider, else the one who simulates the horse), which the server fills and
---checks the player's game made - so the item check counts them as the horse's and taking them out is no cheat. A horse
---nobody holds keeps the list for whoever holds it next. A class is any key of
---the item catalogue; an unknown one is logged and skipped, money is left out (no saddlebag holds it),
---and 64 stacks at most, 65 535 to a stack. When a saved horse comes back, dress it first (`SetHorseGear`), then fill it. An
---entry with an `id` is one of the mode's **tagged items** (one item, its `name` and `text` shown in the game's item panel).
---@param id number the horse
---@param items table a list of `{class=, amount=, health=, quality=}` (`amount` 1 and `health` 100 when left out, `quality` the class's own; `id`, `name`, `text` for a tagged item), as `GetHorseItems` returns it
---@return boolean `false` when it is not a horse
function SetHorseItems(id, items) end

---What a horse wears - its saddle, bridle, saddlebags and caparison.
---
---The item classes (GUIDs) of the gear, as the game of the player who holds the horse's bags (the owner, else the rider, else
---the one who simulates it) last reported it, or as `SetHorseGear` made it. A horse fresh from `CreateHorse` wears the game's
---default outfit for its breed until that player's game reports it.
---@param id number the horse
---@return table a list of item class GUIDs (`{}` = nothing); `nil` when it is not a horse
function GetHorseGear(id) end

---Dresses a horse in exactly this gear, on every screen.
---
---Whatever the horse wore comes off and the list's items go on - a saddle, a bridle, saddlebags, a caparison (the catalogue's
---`HorseGear` category). A class is any key of the item catalogue; an unknown one is logged and
---skipped. What the saddlebags hold stays in them (`SetHorseItems`). Players arriving later see the same.
---@param id number the horse
---@param classes table a list of item keys (GUIDs or names), as `GetHorseGear` returns it
---@return boolean `false` when it is not a horse
function SetHorseGear(id, classes) end

---The horse the player rides, or else the newest one they own, or else one they control.
---@param pid number the player
---@return number a horse's entity id; `nil` when they have none
function GetPlayerHorse(pid) end

---Sets a stat of a horse to a level, exactly.
---
---`stat` is `strength`, `agility`, `vitality` or `courage`; `level` is `0` .. `30`. These are the stats the game keeps for the
---animal itself, and the set is **exact**: the level is what it says, lowering a higher one included. The horse shows it on
---every screen that has it - the rider's, the others', and the screens of players who come into view later. A horse never
---set has its breed's own. A `0` is a level like any other: it is stored and sent as an exact `0`, it does not give the breed's
---own back, and `GetHorseStat` answers `0` for it just as for a stat never set - only `GetHorseStats` tells the two apart. The stats belong to the horse in the world and go with it: the server forgets them when the horse
---is destroyed or the server stops, so a mode that keeps horses saves the levels it gave (`GetHorseStats`) and sets them
---again when it makes the horse again. The stats of a player's own character are `SetPlayerStat`'s.
---@param id number the horse
---@param stat string `"strength"`, `"agility"`, `"vitality"` or `"courage"`
---@param level number `0` .. `30`
---@return boolean `false` when it is not a horse, the name is no horse stat, or the level is outside `0`..`30`
function SetHorseStat(id, stat, level) end

---The level a mode set on a horse's stat.
---
---`0` means either that the stat was never set (the horse has its breed's own) or that a mode set it to exactly `0` with
---`SetHorseStat`; the call cannot tell the two apart. `GetHorseStats` lists only the stats a mode set, a `0` among them.
---@param id number the horse
---@param stat string `"strength"`, `"agility"`, `"vitality"` or `"courage"`
---@return number `0` .. `30`; `0` = never set (the breed's own) or set to `0`, or it is no horse
function GetHorseStat(id, stat) end

---Every stat a mode set on a horse.
---
---What `SetHorseStat` gave the horse, by name - the thing to save with a horse a mode keeps. A stat that was never set is
---not in it; one set to `0` is, with `0` - this is the call that tells the two apart.
---@param id number the horse
---@return table|nil `{strength = 25, courage = 10}`; `{}` when none was set; `nil` when it is not a horse
function GetHorseStats(id) end

---Sets a horse's coat - its colour, mane and tail - on every screen.
---
---`coat` is one of `GetHorseCoats` (`"black"`, `"chestnut"`, `"palomino"` ...; any case), the same coats a cart's horses wear
---(`SetCartPart`'s `horse1` / `horse2`). The horse changes at once on every screen that has it, the rider's included, and
---keeps its gear. A horse never given one wears a pick from the ten coats that changes with the horse's id (two horses can share
---one) - so a mode that keeps horses saves the coat (`GetHorseCoat`) and gives it back, best straight in `CreateHorse` so it never shows another.
---`nil` or `""` goes back to the pick.
---@param id number the horse
---@param coat? string one of `GetHorseCoats`; `nil` = the pick that goes with the horse's id again
---@return boolean `false` when it is not a horse or the coat is no coat
function SetHorseCoat(id, coat) end

---The coat a horse wears.
---
---The coat `SetHorseCoat` or `CreateHorse` gave it, else the pick it shows now - either way the name to save, so the
---horse comes back the same colour.
---@param id number the horse
---@return string|nil one of `GetHorseCoats`; `nil` when it is not a horse
function GetHorseCoat(id) end

---The coats a horse can wear.
---@return table `{"black", "bay_dun", "chestnut", "light_grey", "buckskin", "palomino", "seal_brown", "dark_grey", "red_roan", "brown"}`
function GetHorseCoats() end

---A horse's health.
---
---`0` .. `100`; `100` when it is made. A player's blow or arrow takes the model's damage off it (`OnHorseDamage`); at `0` it
---is dead (`OnHorseDeath`). The server forgets it with the horse: a mode that keeps horses saves it and gives it back with
---`SetHorseHealth`.
---@param id number the horse
---@return number|nil `nil` when it is not a horse
function GetHorseHealth(id) end

---Sets a living horse's health.
---
---`0` .. `100` (more is `100`); raising it heals the horse. `0` kills it now - on every screen, its rider off it -
---and `OnHorseDeath` runs with no attacker. Refused on a dead horse: it stays dead until it is removed.
---@param id number the horse
---@param health number `0` .. `100`
---@return boolean `false` for a dead horse or anything but a horse
function SetHorseHealth(id, health) end

---No blow hurts the horse.
---
---A hit on it is refused before `OnHorseDamage` (`false` = it takes hits again). The mode's own `SetHorseHealth` still
---works.
---@param id number the horse
---@param invulnerable? boolean `true` (the default) or `false`
---@return boolean `false` for anything but a horse
function SetHorseInvulnerable(id, invulnerable) end

---Makes a horse a cart horse, a riding horse or a type of the mode's - what it pulls and how it goes under a rider.
---
---A horse's type (`SetHorseTypeRule`) says what it pulls in front of a cart (`HitchHorse`) and its pace under a rider
---against a riding horse's. The server knows `"riding"` (every horse given none: pulls 350 kg, the full pace) and `"draft"`
---(pulls 750 kg, 0.95 of the pace - a cart's own horses pull as draft horses); a mode adds its own. So a good cart horse is no
---racer and a racer no cart horse. A rider's horse takes the type's pace through the game's own speed effects on the horse.
---`nil` or `""` makes it a riding horse again. The server forgets a horse's type when it forgets the horse: a mode that keeps
---horses saves it with them.
---@param id number the horse
---@param type? string a type's name (any case); `nil` = `"riding"`
---@return boolean `false` for anything but a horse, or a type nobody made
function SetHorseType(id, type) end

---A horse's type.
---@param id number the horse
---@return string the type (`"riding"` when it was given none); `nil` for anything but a horse
function GetHorseType(id) end

---Makes a horse type or changes one - what one horse of it pulls and its pace under a rider.
---
---`pull` is what one horse of the type pulls at a cart's full pace, in kilograms (`0` - `10000`; a horse's strength adds or
---takes up to 30 %); `ride` its pace under a rider against a riding horse's, `0.95` - `1.15` (the game's own speed effects on the
---horse make it, so it comes out as `0.95`, `1`, `1.10` or `1.15`, the nearest; a pace above `1` also takes a fifth off its
---saddlebags). The game has no slower effect that leaves a ridden horse able to run, so a slower type is not possible yet. Up to 64 types; a name is
---1 - 32 letters, digits, `_` and `-`. The horses of the type change at once, ridden or hitched.
---@param type string the type's name
---@param pull number kilograms
---@param ride? number the pace under a rider; `nil` = `1`
---@return boolean `false` for a bad name or number, or 64 types already
function SetHorseTypeRule(type, pull, ride) end

---What a horse type pulls and its pace under a rider.
---@param type string the type's name
---@return table `{name =, pull =, ride =}`; `nil` for no such type
function GetHorseTypeRule(type) end

---Every horse type's name - a stable's list.
---@return table the names, `"draft"` and `"riding"` among them
function GetHorseTypes() end

-- ======== Props =================================================================
-- A **prop** is a static mesh of the game's object files placed in the world for everyone in range to see - a barrel, a fence, a
-- table, a stone - like a pickup nobody can take. The mesh is a key of the mesh list: the id, the file's
-- name (`barrel_a`, when only one file carries it) or the path. A static prop stands where it is placed and blocks the way; a
-- **rigid** one is a physics body on each client - pushable, but its motion is not synchronised, so a barrel one player kicks stays
-- put for the others. The `/prop` and `/props` built-ins place and search them.
-- 
-- An **interaction point** is an invisible spot with a use prompt of yours (`CreateInteraction`): a notice board to read, a
-- house's sign, a well to drink from - the player looks at it, the game's own use hint shows your text, and the use key calls
-- `OnPlayerInteract`. A prop takes a prompt the same way (`SetEntityPrompt`). A door takes a row of yours with
-- `SetDoorPrompt`.

---**Called by the server** - A player pressed the use key on an interaction point or a prop with a prompt.
---
---Fires for an interaction point or a prop with a prompt when a player in its world, within
---reach, presses the use key while the game shows its hint. Nothing else happens by itself: what the use does is yours to write.
---@param pid number the player
---@param id number the point's or the prop's entity id
function OnPlayerInteract(pid, id) end

---Places an invisible spot with your use prompt - "Read the notices", "View the house", "Drink".
---
---An entity of `ENTITY_INTERACTION` that nobody sees: a player who looks at it from close by gets the game's own use hint with
---your text (as written, up to 48 characters; one that starts with `@` is a text key of the game's own), and the use key calls
---`OnPlayerInteract`. `size` is the round area to look at, in metres (`0.6` by default, `0.2` to `3`): about a man's height
---tall from the point up, so put the point on the ground or the floor under what it stands for. `SetEntityPrompt` changes its
---text, `DestroyEntity` removes it, a reload removes them all. `world` is the virtual world (`nil` = the shared one).
---@param x number metres
---@param y number metres
---@param z number metres (the foot of the spot)
---@param label string the use prompt
---@param size? number the round area to look at, metres (`0.6`)
---@param world? number the virtual world; `nil` = the shared one
---@return number the point's entity id; `nil` for an empty prompt or a full world
function CreateInteraction(x, y, z, label, size, world) end

---The use prompt on a prop or an interaction point (an actor's too).
---
---A prop with a prompt shows the game's use hint with your text while a player looks at it, and the use key calls
---`OnPlayerInteract`; `nil` or `""` takes a prop's prompt off. On an interaction point it changes the text (a point keeps one -
---`DestroyEntity` removes it). On an NPC actor it is `SetActorPrompt`. As written, up to 48 characters.
---@param id number the prop, point or actor
---@param text string|nil the prompt; `nil` = none
---@return boolean `false` for anything else (a horse, a pickup, an animal ...)
function SetEntityPrompt(id, text) end

---An entity's use prompt.
---@param id number the entity
---@return string `""` when it has none
function GetEntityPrompt(id) end

---Whether players walk into a prop or through it.
---
---A static prop is solid unless you say otherwise: players, horses and arrows stop at it. `false` lets everyone walk through
---it - a decoration in a doorway, a sign over a path; `true` makes it solid again, at once on every screen. Meshes the game
---makes no collision for on their own (one built of several collision pieces, such as a crate or a shrine) get one made for them
---while they are solid. A rigid prop (`CreateProp` with `rigid`) is a physics body and always solid.
---@param id number the prop
---@param solid? boolean `true` (the default) solid, `false` walked through
---@return boolean `false` for anything that is not a static prop
function SetPropCollision(id, solid) end

---Whether a prop is solid.
---@param id number the prop
---@return boolean `true` for a solid prop (the default, and every rigid one); `false` for one made walk-through, or anything that is not a prop
function IsPropSolid(id) end

---Places a static mesh in the world.
---
---An entity of `ENTITY_PROP` every client in range shows. `mesh` is a key of the mesh list; without the
---tables export only a path passes. `scale` is uniform (`1` = the mesh's own size); `rigid` makes it a physics body on each
---client (false = static); `world` is the virtual world (`nil` = the shared one). Nobody controls a prop, nobody mounts or
---takes it; `DestroyEntity` removes it, a reload removes them all. `nil` when the mesh resolves to nothing or the world is
---full.
---@param mesh string|number the mesh's id, file name or path
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw? number degrees (`0` without)
---@param scale? number uniform scale (`1`)
---@param rigid? boolean `true` = a pushable physics body on each client; `false` = static
---@param world? number the virtual world; `nil` = the shared one
---@return number the prop's entity id; `nil` when it could not be made
function CreateProp(mesh, x, y, z, yaw, scale, rigid, world) end

---The path a mesh key stands for.
---@param key string|number the mesh's id, file name or path
---@return string the path (`objects/manmade/.../barrel_a.cgf`); `nil` when the key resolves to nothing or to several files
function GetMeshPath(key) end

---Meshes whose path holds every word of a pattern.
---@param pattern string words to look for in the path, case-insensitive
---@param max? number at most this many (`10`)
---@return table a list of `{id=, path=, name=}`
function FindMeshes(pattern, max) end

---A prop's scale.
---@param id number the entity
---@return number the uniform scale; `1` for anything but a prop
function GetEntityScale(id) end

---Whether a prop is a physics body.
---@param id number the entity
---@return boolean `true` for a rigid prop
function IsEntityRigid(id) end

-- ======== Siege engines =========================================================
-- Siege engines, entities of `ENTITY_SIEGE`, of four **kinds** (`GetSiegeKinds`): the `"trebuchet"` - the game's own, throwing a
-- stone 100-330 m - and the `"cannon"`, the game's bombard, firing a ball up to about 400 m; `GetEntityTemplate` answers an
-- engine's kind. A player **works** one with the game's use prompt beside it: they take the operator's place, **aim** by holding
-- the right mouse button and looking (the engine turns to the point under their crosshair at its own pace and sets its throw for it - a mark on their screen shows where
-- the shot will come down), press **R** to load it and the **left mouse button** (or **F**) to fire, and the use prompt again to let it
-- go - walking off, mounting a horse or dying lets go too. A trebuchet winds its arm down before each load; the shot leaves a moment
-- after the fire (the sling's swing, the cannon's fuse). The server flies every shot and decides where it comes down - against the
-- level's collision and heightmap when the server has them, else on the shooter's word, checked against the arc - and the impact hurts
-- every player and actor within the kind's radius (the operator is the attacker: the kills are theirs) and takes structure from the
-- engines near it: an engine at 0 % is **wrecked** until `SetSiegeEngineHealth` repairs it. The mode can refuse a player's hand
-- (`OnSiegeEngineAction`), spare a player (`OnPlayerSiegeHit`), work an engine itself (`AimSiegeEngine`, `LoadSiegeEngine`,
-- `FireSiegeEngine`), limit its shots (`SetSiegeEngineShots`) and tune one engine's timing, reach and damage
-- (`SetSiegeEngineRules`). Admins place them with `/siege`.
-- 
-- The third kind is the **siege ladder**, `"ladder"`: the game's own 10 m ladder of the siege battles, leaning against a wall, climbed
-- with the game's own climb. A player on the wall at its top **knocks it down** by holding the use key: it falls outward, everyone on
-- it comes down with it - hurt by how high they were (`OnPlayerSiegeHit`) - and it lands on whoever stands in its way. A player at
-- the foot of a fallen ladder **raises** it with the use key. The mode can do both (`PushSiegeLadder`, `RaiseSiegeLadder`) and
-- refuse either (`OnSiegeEngineAction`); the other engines' shots break a ladder like any engine.
-- 
-- The fourth is a **pile of stones**, `"stones"`: the defenders' hurling stones of the game's own sieges, nine on a wall walk. A
-- player beside it **lifts** one with the use key, holds it while they look where it should fall - over the wall, onto the attackers
-- below - and **throws** it with the left mouse button (or **F**); the use key again puts it back. A stone hurts whoever it lands on
-- and knocks a climber off a siege ladder; a thrown stone is back on the pile 20 s later. The mode can refuse a lift or a throw
-- (`OnSiegeEngineAction`), count the stones itself (`SetSiegeEngineShots`) and tune the pile (`SetSiegeEngineRules`); nothing
-- wrecks it.

---**Called by the server** - A player puts a hand to a siege engine - return `false` to refuse.
---
---Runs before the server acts on the player's use prompt (`"operate"`: they would take the operator's place) or on its operator's
---keys (`"load"`, `"fire"`) - on a siege ladder, `"push"` (they knock it down from its top) or `"raise"` (they stand a fallen one
---up from its foot); at a pile of stones, `"lift"` (they take a stone up) or `"throw"` (they throw the stone they hold). The
---server's own checks come first: the player is near it and on foot, nobody else works it, it is not wrecked. Return `false` to
---refuse - tell the player why, the server says nothing more. Letting go (a stone put back) is never asked.
---
---Return value: `false` refuses; anything else lets it happen
---@param pid number the player
---@param id number the engine
---@param action string `"operate"`, `"load"` or `"fire"`; a ladder's `"push"` or `"raise"`; a pile's `"lift"` or `"throw"`
function OnSiegeEngineAction(pid, id, action) end

---**Called by the server** - A siege engine's shot left it - the sling let go, the fuse burned down.
---@param id number the engine
---@param shooter number the player who fired it; `-1` = the mode (`FireSiegeEngine` with nobody at it)
---@param shot number the engine's shot number (counts from 1)
function OnSiegeShot(id, shooter, shot) end

---**Called by the server** - A siege engine's shot came down - after its damage went out.
---
---`x`, `y`, `z` is where it struck, and `what` says what it struck:
---
---- `"player"` - a player's body in its way (`target` = the player)
---- `"actor"` - a server actor's body in its way (`target` = the actor's entity id)
---- `"engine"` - another siege engine, a siege ladder or a pile of stones (`target` = its entity id)
---- `"gate"` - within 6 m of a gate the server knows (`GetGates`; `target` = the gate's key)
---- `"wall"` - the level's solid geometry over the ground: a wall, a house, a rock (`target` = `nil`)
---- `"ground"` - the terrain (`target` = `nil`); a server without the level's heightmap reports every other impact as `"ground"`
---
---The engine may be gone by now (it was removed while the shot flew). The rest is the mode's - open a gate struck often enough
---(`SetGateState`), switch a level layer (`SetLevelLayer`), count the hits on a wall.
---@param id number the engine that fired it
---@param x number metres
---@param y number metres
---@param z number metres
---@param shooter number the player who fired it; `-1` = the mode
---@param shot number the engine's shot number
---@param what string `"player"`, `"actor"`, `"engine"`, `"gate"`, `"wall"` or `"ground"`
---@param target number|string|nil the player, the actor's or engine's entity id, the gate's key - `nil` for a wall and the ground
function OnSiegeImpact(id, x, y, z, shooter, shot, what, target) end

---**Called by the server** - Another engine's shot is about to damage a siege engine - return the damage to apply.
---
---Runs for every siege engine within the shot's radius of the point it came down on: a trebuchet, a cannon, a siege ladder or a
---pile of stones. `damage` is what the shot takes off its structure (`SetSiegeEngineHealth`: 100 is whole, 0 wrecks it) - up to
---60 for a trebuchet's stone, 35 for a cannon ball, less the farther off it came down (`SetSiegeEngineRules`). Return a number
---to take that instead (`0` or `false` spares it), nothing to take `damage`. An engine that falls to 0 is wrecked
---(`OnSiegeEngineDestroyed`). Not asked: an engine that can not be wrecked (`SetSiegeEngineHealth` below 0), and a stone
---hurled from a pile (it breaks no engine).
---
---Return value: a number - the damage to apply instead; `false` = none; nothing = `damage`
---@param target number the engine it would damage
---@param id number the engine that fired the shot
---@param shooter number the player who fired it; `-1` = the mode
---@param damage number the structure it would take off
function OnSiegeEngineHit(target, id, shooter, damage) end

---**Called by the server** - A siege engine's shot is about to hurt a player - return the damage to apply.
---
---Runs for every player within the shot's radius of the point it came down on (a wall between them shields them when the server
---has the level's collision). `damage` is the kind's at that distance - a player's health is 100: the trebuchet's stone kills
---within about 2.5 m and grazes at 5, the cannon's ball kills within about 1.5 m. A knocked-down siege ladder comes here too: for
---each climber it threw off, as they come down (`100` at its very top, less the lower they were), then for whoever it lands on
---(`25`) - `shooter` is who knocked it down. Return a number to apply that instead (`0` or `false` spares them), nothing to apply
---`damage`.
---
---Return value: a number - the damage to apply instead; `false` = none; nothing = `damage`
---@param pid number the player it would hurt
---@param id number the engine that fired it
---@param shooter number the player who fired it; `-1` = the mode
---@param damage number the damage it would do
function OnPlayerSiegeHit(pid, id, shooter, damage) end

---**Called by the server** - A siege engine was wrecked - by another engine's shots, or by the mode.
---
---Its structure fell to 0 (`SetSiegeEngineHealth` says how much it has). A wreck stands where it was: nobody can work it until
---`SetSiegeEngineHealth` repairs it, or `DestroyEntity` removes it. A broken siege ladder lies on the ground in pieces, and
---whoever climbed it came down with it.
---@param id number the engine
---@param by number the player whose shot wrecked it; `-1` = the mode (`SetSiegeEngineHealth` with `0`) or a shot nobody fired
function OnSiegeEngineDestroyed(id, by) end

---Stands a siege engine in the world - a trebuchet, a cannon, a siege ladder or a pile of stones.
---
---It faces `yaw` - where it throws (a trebuchet stands with its crew's end behind it: give it room, its frame is some 10 m wide
---and 12 m long). `z` below `0` or `nil` = on the ground there, which needs the level's heightmap or navmesh on the server
---(the terrain guide) - the shots leave from the engine's height; without them give `z`
---(`GetPlayerPos` has it). It stands at rest, unloaded, with no shot limit and a whole structure; `DestroyEntity` removes it.
---
---A `"ladder"` stands up against its wall: (`x`, `y`, `z`) is its foot and `yaw` the way it leans - toward the wall, its foot
---about 2 m out from it. With the level's collision data on the server (the collision guide) the
---ladder is made as long as the wall is high - its top just over the wall walk, for walks from about 5 to 14 m up; without it,
---it is the game's 10 m ladder, its top 2 m on that way and 9.5 m up (the walls of Suchdol fit it exactly).
---
---A `"stones"` pile lies at (`x`, `y`, `z`) - give the wall walk's own height, a step from the parapet: its thrower stands
---beside it and throws from where they stand. It starts full (9 stones).
---@param kind string `"trebuchet"`, `"cannon"`, `"ladder"` or `"stones"` (`GetSiegeKinds`)
---@param x number metres
---@param y number metres
---@param z? number metres; `nil` or below `0` = on the ground
---@param yaw? number degrees, the way it throws (`0` = +Y) - a ladder's, the way it leans
---@param world? number the virtual world; `nil` = `0`
---@return number the engine's entity id; `nil` for an unknown kind, a full world or a ground the server cannot find
function CreateSiegeEngine(kind, x, y, z, yaw, world) end

---The kinds of siege engine there are.
---@return table a list of names: `{"trebuchet", "cannon", "ladder", "stones"}`
function GetSiegeKinds() end

---Every siege engine in the world.
---@return table a list of entity ids
function GetSiegeEngines() end

---A siege engine as it stands - its phase, operator, aim, structure and shots.
---
---`phase` is `"rest"`, `"winding"` (a trebuchet's arm going down), `"loading"`, `"loaded"`, `"firing"` or `"destroyed"` (and
---`"cocked"`: a trebuchet wound with no stones left to load); `secondsLeft` is the running phase's time. `aim` is the point it is
---aimed at (`nil` until something aimed it: it throws straight ahead); `pitch` and `speed` are the throw the aim takes (degrees,
---m/s), `range` its reach on level ground, and `inReach` is `false` when the aim lies beyond its limits - it throws as far (or, a
---cannon, as high) as it can. `health` is its structure in percent (`-1`: nothing can wreck it); `shots` the shots left (`-1` = no
---limit); `fired` how many it fired. A siege ladder's `phase` is `"up"`, `"falling"`, `"down"`, `"raising"` or `"destroyed"`; it has
---no operator, aim or shots. A pile of stones' is `"rest"`, `"lifting"`, `"holding"` or `"throwing"`: its `operator` is the
---player with its stone in their hands, `aim` where the last one was thrown, `shots` the stones on it.
---@param id number the engine
---@return table `{kind =, phase =, operator =, yaw =, aim =, pitch =, speed =, range =, inReach =, health =, shots =, fired =, secondsLeft =}` (`operator` a player or `nil`, `aim` `{x =, y =, z =}` or `nil`, `secondsLeft` `nil` when no phase runs); `nil` when it is no siege engine
function GetSiegeEngineInfo(id) end

---The siege engine a player works.
---@param pid number the player
---@return number the engine's id; `nil` when they work none
function GetPlayerSiegeEngine(pid) end

---Puts a player at a siege engine as its operator, or takes its operator away.
---
---The player works it from wherever they stand - walking off lets go of it, as it does for anyone. Someone else working it lets
---go. A player works one engine at a time.
---@param id number the engine
---@param pid? number the player; `nil` = nobody works it
---@return boolean `false` when it is no engine, it is wrecked, or the player is not in its world
function SetSiegeEngineOperator(id, pid) end

---Aims a siege engine at a point.
---
---It turns there at its own pace (within its traverse, `SetSiegeEngineRules`) and sets its throw for the point - within its reach
---(`GetSiegeEngineInfo`'s `inReach` says whether it gets there). An operator's look aims it the same way while they work it, so
---the mode's aim lasts until they look elsewhere.
---@param id number the engine
---@param x number metres
---@param y number metres
---@param z number metres
---@return boolean `false` when it is no engine or it is wrecked
function AimSiegeEngine(id, x, y, z) end

---Loads a siege engine, as its operator's R would.
---
---A trebuchet winds its arm down first (35 s), then takes its stone (6 s); a cannon takes its powder and ball (10 s). Nobody needs
---to work it. It is refused - the second value says why, in the words a player would read - while it is busy, loaded already,
---wrecked, or out of shots.
---@param id number the engine
function LoadSiegeEngine(id) end

---Fires a loaded siege engine, as its operator's fire key would.
---
---The shot leaves a moment later - a trebuchet's sling lets go 2 s into the swing, a cannon's fuse burns 1.5 s - along the engine's
---aim (`AimSiegeEngine`; never aimed: straight ahead). Its operator, if anyone works it, is the shooter. Refused (the second
---value says why) when it is not loaded.
---@param id number the engine
function FireSiegeEngine(id) end

---Limits the shots a siege engine has left.
---
---Each shot that leaves it takes one; at `0` it loads no more (its operator reads "No stones left." / "No balls left."). `-1` (the
---default) = no limit. A pile of stones counts the stones on it (9 when full, never more than its `capacity`) - a lift takes one,
---a stone put back or come back after its `refillSeconds` adds one.
---@param id number the engine
---@param shots? number the shots left; `-1` or `nil` = no limit
---@return boolean `false` when it is no engine
function SetSiegeEngineShots(id, shots) end

---Sets a siege engine's structure - wrecks it, repairs it, or makes it unbreakable.
---
---In percent: a new engine has `100`, and the other engines' shots near it take it down (`structureDamage`,
---`SetSiegeEngineRules`). `0` wrecks it (`OnSiegeEngineDestroyed` runs, its operator lets go - a ladder's climbers come down
---with it); more repairs a wrecked one - it stands at rest again, unloaded (a ladder lies whole, to be raised); below `0` nothing
---can wreck it.
---@param id number the engine
---@param percent number `0`-`100`; below `0` = it cannot be wrecked
---@return boolean `false` when it is no engine
function SetSiegeEngineHealth(id, percent) end

---Tunes one siege engine - its timing, reach, turning and damage.
---
---`rules` is a table; a key left out keeps the kind's own. The cycle in seconds: `windSeconds` (a trebuchet's winding, 35),
---`loadSeconds` (6; a cannon 10), `fireSeconds` (the whole firing - the arm settling, the smoke clearing: 16 and 3.5; never shorter
---than the release). Its reach on level ground in metres: `minRange` and `maxRange` (a trebuchet throws anywhere between - about
---100 and 330 -, a cannon's `maxRange` is its charge at its highest wedge, about 400). `turnRate` (degrees a second: 6 and 15) and
---`traverse` (degrees either way from where it faces now; `180` = all round, the default, `0` = only where it faces). The impact:
---`damage` at the point (200 and 150 - a player's health is 100), `radius` (6 and 4 m) and `fullRadius` (1.5 and 1 m: beyond it
---the damage falls off to nothing at the radius), `structureDamage` (60 and 35: the percent of another engine's structure a hit at
---the point takes). `operateRange`: how near its operator stands (9 and 3.5 m). `crew` (a trebuchet's): how many of its two
---winches a player's winding needs manned - 2 by default, `0` = its operator winds it alone; the crew stand at the winches behind
---its frame (the use key there) and pull while it winds. A mode's own `LoadSiegeEngine` winds it without them.
---
---A siege ladder takes `fallSeconds` (its fall once knocked down, 2.6), `raiseSeconds` (standing it up again, 6), `damage` (what a
---climber at its very top takes from the fall, 100 - less the lower they were, a quarter of it whoever it lands on),
---`operateRange` (how near its top a player knocks it down and its foot one raises it, 2.5 m) and `polearmToPush` (`true`, the
---default: a player knocks it down only with a hooked polearm in their weapons or their bags - a guisarme, a billhook, a poleaxe, a
---halberd or a pitchfork, not a glaive or a bardiche; the polearm is back in their bag after the push; `false`: anyone may); the
---engines' other keys mean nothing to it. A pile of stones takes `capacity` (the stones a full pile
---holds, 9), `refillSeconds` (how long a thrown stone takes to come back, 20; `0` = never - refill it with
---`SetSiegeEngineShots`), `damage`, `radius` and `fullRadius` (a stone's blow: 60, 1.2 and 0.4 m) and `operateRange` (how
---near the pile a player lifts a stone, 2.2 m).
---@param id number the engine
---@param rules table `{windSeconds =, loadSeconds =, fireSeconds =, minRange =, maxRange =, turnRate =, traverse =, damage =, radius =, fullRadius =, structureDamage =, operateRange =, crew =, fallSeconds =, raiseSeconds =, polearmToPush =, capacity =, refillSeconds =}`
---@return boolean `false` when it is no engine
function SetSiegeEngineRules(id, rules) end

---Knocks a standing siege ladder down.
---
---As a player's push from its top would: it falls outward from its wall, everyone on it comes down with it - hurt by how high they
---were, as they land (`OnPlayerSiegeHit`) - and it lands on whoever stands in its way. Nobody is credited with the damage.
---Refused (the second value says why) unless it stands.
---@param id number the ladder
function PushSiegeLadder(id) end

---Stands a fallen siege ladder up against its wall again.
---
---As a player's use key at its foot would: it swings back up over its raise time (`SetSiegeEngineRules`' `raiseSeconds`, 6 by
---default) and can be climbed once it stands. Refused (the second value says why) unless it lies whole on the ground.
---@param id number the ladder
function RaiseSiegeLadder(id) end

-- ======== Dogs ==================================================================
-- A player's **dog**: a world entity of `ENTITY_DOG` whose controller is its master for life. On the master's screen it is the
-- game's own companion - it follows, waits or roams on the game's dog AI, it can be praised - and everyone in range sees the same
-- dog following them. One dog per player; it goes with the master's disconnect or `DestroyEntity`. A following dog comes along
-- when its master respawns or is moved more than 30 m by `SetPlayerPos` - it appears two metres behind them; a dog told to
-- stay or roam stays where it is. The `/dog` built-in gives the caller one (and sends it away on the second call); `/dog stay`,
-- `/dog follow` and `/dog free` set its mode.
-- 
-- The mode is the dog's state bag key `mode` (`GetEntityState`), a number of the game's own list: `DOG_STAY` 0, `DOG_FOLLOW` 1
-- (the default), `DOG_FREE` 2, `DOG_AGGRESSIVE` 3, `DOG_SEARCH` 4, `DOG_HUNT` 5, `DOG_GUARD` 6, `DOG_AMBUSH` 7. Stay, follow and
-- free are the tested ones.

---Gives a player a dog that follows them.
---
---`soul` is the dog's soul - one of the Dog archetype from the dog souls by name, id or GUID; `nil` = the
---plain dog. Its colour is its coat, the same on every screen: a pick that changes with each new dog, or the one
---`SetDogCoat` gives it. `x, y, z, yaw` is where it appears; without them, two metres in front of the master. A player who
---already has a dog gets the one they have. `nil` when the player is not in the world or the world is full.
---@param pid number the master
---@param soul? string|number a dog soul's name, id or GUID; `nil` = the plain dog
---@param x? number metres; without a point the dog appears in front of the master
---@param y? number metres
---@param z? number metres
---@param yaw? number degrees
---@return number the dog's entity id; `nil` when it could not be made
function CreateDog(pid, soul, x, y, z, yaw) end

---The player's dog.
---@param pid number the player
---@return number the dog's entity id; `nil` when they have none
function GetPlayerDog(pid) end

---Tells a dog to stay, follow or roam.
---
---`mode` is one of the game's dog modes - `DOG_STAY` (0), `DOG_FOLLOW` (1, what a new dog does), `DOG_FREE` (2) and the
---others of the list above. It is kept on the dog's state bag as `mode`, so it survives the master walking out of range and
---back, and `GetEntityState``(dog, "mode")` reads the same number. False for an id that is not a dog or a mode outside 0-7.
---The `/dog stay|follow|free` built-in does exactly this.
---@param id number the dog's entity id
---@param mode number `DOG_STAY`, `DOG_FOLLOW`, `DOG_FREE`, ... (0-7)
---@return boolean true when the mode was set
function SetDogMode(id, mode) end

---A dog's mode.
---@param id number the dog's entity id
---@return number the mode (`DOG_FOLLOW` for a dog nobody told otherwise); `false` when the id is not a dog
function GetDogMode(id) end

---Sets a dog's coat - its colour and markings - on every screen.
---
---`coat` is one of `GetDogCoats` (`"backyard_brown"`, `"alaunt_white"`, `"wardog_black"` ...; any case). It works on a
---player's dog (`CreateDog`) and on an animal made with `CreateAnimal``("dog")`. The dog changes at once on every screen
---that has it. A dog never given one wears a pick that changes with the dog's id (two dogs can share one) - so a mode that
---keeps dogs saves the coat (`GetDogCoat`) and gives it back right after making the dog; set in the same moment, it is on
---from the dog's first frame. `nil` or `""` goes back to the pick.
---@param id number the dog
---@param coat? string one of `GetDogCoats`; `nil` = the pick that goes with the dog's id again
---@return boolean `false` when it is not a dog or the coat is no coat
function SetDogCoat(id, coat) end

---The coat a dog wears.
---
---The coat `SetDogCoat` gave it, else the pick it shows now - either way the name to save, so the dog comes back the same.
---@param id number the dog
---@return string|nil one of `GetDogCoats`; `nil` when it is not a dog
function GetDogCoat(id) end

---The coats a dog can wear.
---@return table the coat names: the backyard dogs, the alaunts and the war dogs of the game
function GetDogCoats() end

-- ======== Voice chat ============================================================
-- Players talk to whoever stands near them: a voice plays from where its owner stands, through the game's own 3D sound,
-- fading with the distance. The server relays every voice frame the moment it arrives to the players within the range, and
-- the mode steers it: how far a voice carries (`SetVoiceRange`), one player's own reach (`SetPlayerVoiceRange` - a crier,
-- a whisperer), a mute nobody hears (`SetPlayerVoiceMuted`) and a deafening that hears nobody (`SetPlayerVoiceDeaf`);
-- `OnPlayerVoiceStart` and `OnPlayerVoiceStop` say who speaks.
-- 
-- **A player's own mutes** silence one talker for that player alone - everyone else still hears them. Players have the
-- server's `/mute <name|id>` and `/unmute <name|id>` and the scoreboard's mute button; `OnPlayerVoiceMute` hears (and may
-- refuse) each one, and a mode that handles `/mute` itself, or offers a menu, sets them with `SetPlayerVoiceMutedFor`.
-- `GetPlayerVoiceMutes` lists them to save; they last while both players are in the game. The server's defaults are the `[voice]` section of
-- server.toml; players pick their microphone, key and mode in the launcher.
-- 
-- **Voice levels** let the players choose how far they are heard: a whisper, the normal voice, a shout - as many as the mode
-- likes (`SetVoiceLevels`). A player switches with the voice level key (left Ctrl unless they changed it in the launcher's options; on horseback Ctrl stays the horse's brake),
-- the game's HUD shows the level they picked ("Voice: Whisper (3 m)"), and their voice carries as far as the level says.
-- `OnPlayerVoiceLevelChange` may refuse a switch, `SetPlayerVoiceLevel` puts a player at a level.

---**Called by the server** - A player started speaking.
---
---Their first voice frame of a burst reached the server. `IsPlayerTalking` answers `true` from here until
---`OnPlayerVoiceStop`. A muted player never triggers it (their frames are dropped before the relay). A quiet
---push-to-talk press that sends no sound (the codec drops silence) does not either.
---@param pid number who speaks
function OnPlayerVoiceStart(pid) end

---**Called by the server** - A player stopped speaking.
---
---300 ms passed without a voice frame from them, or they left the server.
---@param pid number who fell silent
function OnPlayerVoiceStop(pid) end

---**Called by the server** - A player pressed the voice level key and asks for the next level.
---
---`level` is the level they ask for, `previous` the one they speak at (both numbered from 1 in the `SetVoiceLevels`
---list). Return `false` to refuse: they stay where they are and nothing shows on their screen - tell them why if you want
---to. Nothing, `nil` or `true` lets the switch through. A player can switch at most five times a second; `SetPlayerVoiceLevel`
---does not come here.
---
---Return value: `false` refuses the switch
---@param pid number the player
---@param level number the level asked for, from 1
---@param previous number the level they speak at now, from 1
function OnPlayerVoiceLevelChange(pid, level, previous) end

---**Called by the server** - A player asks to stop hearing another player, or to hear them again.
---
---The server's `/mute` or `/unmute` (with a name or a player id) or the scoreboard's mute button. It is for `pid` alone:
---everyone else still hears `target`. Return `false` to refuse - nothing changes (the scoreboard's mark goes back) - and tell
---them why if you want to; nothing, `nil` or `true` lets it through. Save the change here to keep it across visits
---(`GetPlayerVoiceMutes`, then `SetPlayerVoiceMutedFor` at the next join). A mode that answers `/mute` itself in
---`OnPlayerCommandText` never comes here for it, and `SetPlayerVoiceMutedFor` does not either.
---
---Return value: `false` refuses it
---@param pid number the player who asks
---@param target number the player they want to stop hearing (or hear again)
---@param muted boolean `true` = stop hearing them, `false` = hear them again
function OnPlayerVoiceMute(pid, target, muted) end

---How far a voice carries by default, in metres.
---
---The server relays a voice to the players within this distance of the talker, and every client sets its 3D falloff
---from it: full level within the first metre, fading to silence at the range. `0` switches the voice chat off for
---everyone (a player with an own range through `SetPlayerVoiceRange` still carries). The change reaches every
---client at once. The start value is `[voice] range` in server.toml (25).
---@param metres number the range; 0 = off
function SetVoiceRange(metres) end

---The server's default voice range in metres.
function GetVoiceRange() end

---One player's own voice range in metres; 0 = the default again.
---
---A town crier heard across the square, a conspirator heard at arm's length. The range applies to that player's
---voice alone (how far others hear them, not how far they hear); every client is told. With voice levels
---(`SetVoiceLevels`) the player's next switch sets their range again.
---@param pid number the player
---@param metres number their range; 0 = the server's default
function SetPlayerVoiceRange(pid, metres) end

---A player's own voice range, 0 when they use the default.
---@param pid number the player
function GetPlayerVoiceRange(pid) end

---Nobody hears the player while muted.
---
---Their voice frames are dropped at the server: a moderation lever (a gag). For one listener alone - a player who does
---not want to hear another - use `SetPlayerVoiceMutedFor` (the server's `/mute`).
---@param pid number the player
---@param muted boolean `true` mutes, `false` lifts it
function SetPlayerVoiceMuted(pid, muted) end

---Whether the mode muted the player.
---@param pid number the player
function IsPlayerVoiceMuted(pid) end

---The player hears nobody while deaf.
---
---Nothing is relayed to them; they may still speak. A dead player in a round, a spectator, a penalty.
---@param pid number the player
---@param deaf boolean `true` deafens, `false` restores their hearing
function SetPlayerVoiceDeaf(pid, deaf) end

---Whether the mode deafened the player.
---@param pid number the player
function IsPlayerVoiceDeaf(pid) end

---One player no longer hears another - for that player alone.
---
---`listener` stops hearing `talker` (`false`: hears them again); everyone else still hears the talker. It is what the
---server's `/mute` does, for a mode that offers its own - a command of its own name, a button on a page, a mute by the id
---the mode shows instead of a name plate. The listener's scoreboard marks the talker muted, and they can lift it with
---`/unmute` or the scoreboard's button (which asks `OnPlayerVoiceMute`); this call does not ask it.
---
---It lasts while both are in the game: a mode that keeps mutes across visits saves them (`OnPlayerVoiceMute`,
---`GetPlayerVoiceMutes`) and sets them again when the player joins.
---@param listener number the player who stops hearing
---@param talker number the player they stop hearing
---@param muted? boolean `true` (the default) mutes, `false` lifts it
function SetPlayerVoiceMutedFor(listener, talker, muted) end

---Whether one player muted another for themselves.
---
---Their own `/mute`, the scoreboard's button or `SetPlayerVoiceMutedFor`.
---@param listener number the player who may have muted
---@param talker number the player they may not hear
function IsPlayerVoiceMutedFor(listener, talker) end

---The players one player muted for themselves.
---
---Their pids, lowest first - to save in `OnPlayerDisconnect` (they are still listed there) and set again with
---`SetPlayerVoiceMutedFor` at the next join. A player who left is no longer in anyone's list.
---@param listener number the player
function GetPlayerVoiceMutes(listener) end

---Whether the player's voice reached the server in the last 300 ms.
---
---What `OnPlayerVoiceStart` / `OnPlayerVoiceStop` bracket, as a question.
---@param pid number the player
function IsPlayerTalking(pid) end

---Whether the player keeps the voice chat on in their own settings.
---
---A preference, not a permission - `false` means they switched it off on their side (they neither talk nor hear).
---@param pid number the player
function IsPlayerVoiceEnabled(pid) end

---The voice levels players switch between with the voice level key - a whisper, a shout, as many as you like.
---
---`levels` is a list of `{name = "...", range = metres}` in the order the key goes through them (16 at most). A level
---without a range (or `0`) carries as far as the server's default (`SetVoiceRange`). `defaultLevel` - a number from 1 or
---a level's name - is where every player starts; without it, the first level that has no range of its own.
---
---A player picks the next level with the key (it goes round), the HUD shows it, and the level's range becomes their own
---(`SetPlayerVoiceRange`, which still sets it directly until their next switch). A new list keeps every player at their
---place in it when the new list has one; `{}` takes the levels away - the key does nothing and everyone's own range goes
---back to the default. Set it in `OnGameModeInit`; a reload of the mode clears it.
---@param levels table `{{name = "Whisper", range = 3}, ...}`; `{}` = no levels
---@param defaultLevel? number|string where everyone starts - a number from 1 or a level's name
function SetVoiceLevels(levels, defaultLevel) end

---The voice levels of SetVoiceLevels and the one players start at.
function GetVoiceLevels() end

---Puts a player at one of the voice levels.
---
---As if they picked it themselves - their range, their HUD's line - but without asking `OnPlayerVoiceLevelChange`. Use it
---to restore a saved choice in `OnPlayerConnect`, or to make a guard shout.
---@param pid number the player
---@param level number|string a number from 1 or a level's name
function SetPlayerVoiceLevel(pid, level) end

---How much walls muffle a voice.
---
---Every player's game measures what stands between them and each player they hear - walls, floors, a closed door, a hill -
---and muffles that voice the way the game muffles its own sounds behind them: stone and plaster a lot, wood less, leaves,
---cloth and open windows not at all. The voice still carries as far as its range; only how it sounds changes. `1` is the
---default, `0` turns it off, up to `2` muffles twice as much. The change reaches every player at once.
---@param strength number 0 = walls never muffle, 1 = the default, up to 2
function SetVoiceOcclusion(strength) end

---How much walls muffle a voice on this server.
function GetVoiceOcclusion() end

---How much a closed helmet visor muffles its wearer's voice.
---
---A player who speaks with their helmet's visor down sounds as if through it to everyone who hears them - duller and a
---little quieter. `1` is the default, `0` turns it off, anything between muffles less. It adds to what walls do
---(`SetVoiceOcclusion`), and the change reaches every player at once.
---@param amount number 0 = a visor never muffles, 1 = the default
function SetVoiceVisorMuffle(amount) end

---How much a closed helmet visor muffles a voice on this server.
function GetVoiceVisorMuffle() end

---The voice level a player speaks at.
---@param pid number the player
function GetPlayerVoiceLevel(pid) end

-- ======== NPC actors ============================================================
-- An **NPC actor** is a dressed, named human body the server owns outright - a guard, a merchant, an arena opponent, a crowd -
-- without the game's own AI. The mode creates it, walks it, poses it and sets it on a player; it takes hits,
-- dies and fights back. Its `id` is a world entity of `ENTITY_NPC`: `GetEntityPos`, `GetEntityName`, `SetEntityState` and
-- `DestroyEntity` work on it. Its look is a soul of the souls, its clothes and arms are
-- clothing and weapon presets, its poses are clips of
-- the animation list. It fights like a player: an armed actor raises its guard against a swing part
-- of the time (`[actors] block_chance`, `block_hold`), a heavy blow wounds the part it hits, a cut bleeds, a bleed-out kills it.
-- With the level's navigation mesh it walks around walls and opens the doors in its way (`[actors] open_doors`). Several
-- actors on one player all swing at once by default; `[actors] max_attackers` makes them take turns - at most that many swing
-- at one player within a `swing_interval`, the rest wait at arm's length, the longest waiting first. Actors fight each other
-- too (`SetActorHostileToActor`), and a mode can relabel and color the name over one (`SetActorNameplate`,
-- `SetActorColor`). `[actors]` in `server.toml` tunes how it fights. How hard it hits and what it wears are the mode's too:
-- its stats and skills (`SetActorStat`, `SetActorSkill`) and its items one by one (`SetActorInventory` - its armour counts,
-- its weapon prices its blows). An actor also rides a horse, speaks the game's own lines and sits on the level's benches or works
-- at its work spots (`MountActor`, `PlayActorBark`, `SetActorUse` - the next section).
-- 
-- **Animals** (`CreateAnimal`, `ENTITY_ANIMAL`) are the game's own wildlife and farm animals, owned by the server the same way
-- an actor is. The kinds are wolves, wild dogs, dogs (a stray the server walks; a player's own dog is `CreateDog`'s), boars, pigs,
-- red deer stags and does, roe deer bucks and hinds, hares, sheep (ewes and rams), cattle (cows and bulls), hens and ravens.
-- 
-- - **Moving and keeping them:** `MoveActor`, `StopActor`, `TurnActor`, the health functions, `HealActor`,
--   `SetActorInvulnerable` and `DestroyEntity` work on them as on an actor.
-- - **Hunting them:** a player's blow or arrow hurts one (`OnActorDamage` may change or cancel the damage), a cut bleeds, and it
--   dies when its health reaches 0 or it bleeds out. An animal never blocks, poses, trades or takes a look, wears no label or
--   torch, is not knocked out, robbed or carried (`SetActorNameplate`, `SetActorTorch`, `SetActorKnockedOut`,
--   `SetActorPocket` and the like answer `false`). It bleeds but is never injured: `OnActorInjury` never runs for an animal and
--   `GetActorInjuries` stays empty.
-- - **Animals that attack and flee:** left alone an animal does nothing by itself. `SetAnimalHostile` sets one on a player - it
--   runs after them and bites within its reach (a wolf's or a dog's attack on every screen; the bite goes through their armour and
--   `OnActorAttack`); `SetAnimalFlee` runs it from a player. `SetAnimalBehavior` gives it a temper that acts by itself:
--   `"aggressive"` hunts a player who comes close, `"defensive"` turns on whoever hurts it, `"skittish"` runs from a player who comes
--   close and from whoever hurts it. `SetAnimalAttack` tunes the bite, `GetAnimalState` says what it is doing.
-- - **What a kill is worth:** a dead animal gives nothing by itself. `OnActorDeath` runs for it with the player who killed it
--   (`-1` when its health was set to 0 or the last blow was no player's) - hand out the meat or the pelt there, or put it on the
--   body for a search (`SetActorLoot`), and `DestroyEntity` the carcass when you are done with it, since it lies there until you do.

---**Called by the server** - An actor (or a horse) reached its MoveActor target.
---
---It stands there until the next `MoveActor`. Chain the legs of a route here. A walk that meets a locked door ends at the
---door and lands here too - compare `GetEntityPos` with the target when it matters. A horse nobody rides that `MoveActor`
---walked lands here with its own id (a mounted actor's horse: the actor's).
---@param id number the actor, or the horse
function OnActorArrive(id) end

---**Called by the server** - A player hit an actor - change the damage, cancel it, or let it through.
---
---The same shape and the same return rules as `OnPlayerDamage`: a number replaces the damage (`0` cancels), `false`
---cancels, nothing keeps it. The hit went through the same model as a hit on a player, through the armour the actor wears of the
---items `SetActorInventory` gave it (an actor dressed by its presets has no armour that counts).
---
---Return value: a number replaces the damage (`0` cancels); `false` cancels the hit; nothing keeps it. A second value `true` / `false` decides the bleeding
---@param id number the actor
---@param attacker number the player who struck
---@param damage number what the actor is about to lose
---@param zone number the attack zone the attacker's game recorded
---@param part number the body part struck, `1` .. `6`; `0` unknown
---@param weapon string the weapon's table name; `""` bare-handed
---@param dtype string `"stab"`, `"slash"`, `"smash"` or `""`
---@param bleeds boolean whether the blow opens a bleeding wound by the server's rules (`SetBleedRules`)
---@param armour number the share of the blow the actor's armour on that part took, `0` .. `0.85`
function OnActorDamage(id, attacker, damage, zone, part, weapon, dtype, bleeds, armour) end

---**Called by the server** - A hit wounded one of an actor's body parts.
---
---The shape of `OnPlayerInjury`: a blow of at least `[combat] injury_threshold` injures the part it struck; every client
---shows the limp. A cut through the armour's gate bleeds (`SetBleedRules`, `GetActorBleeding`) and drains the health - a
---bleed-out is the last attacker's kill. `HealActor` makes the actor whole.
---@param id number the actor
---@param attacker number the player who struck; `-1` = nobody
---@param part number the body part, `1` .. `6`
function OnActorInjury(id, attacker, part) end

---**Called by the server** - An actor's health reached 0.
---
---`attacker` is the player who killed it - by a blow or by the bleed they opened - or `-1` for `SetActorHealth(id, 0)` and
---for another actor's blow (`OnActorAttackActor` saw it). The corpse stays until `DestroyEntity` - an actor has no
---respawn of its own; a mode creates a new one.
---@param id number the actor
---@param attacker number the killer; `-1` = nobody
function OnActorDeath(id, attacker) end

---**Called by the server** - An actor's blow landed on its opponent - change the damage, cancel it, or let it through.
---
---The same shape and return rules as `OnPlayerDamage`. The blow is priced by the victim's own game - the actor's weapon
---through their armour - times `[actors] attack_scale`, at most `[actors] max_damage`. A mode **without** this callback hears
---the blow as `OnPlayerDamage(pid, -1, ...)`. An animal's bite (`SetAnimalHostile`) comes here too: `id` is the animal, the
---damage is its bite's (`SetAnimalAttack`) through the player's armour, `weapon` is `"a bite"`.
---
---Return value: a number replaces the damage (`0` cancels); `false` cancels the blow; nothing keeps it. A second value `true` / `false` decides the bleeding
---@param id number the actor
---@param pid number the player struck
---@param damage number what the player is about to lose
---@param zone number the attack zone
---@param part number the body part struck, `1` .. `6`; `0` unknown
---@param weapon string the actor's weapon by its table name; `""` bare-handed
---@param dtype string `"stab"`, `"slash"`, `"smash"` or `""`
---@param bleeds boolean whether the blow opens a bleeding wound by the server's rules (`SetBleedRules`)
---@param armour number the share of the blow the player's armour on that part took, `0` .. `0.85`
function OnActorAttack(id, pid, damage, zone, part, weapon, dtype, bleeds, armour) end

---**Called by the server** - An actor's blow landed on another actor - change the damage, cancel it, or let it through.
---
---Fires for an actor set on another with `SetActorHostileToActor` (or one fighting back). The server decides these
---blows itself: the attacker's weapon - or its fists - against the body part struck, times `[actors] attack_scale`, at
---most `[actors] max_damage`. A blow the target blocked, or one on an invulnerable actor, never
---comes here. The return rules are `OnActorAttack`'s.
---
---Return value: a number replaces the damage (`0` cancels); `false` cancels the blow; nothing keeps it. A second value `true` / `false` decides the bleeding
---@param id number the attacking actor
---@param target number the actor struck
---@param damage number what the target is about to lose
---@param zone number the attack zone
---@param part number the body part struck, `1` .. `6`
---@param weapon string the attacker's weapon by its table name; `"fists"` bare-handed
---@param dtype string `"stab"`, `"slash"`, `"smash"` or `""`
---@param bleeds boolean whether the blow opens a bleeding wound by the server's rules (`SetBleedRules`)
---@param armour number the share of the blow the target's armour on that part took, `0` .. `0.85`
function OnActorAttackActor(id, target, damage, zone, part, weapon, dtype, bleeds, armour) end

---**Called by the server** - An actor's swing met a player's block.
---
---The player's game blocked the actor's swing - with `perfect` `true` a perfect block or a master strike. Once per swing; a
---blow that landed comes to `OnActorAttack` instead, a dodge or a miss to neither. The actor's stagger follows this call
---(`SetActorBlockRules`: by default a perfect block costs the actor its next swing for 1.5 seconds and a plain block nothing);
---a mode that keeps its own stamina for its fighters spends it here, and may stagger the actor itself with `StaggerActor`.
---@param id number the actor
---@param pid number the player who blocked
---@param perfect boolean `true` for a perfect block or a master strike
function OnActorBlocked(id, pid, perfect) end

---**Called by the server** - A player's swing met an actor's raised guard.
---
---An armed actor raises its guard against a swing part of the time (`[actors] block_chance`); this fires when the player's blow
---met it and did no harm. Once per swing. A blow that glanced off without a guard comes to neither this nor `OnActorDamage`.
---@param pid number the player who swung
---@param id number the actor
function OnPlayerBlockedByActor(pid, id) end

---**Called by the server** - The player pressed the use key on an actor that has a prompt - return `false` to stop its shop opening.
---
---Fires for an actor with a prompt (a shop gives it "Trade") when a player within
---3.5 m, facing it, presses the use key. An actor with a shop then opens it on the player unless the callback returns
---`false`; an actor with a prompt of the mode's own does nothing but call this - a talk, a quest, a guard's challenge
---are the mode's to write here.
---
---Return value: `false` stops the actor's shop from opening; anything else lets it
---@param pid number the player
---@param id number the actor
function OnPlayerInteractActor(pid, id) end

---**Called by the server** - A player wants to search a dead actor's or animal's body - return `false` to refuse.
---
---Fires for a body that holds what the mode put on it (`SetActorLoot`) when a player within reach uses the game's loot
---prompt on it. Nothing has opened yet. Return `false` and nothing opens, **without a word**; return a text after the `false`
---and their chat shows it (`return false, "The hunter's mark is on it."`). Otherwise the game's own search screen opens on the
---body's list, and what they take is theirs (the list loses it). One player searches a body at a time.
---
---Return value: `false` refuses saying nothing, `false, "text"` refuses and tells the player that text; anything else lets them search
---@param pid number the player
---@param id number the dead actor or animal
function OnPlayerLootActor(pid, id) end

---**Called by the server** - A player wants to butcher a dead animal - return `false` to refuse.
---
---Fires when a player within reach holds the game's "Butcher" on a carcass you made butcherable (`SetActorButcher`).
---Nothing has happened yet. Return `false` and nothing happens, **without a word**; return a text after the `false` and their
---chat shows it. Otherwise their game butchers it - the animation, then the game's own meat to take from the carcass - and the
---others see them at it.
---
---Return value: `false` refuses saying nothing, `false, "text"` refuses and tells the player that text; anything else lets them
---@param pid number the player
---@param id number the carcass
function OnPlayerButcher(pid, id) end

---Creates an NPC actor - a dressed, named body the server owns.
---
---`soul` is the face and build: a soul of any archetype from the souls by name, id or GUID (`nil` = the
---server's appearance pool for the name, like a player without a `SetSpawnInfo` face). `name` is the label over its head (`nil`
---= none). `clothing` and `weapons` are preset GUIDs (clothing,
---weapons; `nil` = the server's `[spawn]` presets, like a player - or, where those leave players
---naked and unarmed, a peasant's clothes with a sword and a shield; `clothing = "none"` leaves it naked, `weapons = "none"`
---makes an unarmed one that fights with its fists). `world` is the virtual world (`nil` = the shared one). The actor stands where it is
---put until `MoveActor`; its health is 100. `nil` when the soul is unknown or the world is full.
---@param soul string|number|nil a soul's name, id or GUID; `nil` = the server's pool
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw number degrees (`0` without)
---@param name? string the label over its head; `nil` = none
---@param clothing? string a clothing preset GUID; `nil` = the server default
---@param weapons? string a weapon preset GUID; `nil` = the server default; `"none"` = unarmed
---@param world? number the virtual world; `nil` = the shared one
---@return number the actor's entity id; `nil` when it could not be made
function CreateActor(soul, x, y, z, yaw, name, clothing, weapons, world) end

---Creates an animal - the game's wolf, boar, deer, hare ... that the server walks like an actor.
---
---`animal` is the kind - `"wolf"`, `"wild dog"`, `"dog"`, `"boar"`, `"pig"`, `"red deer stag"`, `"red deer doe"`,
---`"roe deer buck"`, `"roe deer hind"`, `"hare"`, `"sheep ewe"`, `"sheep ram"`, `"cattle cow"`, `"cattle bull"`, `"hen"`,
---`"raven"` (case and spaces do not matter; `"deer"`, `"stag"`, `"doe"`, `"buck"`, `"hind"`, `"sheep"`, `"ram"`, `"cow"`,
---`"bull"` and `"chicken"` work too) - or one of its souls from the souls by name, id or GUID, for a
---particular look (a soul of another archetype is refused). `name` is the mode's name for it (`GetEntityName`, the server
---log; no label shows over an animal). `world` is the virtual world (`nil` = the shared one). It stands where it is put until
---`MoveActor` - about 1.5 walks, 4 trots, 6.5 or more runs - and its health is 100 (`SetActorHealth` makes a hare
---easier to kill). It does nothing by itself until the mode gives it a behaviour (`SetAnimalBehavior`) or sets it on a player
---(`SetAnimalHostile`), and its body gives what the mode puts on it (`SetActorLoot`: the meat, the pelt -
---players search it the game's own way) or what the mode hands out in `OnActorDeath`. `nil` for an unknown kind, a soul that is no animal's, a full world, or a soul named instead of a kind
---(by name, id or GUID) when the server has no tables export of the game loaded (the kinds still work then).
---@param animal string|number the kind (`"wolf"`, `"red deer stag"` ...) or an animal's soul by name, id or GUID
---@param x number metres
---@param y number metres
---@param z number metres (below 0 = on the ground)
---@param yaw number degrees (`0` without)
---@param name? string the mode's name for it; `nil` = none
---@param world? number the virtual world; `nil` = the shared one
---@return number the animal's entity id; `nil` when it could not be made (an unknown kind, a soul that is no animal's or cannot be told apart without the tables export, a full world)
function CreateAnimal(animal, x, y, z, yaw, name, world) end

---Sets an animal on a player - it runs after them and bites.
---
---The animal runs after the player at its kind's pace (a wolf ~6.5 m/s, a boar 5) and, at their feet, bites standing every
---second and a half or so: on every screen a wolf or a dog plays its attack, a boar gores. It stays close between bites, within
---reach of a sword, and after every third backs off a little - a dog hops back, a boar runs out and charges in again. The bite
---lands on a player still within reach when it arrives - its kind's damage (a wolf 12, a boar 18, a dog 7 ...;
---`SetAnimalAttack` changes it) through their armour, and half that from their stamina; `OnActorAttack` may change or
---cancel it. A wolf's or a boar's bite bleeds. The hunt ends when the player dies, leaves, goes to another world or gets far away (2.5 times the
---animal's behaviour radius, 30 m at least), when the animal dies, with a `MoveActor` or `StopActor`
---of yours, or with `SetAnimalHostile(id, nil)`.
---@param id number the animal
---@param pid number|nil the player to hunt; `nil` calls a hunt off
---@return boolean `false` for anything but a live animal, or a player who is dead, not in the world or in another one
function SetAnimalHostile(id, pid) end

---Runs an animal from a player.
---
---The animal runs straight away from the player at its kind's flight pace (deer and hares ~9 m/s, a boar 5.5, sheep and cattle
---4.5-5) until it is `distance` metres from them, then stands. A `MoveActor` or `StopActor` of yours ends it, and so does
---`SetAnimalFlee(id, nil)`.
---@param id number the animal
---@param pid number|nil the player to run from; `nil` stops the flight
---@param distance? number metres from the player where it stops (`30`; 3 to 200)
---@return boolean `false` for anything but a live animal, or a player not in its world
function SetAnimalFlee(id, pid, distance) end

---What an animal does by itself - calm, aggressive, defensive or skittish.
---
---- `"calm"` (every animal's to start with): nothing by itself - it walks where you send it, even when hurt.
---- `"aggressive"`: hunts the nearest player who comes within `radius` metres (`SetAnimalHostile`), and whoever hurts it.
---- `"defensive"`: turns on whoever hurts it.
---- `"skittish"`: runs from the nearest player who comes within `radius` metres (`SetAnimalFlee`, to twice the radius and 30 m
---  at least), and from whoever hurts it.
---
---The behaviour stays through hunts and flights: an aggressive wolf that lost its prey goes for the next player who comes near.
---@param id number the animal
---@param behavior string `"calm"`, `"aggressive"`, `"defensive"` or `"skittish"`
---@param radius? number metres the aggressive and the skittish keep watch over (`15`; 1 to 100)
---@return boolean `false` for anything but an animal, or an unknown word
function SetAnimalBehavior(id, behavior, radius) end

---An animal's behaviour.
---@param id number the animal
---@return string `"calm"`, `"aggressive"`, `"defensive"` or `"skittish"`; `""` for anything but an animal
function GetAnimalBehavior(id) end

---An animal's bite - its damage and how often it bites.
---
---`damage` is what a bite takes from a player without armour (armour lowers it, `OnActorAttack` has the last word); `interval`
---the seconds between bites (0.5 at least). `0` gives back the kind's own: a wolf 12 every 1.6 s, a wild dog 9, a dog 7, a boar 18
---every 2.4 s, a red deer stag 14, a bull 20, a hare 2.
---@param id number the animal
---@param damage number health a bite takes (`0` = the kind's own; at most 100)
---@param interval? number seconds between bites (`0` = the kind's own)
---@return boolean `false` for anything but an animal, or a negative number
function SetAnimalAttack(id, damage, interval) end

---What an animal is doing - hunting, fleeing or calm - and who it is about.
---@param id number the animal
function GetAnimalState(id) end

---Walks an actor to a point - around the walls when the server has the navigation mesh.
---
---At `speed` metres per second, facing its way - about 1.5 walks, 4 runs, 6.5 sprints (the body's clips follow the speed).
---`OnActorArrive` fires when it gets there. A new target replaces the old one; a pose (`SetActorAnim`) is cleared. With
---the level's navigation mesh (`HasNavmesh`, the navigation guide) the actor takes the walk the game's own
---people would - corner by corner, around walls and through doorways; a target off the mesh (in a wall, on a roof) or a
---server without the mesh gets the straight line, where the body stops at a wall and catches up when the line comes out.
---A closed door in its way opens for everyone as the actor gets there; a locked one (`SetDoorState`) ends the walk at the
---door, with `OnActorArrive` (`[actors] open_doors`).
---
---**A horse nobody rides walks too** - a server horse (`CreateHorse`) or a player's own (`SetHorseOwner`): the speed picks
---its gait (about 1.5 a walk, 3.5 a trot, 6.5 a canter, 9.5 a gallop) and `OnActorArrive` gets the horse's id at the end - a
---player's call for their horse, a herd moved, a pack horse led. A player who mounts it on the way ends the walk; a horse a
---player rides is refused. `StopActor` and `TurnActor` take a horse as well.
---@param id number the actor
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground there (the server's world data, else the height the actor walks at)
---@param speed? number metres per second (`1.5`)
---@return boolean `false` for anything but a living actor that is not knocked out (`SetActorKnockedOut`) or grabbing a body (`ActorCarryEntity`), or a living horse no player rides
function MoveActor(id, x, y, z, speed) end

---Stops an actor where it is.
---
---No `OnActorArrive`. Also ends a chase started by `SetActorHostile` only as far as the walk goes - the fight of record stays
---until its timeout.
---@param id number the actor
---@return boolean `false` for anything but an actor or a horse no player rides
function StopActor(id) end

---Turns a standing actor to face a direction.
---@param id number the actor
---@param yaw number degrees; `0` = facing +Y, counter-clockwise
---@return boolean `false` for anything but a standing actor or a standing horse no player rides
function TurnActor(id, yaw) end

---Whether an actor is on its way to a MoveActor target.
---@param id number the actor
---@return boolean `false` once arrived or stopped
function IsActorMoving(id) end

---Puts a pose on a standing actor - a clip of the game's animation set.
---
---`clip` is a clip name of the male animation set (`behavior_sitting_variation01_loop`,
---`greetings_wave_big_over`, `woodchopping_loop_01` ...) or one of the aliases the API names: `sit`, `wave`, `bow`, `nod`,
---`pray`, `chop`, `sweep`, `smith` (`ACTOR_ANIM` in Constants). `loop` `true` (the default) plays it
---until cleared; `false` plays it once. `nil` clears the pose; so do `MoveActor` and a death. The pose rides in the actor's
---state bag (key `anim`), so a player who arrives later finds the guard sitting. A chore without its prop mimes - a smith
---without an anvil.
---@param id number the actor
---@param clip string|nil a clip name or an alias; `nil` clears the pose
---@param loop? boolean `true` (the default) loops; `false` plays once
---@return boolean `false` for anything but a living actor
function SetActorAnim(id, clip, loop) end

---An actor's health.
---@param id number the actor
---@return number `0` .. `100`; `0` for anything but an actor
function GetActorHealth(id) end

---Sets an actor's health; 0 kills it.
---
---Clamped to `0` .. `100`; `0` kills it now (`OnActorDeath` with attacker `-1`). Refused on a dead actor - a corpse stays a
---corpse; `DestroyEntity` and `CreateActor` again.
---@param id number the actor
---@param health number the new health
---@return boolean `false` for a dead actor or anything but an actor
function SetActorHealth(id, health) end

---Whether an actor is a corpse.
---@param id number the actor
---@return boolean
function IsActorDead(id) end

---Makes an actor whole - full health, no wounds, no bleeding.
---
---Every client shows the body straighten. Refused on a corpse.
---@param id number the actor
---@return boolean `false` for a dead actor or anything but an actor
function HealActor(id) end

---An actor's wounded body parts.
---
---A list of body parts, `BODY_PART_HEAD` .. `BODY_PART_LEG_RIGHT` (`1` .. `6`); `{}` when whole. A blow of at least
---`[combat] injury_threshold` wounds the part it struck (`OnActorInjury`).
---@param id number the actor
---@return table a list of body part ids
function GetActorInjuries(id) end

---Whether an actor has a wound - anywhere, or on one part.
---@param id number the actor
---@param part? number a body part `1` .. `6`; without it, any part
---@return boolean
function IsActorInjured(id, part) end

---How fast an actor is bleeding, in health per second.
---
---A cut opens a wound by the players' rules (`SetBleedRules`): each bleeds on its own for the rules' seconds and they add
---up; `0` = not bleeding. A bleed-out is the last attacker's kill (`OnActorDeath`); `HealActor` stops it.
---@param id number the actor
---@return number health lost per second; `0` = not bleeding
function GetActorBleeding(id) end

---Sets how fast an actor bleeds, in place of its open wounds.
---
---`SetPlayerBleeding` for an actor or an animal: one wound of `rate` health a second for `seconds` (left out = the rules'
---seconds, `SetBleedRules`), capped by the rules' `maxRate`; `0` stops the bleeding. A bleed-out is the last player's kill
---who struck it. Refused on a corpse.
---@param id number the actor
---@param rate number health lost per second; `0` stops the bleeding
---@param seconds? number how long it bleeds; left out = the rules' seconds
---@return boolean `false` for a dead actor or anything but an actor
function SetActorBleeding(id, rate, seconds) end

---Whether an actor is bleeding.
---@param id number the actor
---@return boolean
function IsActorBleeding(id) end

---Sets an actor on a player - or stands it down.
---
---`true` makes the player the actor's opponent: their game may lock on to the actor's body, and the actor faces them, walks
---after them (`[actors] chase_speed`, up to `chase_range`; around walls with the navigation mesh, and a locked door holds it
---back) and swings every `[actors] swing_interval` seconds within
---`[actors] reach`, with the weapon of its preset or its fists; a blow that lands comes to the mode as `OnActorAttack`. With
---`[actors] max_attackers` set, the actors on one player take turns: while that many of them swung at the player within the
---last `swing_interval`, the others wait at their reach (still in the fight) until a turn frees. A
---player's blow on the actor does the same by itself when `[actors] fight_back` is on. `false` stands it down - so do the
---opponent's death or leaving, another world, `chase_range`, `MoveActor` and the actor's own death.
---@param pid number the player
---@param id number the actor
---@param hostile boolean `true` = the actor fights the player; `false` = peace
---@return boolean `false` for anything but a living actor or a player not in the world
function SetActorHostile(pid, id, hostile) end

---Sets an actor on another actor - or stands it down.
---
---`true` makes `target` the actor's opponent: it faces it, walks after it and swings like at a player (`SetActorHostile`),
---and every screen shows the two fight. The server decides each blow itself: out of reach it misses, a raised guard
---blocks it (`[actors] block_chance`), otherwise it is the attacker's weapon - or its fists - against the body part
---struck, times `[actors] attack_scale`, at most `[actors] max_damage`, through `OnActorAttackActor`. With `[actors]
---fight_back` the target turns on its attacker at the first blow unless it fights someone already; without it, set both.
---An actor fights one opponent at a time: this replaces a player it was on, and `SetActorHostile` replaces this.
---`false` stands it down if it is on `target` - so do either's death or removal, another world, `chase_range` and
---`MoveActor`.
---@param id number the actor
---@param target number the actor to fight
---@param hostile boolean `true` = the actor fights `target`; `false` = peace
---@return boolean `false` unless both are living actors in one world (and not the same one)
function SetActorHostileToActor(id, target, hostile) end

---The actor an actor is fighting.
---@param id number the actor
---@return number|nil the other actor's id; `nil` when it fights none (or fights a player)
function GetActorTarget(id) end

---Staggers an actor - it reels and loses its next swing.
---
---For `seconds` (`0.2` .. `5`) the actor swings no more, lowers its guard and cannot raise one - the opening a perfect block
---gives in the game - and its body reels with the game's own hit reaction on every screen. A stagger while one lasts lengthens
---it. `false` for a dead, knocked-out or carried actor, an animal or anything else.
---@param id number the actor
---@param seconds number how long, `0.2` .. `5`
---@return boolean
function StaggerActor(id, seconds) end

---Sets what a player's block costs an actor.
---
---`rules` is a table: `perfectStagger` - seconds an actor staggers after a player's perfect block (or master strike) of its
---swing, `1.5` by default; `blockStagger` - after a plain block, `0` (none) by default. `0` .. `5` each; a key left out keeps
---the server's own, `nil` puts both back. A staggered actor loses its next swing and its guard (`StaggerActor`).
---@param rules table `{perfectStagger = seconds, blockStagger = seconds}`; `nil` = the server's own
function SetActorBlockRules(rules) end

---The actor block rules in force.
---@return table `{perfectStagger = seconds, blockStagger = seconds}`, every key set
function GetActorBlockRules() end

---Makes an actor one no blow hurts - or hittable again.
---
---A hit on an invulnerable actor is refused before anything happens: no damage, no wound, no fight of record, no
---`OnActorDamage`; it never turns on the attacker. The body still shows the swing land. For a vendor, a quest giver,
---a guard nobody may kill.
---@param id number the actor
---@param invulnerable? boolean `true` (the default) = no blow hurts it; `false` = it takes hits
---@return boolean `false` for anything but an actor
function SetActorInvulnerable(id, invulnerable) end

---Whether an actor takes no hits.
---@param id number the actor
---@return boolean
function IsActorInvulnerable(id) end

---Makes an actor or an animal invisible to every player, or seen again.
---
---Its body leaves every screen as if it had walked out of range, with the horse it rides. It is not heard, a player cannot hit
---it, use it, carry it or rob it, and a carry or a pickpocketing it is part of ends; a hostile animal leaves the players it is
---invisible to alone. Nothing else changes: it keeps walking where `MoveActor` sends it, and your other orders still apply -
---when it shows again it is wherever it is then, dressed as it is then.
---
---For a ghost, a spy only some players see, an actor waiting off stage for its cue. `SetActorInvisibleFor` gives one player
---their own rule. A reload of the mode shows every actor again.
---@param id number the actor or animal
---@param invisible? boolean `true` (the default) hides it, `false` shows it again
---@return boolean `false` for anything but an actor or an animal
function SetActorInvisible(id, invisible) end

---Whether an actor or an animal is invisible to players.
---@param id number the actor or animal
---@return boolean `true` while `SetActorInvisible` hides it. One player's own rule may differ: `IsActorVisibleTo`
function IsActorInvisible(id) end

---Hides an actor from one player, or shows it to one player while it is invisible to the rest.
---
---One player's own rule for the actor, which wins over `SetActorInvisible` both ways: `false` lets this player see an
---invisible actor, `true` hides a visible actor from this player alone, `nil` drops the rule. What a hidden actor hides is the
---same as `SetActorInvisible`'s. The rule is forgotten when the player leaves, and by a reload of the mode.
---@param id number the actor or animal
---@param viewer number the player whose screen the rule is for
---@param invisible boolean|nil `true` hides the actor from `viewer`, `false` shows it, `nil` follows `SetActorInvisible` again
---@return boolean `false` for anything but an actor or an animal, or when the viewer is not connected
function SetActorInvisibleFor(id, viewer, invisible) end

---Whether a player sees an actor or an animal.
---@param id number the actor or animal
---@param viewer number the player looking
---@return boolean the player's own rule (`SetActorInvisibleFor`) when there is one, else `not IsActorInvisible(id)`; `false` when either does not exist
function IsActorVisibleTo(id, viewer) end

---Puts a lit torch in an actor's free hand - or puts it out.
---
---The game's own burning torch, fire and light, in the actor's free hand on every screen: at peace or in a fight, standing or
---walking. An actor draws no weapon outside a fight, so this is how a mode lights its guards and townsfolk at night. A death
---puts the torch out; an actor coming into view later shows it lit.
---@param id number the actor
---@param lit? boolean `true` (the default) = the torch lit in the hand; `false` = put away
---@return boolean `false` for anything but a person actor (an animal too), or for a dead one when `lit` is `true` (a corpse holds no torch; putting one out always works)
function SetActorTorch(id, lit) end

---Lets an actor with a bow or a crossbow shoot in its fights - or keeps it to its melee weapon.
---
---An actor whose gear holds a bow (or a crossbow) and its arrows (or bolts) - its weapon preset, or the items you gave it
---(`SetActorInventory`) - fights with it by default: within `range` of its opponent and with a clear line it stands, draws,
---aims and shoots; out of range or out of sight it walks closer with the bow out; up close it changes to its melee weapon when
---it has one, and back to the bow when the opponent is far again. Every player sees the draw, the release and the arrow's
---flight. The server decides each arrow: where it flies (the opponent's movement led, off by a spread from `accuracy` - a miss
---is seen to miss) and what it costs - the bow's power and the arrow's attack against the armour on the part it struck, like a
---player's arrow, through `OnActorAttack` (an actor struck: `OnActorAttackActor`). It never shoots from the saddle.
---@param id number the actor
---@param enabled? boolean `true` (the default) = it shoots; `false` = its melee weapon only (a fight under way changes to it)
---@param range? number metres it shoots within (`30`; 5-80)
---@param accuracy? number 0-1, how close its arrows fly to where it aims (`0.7`: about half of them on a walking target at 20 m; `1`: nearly all)
---@return boolean `false` for anything but a person actor
function SetActorRanged(id, enabled, range, accuracy) end

---Whether an actor holds a lit torch.
---@param id number the actor
---@return boolean `false` for an actor with no lit torch, for a dead one (a death puts the torch out) and for anything that is no person actor, an animal included
function IsActorTorchLit(id) end

---Sets one of an actor's stats - strength, agility, vitality, speech.
---
---The level goes on the actor's body on every screen, so the game's own rules answer by it. Above all, the blows the actor
---lands on a player hurt more with more strength (the game weighs it against the weapon's requirement) and a higher combat
---level; a bow is held drawn by its strength. Set the levels right after `CreateActor` - a boss with strength 25 and its
---weapon skill at 20 hits much harder than a recruit at 5. A person actor takes `"strength"`, `"agility"`, `"vitality"` and
---`"speech"`; an animal takes `"strength"`, `"agility"`, `"vitality"` and `"courage"`. A level set stays until the actor is
---destroyed.
---@param id number the actor or animal
---@param stat string the stat's name
---@param level number 0 to 30
---@return boolean `false` for anything but an actor, a stat it does not take, or a level outside 0-30
function SetActorStat(id, stat, level) end

---The level SetActorStat gave one of an actor's stats.
---@param id number the actor or animal
---@param stat string the stat's name
---@return number|nil the level; `nil` when the mode never set it (the body's own soul decides)
function GetActorStat(id, stat) end

---Sets one of an actor's skills - a weapon skill, defense, warfare.
---
---Like `SetActorStat` for the skills: the level goes on the actor's body on every screen and the game's own rules answer
---by it, its blows on a player first of all. The names are the ones `SetPlayerSkill` takes: `"weapon_sword"` (or
---`"sword"`), `"heavy_weapons"`, `"weapon_large"` (polearms), `"weapon_dagger"`, `"weapon_unarmed"`, `"marksmanship"`,
---`"defense"`, `"fencing"` (or `"warfare"`) and the rest. Person actors only.
---@param id number the actor
---@param skill string the skill's name
---@param level number 0 to 30
---@return boolean `false` for an animal or anything but an actor, an unknown skill, or a level outside 0-30
function SetActorSkill(id, skill, level) end

---The level SetActorSkill gave one of an actor's skills.
---@param id number the actor
---@param skill string the skill's name
---@return number|nil the level; `nil` when the mode never set it
function GetActorSkill(id, skill) end

---Gives an actor exactly these items - what it wears dresses and arms it.
---
---The same list `SetPlayerInventory` takes: `{class = <item>, amount = <n>, worn = true}`, a class by its name, id or GUID
---(at most 64 entries). The items with `worn` dress and arm the actor's body on every screen, in place of the clothing and
---weapon presets it was created with. They are also what the server counts: the armour it wears softens the blows and arrows
---that hit it, its strongest worn weapon is the one its blows are priced by, and that weapon and its first shield are what it
---drops when it dies. The rest it only carries - `GetActorInventory` lists it, for loot. An actor never given items keeps
---its presets' dress and weapon, and no armour counts for it. An empty list leaves it naked and unarmed (it punches).
---@param id number the actor
---@param items table a list of `{class =, amount =, health =, worn =}`; `amount` 1 and `health` 100 by default
---@return boolean `false` for an animal or anything but a living server actor
function SetActorInventory(id, items) end

---Gives an actor one item more - worn unless told otherwise.
---
---Adds to the list `SetActorInventory` keeps. The first item given replaces the presets' dress, as a whole list would.
---@param id number the actor
---@param item string the item class (a name, id or GUID)
---@param amount? number how many (1 by default)
---@param wear? boolean `true` (the default) = worn; `false` = only carried
---@return boolean `false` for an unknown item, a full list (64) or anything but a living person actor
function GiveActorItem(id, item, amount, wear) end

---Takes items from an actor - what it carries first, then what it wears.
---@param id number the actor
---@param item string the item class (a name, id or GUID)
---@param amount? number how many (1 by default)
---@return boolean `false` when the actor has none of it (or was never given items)
function RemoveActorItem(id, item, amount) end

---An actor's items, as SetActorInventory and GiveActorItem left them.
---
---The weapon and the shield an actor drops at its death leave the list (they lie on the ground as pickups); the rest stays,
---for a mode that hands out loot from the corpse.
---@param id number the actor
---@return table|nil a list of `{class =, amount =, health =, worn =}`; `nil` when the actor was never given items (its presets dress it)
function GetActorInventory(id) end

---What a dead actor's or animal's body gives the players who search it.
---
---The list a search takes from: `{class = <item>, amount = <n>, health = <0-100>}`, a class by its name, id or GUID, money as the
---item `money` in tenths of a Groschen (`{class = "money", amount = 150}` is 15 Groschen), at most 64 entries. Set it whenever
---you like - at the creation, in `OnActorDeath`, later: while the body lies dead with anything on it, every player sees the
---game's own loot prompt on it and searches it the game's way, an animal's body too. What a search takes is the searcher's and
---the list loses it (`GetActorLoot` shows what is left); once it is empty the prompt goes. An empty list takes it away at once.
---`OnPlayerLootActor` may refuse a search. The body stays until `DestroyEntity`. This is the actor's own list - what it
---wears and carries (`SetActorInventory`) is not given up unless you put it here.
---@param id number the actor or animal
---@param items table a list of `{class =, amount =, health =}`; `amount` 1 and `health` 100 by default
---@return boolean `false` for anything but a server actor or animal
function SetActorLoot(id, items) end

---What a dead actor's or animal's body still holds for a search.
---@param id number the actor or animal
---@return table|nil a list of `{class =, amount =, health =}` (empty once searched bare); `nil` for anything but a server actor or animal
function GetActorLoot(id) end

---Lets players butcher a dead animal the game's own way - or not.
---
---Off by default. With it on, a dead animal that nobody has butchered yet offers the game's own held "Butcher" to every player
---within reach: the butcher plays the game's butchering, which skins the carcass, and takes the game's own meat for that animal
---from it (the game's exchange screen opens on it); the others see the butcher at it, and the carcass stays skinned for everyone,
---players who come by later too. One player butchers a carcass, once. `OnPlayerButcher` may refuse a player. It works beside `SetActorLoot`: what
---you put on the body is searched as before. Set it at `CreateAnimal` or at `OnActorDeath`, and keep the carcass long enough
---to be found - a dead animal stays until you remove it (`DestroyEntity`).
---@param id number the animal
---@param enabled? boolean `true` (the default) = it may be butchered; `false` = no butchering
---@return boolean `false` for anything but a server animal
function SetActorButcher(id, enabled) end

---Whether a player butchered the animal's carcass.
---@param id number the animal
---@return boolean `false` for a whole carcass, a living animal and anything that is no server animal
function IsActorButchered(id) end

---The prompt under an actor's name within reach - the use key on it reaches the mode.
---
---A short text ("Talk", "Trade", "Challenge", "Ask about the road") shown as `[E] Talk` under the name to a player within 3.5 m,
---and in the game's own use hint while they look at the body; the use key then fires `OnPlayerInteractActor`. The text is
---shown as written, up to 32 characters; one that starts with `@` is a text key of the game's own (`"@ui_hud_talk"`), shown in
---the player's language. `nil` or `""` takes it off (the use key does nothing on the actor). An actor
---with a shop gets "Trade" by itself; a prompt set after that replaces the word, the shop still opens.
---@param id number the actor
---@param prompt string|nil the word; `nil` = none
---@return boolean `false` for anything but an actor
function SetActorPrompt(id, prompt) end

---An actor's prompt.
---@param id number the actor
---@return string `""` when none
function GetActorPrompt(id) end

---The label over an actor's body on every screen.
---
---By default the label is the actor's name (`CreateActor`); this replaces it - a rank, a faction, a title. `nil` or `""`
---puts the name back. At most 48 characters. An actor created without a name wears no label until it gets one here. The
---label keeps its color (`SetActorColor`) and hides behind walls like a player's.
---@param id number the actor
---@param text string|nil the label; `nil` = the name again
---@return boolean `false` for anything but an actor
function SetActorNameplate(id, text) end

---An actor's label as set.
---@param id number the actor
---@return string `""` when it shows its name
function GetActorNameplate(id) end

---The label one viewer alone reads over an actor.
---
---Like `SetPlayerNameplateFor` for an actor: `viewer` reads `text` over it instead of its own label (`SetActorNameplate`),
---which everyone else keeps reading; `""` gives the viewer the actor's own label again. At most 48 characters. Gone when the
---actor is destroyed.
---@param viewer number the player who reads the label
---@param id number the actor
---@param text string the label; `""` = the actor's own again
---@return boolean `false` for anything but a living person actor, or a viewer not connected
function SetActorNameplateFor(viewer, id, text) end

---The label one viewer alone reads over an actor (SetActorNameplateFor).
---@param viewer number the player who reads it
---@param id number the actor
---@return string the viewer's own label; `""` when they read the actor's own
function GetActorNameplateFor(viewer, id) end

---The color of an actor's label.
---
---`0xRRGGBBAA`, like `SetPlayerColor`; `0` puts the default back (the game's gold).
---@param id number the actor
---@param color number `0xRRGGBBAA`; `0` = the default
---@return boolean `false` for anything but an actor
function SetActorColor(id, color) end

---An actor's label color as set.
---@param id number the actor
---@return number `0xRRGGBBAA`; `0` = the default
function GetActorColor(id) end

---Makes an actor a vendor - the use key on it opens the shop.
---
---The actor shows "Trade" under its name within reach and the use key opens the shop on the player, on the
---game's own trade screen (`SetShopScreen` keeps the panel; `OnPlayerInteractActor` and `OnPlayerOpenShop` may stop
---it). The screen closes when the player walks 4 m from the actor or it dies. `nil` takes the shop off (the screens on it
---close). A vendor is not invulnerable by itself: `SetActorInvulnerable` - or make it with `CreateVendor`, which does both.
---@param id number the actor
---@param shop number|nil the shop; `nil` = none
---@return boolean `false` for anything but an actor, or no such shop
function SetActorShop(id, shop) end

---The shop an actor sells.
---@param id number the actor
---@return number the shop; `nil` when none
function GetActorShop(id) end

-- ======== Actor life ============================================================
-- What brings a town's people to life: an NPC actor (`CreateActor`) can **ride** a horse, **speak**
-- the game's own lines and **use** the level's seats, beds and work spots or stand in a **pair** animation with another actor. All of
-- it is the server's: every player sees the same rider on the same road, hears the same line from the same body, finds the same
-- man on the same bench - and a player who arrives later finds them there too.
-- 
-- - **Riding:** `MountActor` puts an actor on a horse nobody rides or owns (`CreateHorse`): it walks to the horse's side and climbs
--   on with the game's own mount; `MoveActor` then rides - the speed picks the gait (about `1.8` a walk, `4` a trot, `7` a canter, `11`
--   a gallop) and the horse walks around walls on the navigation mesh like a walking actor; `DismountActor` gets it off. A mounted
--   actor does not fight, and its death, its horse's, either one's removal or a knock-out take it off at once (`OnActorDismount`).
-- - **Speaking:** `PlayActorBark` says one line of one of the game's barks (`"greeting"`, `"farewell"`, `"self_talk"`,
--   `"work_sigh"`, `"market_call"`, `"pray"`, `"pain"` ...), `PlayActorVoice` one line by its id, `PlayActorConversation` a whole
--   conversation of the game between two actors (gossip, greetings, a trader with a customer). The players around hear the line from
--   the actor's body in their own game's language, with the face the game animated for that recording and its gesture. Each actor
--   speaks in its soul's voice where the game recorded the line in it (`SetActorVoice` gives it another), else in a voice of its
--   gender. The lines: the voice lines.
-- - **Seats, beds and work spots:** `GetSmartObjects` lists the level's own - benches, chairs, stools, beds, wells, weeding beds,
--   debarking trestles, waiting and leaning places, more than 14,000 of them on Kuttenberg's map - and `SetActorUse` sends an actor to
--   one: it walks there, sits down (kneels, leans, starts work) with the game's own animation, stays until `StopActorUse` or a
--   `MoveActor`, and gets up before it walks away. `SetActorUseAt` does an activity anywhere. The activities:
--   the activities.
-- - **Pairs:** `PlayActorPairAnim` stands two actors face to face in one of the game's pair animations - talking, drinking and
--   cheering, dancing.
-- 
-- An actor in an activity or on a horse keeps its pose: `SetActorAnim` and `TurnActor` answer `false` until it is up or off.
-- The voice lines and the level's seats and work spots come from the server's export of the game's tables (re-export with this
-- version: Exporting the game's tables).

---**Called by the server** - An actor sits on its horse - MountActor's climb is done.
---@param id number the actor
---@param horse number the horse
function OnActorMount(id, horse) end

---**Called by the server** - An actor is off its horse.
---
---After `DismountActor` (the game's dismount is over), or at once when its death, its horse's death, either one's removal or a
---knock-out threw it off.
---@param id number the actor
---@param horse number the horse it rode
function OnActorDismount(id, horse) end

---**Called by the server** - The line PlayActorVoice or PlayActorBark started is over.
---
---Not called for a line cut by `StopActorVoice` or by the actor's next line, nor for the lines of a conversation
---(`OnActorConversationEnd` tells its end).
---@param id number the actor
---@param line string the line's id
function OnActorVoiceEnd(id, line) end

---**Called by the server** - The conversation PlayActorConversation started is over.
---@param first number the first actor named
---@param second number the second actor named
---@param conversation string the game's name of the conversation that was held
function OnActorConversationEnd(first, second, conversation) end

---**Called by the server** - An actor's activity or pair began, ended or never got under way.
---
---`state` is `"start"` once the actor is in place and the activity's loop plays (seated, kneeling, the pair talking), `"end"`
---when it got up (`StopActorUse`, a `MoveActor`) and `"cancel"` when it never got there (its walk ended short of the place, a
---pair's partner did not come within 30 s). An activity the server cut off - a death, a mount, a fight, the actor removed, another
---activity - ends without the callback.
---@param id number the actor
---@param activity string the activity's name, or the pair's
---@param state string `"start"`, `"end"` or `"cancel"`
function OnActorActivity(id, activity, state) end

---Puts an actor on a horse - it walks to it and climbs on with the game's own mount.
---
---The horse must be alive, unridden and nobody's (`SetHorseOwner`); the actor standing free (not dead, knocked out, carrying,
---carried, in a cart or in a fight). An actor farther than 2.5 m walks to the horse's left side first. The climb takes about three
---seconds on every screen; `OnActorMount` says when it sits. While an actor holds it, the horse is the server's: no player minds
---it or mounts it. `instant = true` seats it at once, wherever the horse stands.
---@param id number the actor
---@param horse number the horse
---@param instant? boolean `true` seats it at once
---@return boolean `false` when it cannot (the server's log says why)
function MountActor(id, horse, instant) end

---Gets an actor off its horse with the game's dismount.
---
---About three seconds; the actor then stands beside the horse and `OnActorDismount` runs. `instant = true` sets it down at once.
---The horse stays where it is, loose - a player may take it, or `DestroyEntity` it.
---@param id number the actor
---@param instant? boolean `true` = at once
---@return boolean `false` when it rides no horse
function DismountActor(id, instant) end

---The horse an actor is on.
---@param id number the actor
---@return number|nil the horse while it climbs on, rides or climbs off; `nil` on foot
function GetActorHorse(id) end

---Whether an actor sits in the saddle.
---@param id number the actor
---@return boolean `true` once its climb is done, until its dismount starts
function IsActorMounted(id) end

---An actor says one of the game's lines by its id.
---
---`line` is a line id of the voice lines. The players within `range` metres of the actor hear it
---from its body (20 m when not given, at most 100), with the line's own face and in their game's language. The voice is `voice`
---when the line was recorded in it, else the actor's own (`SetActorVoice`, else its soul's), else a voice of its gender that has
---the line - the same one for the same actor every time. A line replaces the one the actor was saying. `OnActorVoiceEnd` at its end.
---@param id number the actor
---@param line string the line's id (any case)
---@param voice? string|nil a voice to say it in, when the line has it
---@param range? number metres it carries (20 when not given)
---@return number the line's length in seconds; `0` when it cannot (not a living actor, no such line, an export without the voice lines)
function PlayActorVoice(id, line, voice, range) end

---An actor says a line of one of the game's barks.
---
---`bark` is one of the plain words below or the game's own name of a bark (the barks). The line is
---picked at random among those the actor's own voice recorded, else among those a voice of its gender has; a woman's body takes the
---women's pool of a word. The words: `greeting`, `greeting_reply`, `greeting_respectful`, `greeting_noble`, `greet_player`, `farewell`,
---`self_talk`, `whistle_happy`, `whistle_sad`, `work_sigh`, `work_talk`, `smith_work`, `butcher_work`, `farmer_work`,
---`woodcutter_work`, `carpenter_work`, `guard_mutter`, `innkeeper_talk`, `innkeeper_closing`, `toast`, `order_drink`, `order_food`,
---`market_call`, `market_call_baker`, `market_call_smith`, `market_call_food`, `shop_welcome`, `shop_thanks`, `shop_no_sale`, `pray`,
---`pray_morning`, `pray_night`, `amen`, `going_to_bed`, `woken_up`, `let_me_sleep`, `weapon_seen`, `sneaking_seen`, `pain`,
---`pain_heavy`, `dying`, `wounded_moan`, `comfort_wounded`, `fight_grunt`, `out_of_breath`, `spur_horse`.
---@param id number the actor
---@param bark string a word above or a bark's name
---@param range? number metres it carries (20 when not given)
---@return string the id of the line it says; `""` when none
function PlayActorBark(id, bark, range) end

---Two actors hold one of the game's conversations, line by line.
---
---`conversation` is the game's name of one (the conversations) or a plain word picked by the
---two actors' genders: `greeting`, `greeting_noble`, `farewell`, `gossip`, `gossip_kuttenberg`, `gossip_noble`, `gossip_tavern`,
---`gossip_drunk`, `gossip_miners`, `gossip_smelters`, `gossip_bandits`, `gossip_bandits_road`, `gossip_beggars`, `gossip_travellers`,
---`shop_chat`, `guard_change`, `argument`. The actor whose body fits a part's gender takes it. They turn to each other; one standing
---listens in the game's dialogue pose between its lines (a seated or working one keeps its pose, its gestures from the waist up);
---each line comes in the speaker's voice with its gesture and face. `sequence` picks one of the conversation's ways through it
---(`-1`, or none, at random). `OnActorConversationEnd` at its end.
---@param first number an actor
---@param second number the other
---@param conversation string a word above or a conversation's name
---@param sequence? number which way through it; `-1` at random
---@param range? number metres it carries (20 when not given)
---@return number the seconds it lasts; `0` when it cannot
function PlayActorConversation(first, second, conversation, sequence, range) end

---Cuts what an actor is saying, on every screen.
---
---A conversation it is in ends for both, without `OnActorConversationEnd`.
---@param id number the actor
---@return boolean `false` when it was silent
function StopActorVoice(id) end

---Whether an actor is saying a line or is in a conversation.
---@param id number the actor
---@return boolean
function IsActorSpeaking(id) end

---The voice an actor speaks in.
---@param id number the actor
---@return string the game's voice abbreviation (the voices): the one SetActorVoice gave it, else its soul's; `""` = a voice of its gender per line
function GetActorVoice(id) end

---Gives an actor one of the game's voices.
---
---`voice` is a voice abbreviation of the voices; `""` gives it its soul's back. A line the voice never
---recorded is said in another voice of the actor's gender.
---@param id number the actor
---@param voice string a voice abbreviation; `""` = its soul's
---@return boolean `false` for an unknown voice or anything but an actor
function SetActorVoice(id, voice) end

---A line's English text - the game's subtitle.
---@param line string the line's id
---@return string `""` for an unknown line
function GetVoiceLineText(line) end

---The line ids of a bark.
---@param bark string a PlayActorBark word or a bark's name
---@param female? boolean `true` = a woman's lines of the word
---@return table the line ids, `{}` for an unknown bark
function GetBarkLines(bark, female) end

---Sends an actor to one of the level's seats, beds or work spots to do what the game's people do there.
---
---`key` is a smart object's key of `GetSmartObjects`. The actor walks to the object (at 1.3 m/s, around walls on the navigation
---mesh), starts the activity with the game's own animation - sits down, lies down, kneels in the bed, takes up the work - and stays in
---it until `StopActorUse` or a `MoveActor` (it gets up first, then walks). `OnActorActivity` tells `"start"` and `"end"`. One
---actor an object; a woman takes the women's animation where the game has one. A chore mimes its tool (no draw knife in the hands at
---the trestle).
---@param id number the actor
---@param key string the smart object's key
---@return boolean `false` for an unknown or taken object, an activity without an animation for this body, or an actor that is not standing free
function SetActorUse(id, key) end

---An activity anywhere - the actor at a place you name.
---
---`activity` is an activity of the activities (`"sit_ground"`, `"pray_kneel"` ...); `x`, `y`, `z` and `yaw` say
---where the actor is while in it, facing `yaw` degrees - on a seat, the seat's surface. It walks there first.
---@param id number the actor
---@param activity string the activity's name
---@param x number metres
---@param y number metres
---@param z number metres
---@param yaw number degrees (0 = +Y, counter-clockwise)
---@return boolean
function SetActorUseAt(id, activity, x, y, z, yaw) end

---Gets an actor up from its activity or pair.
---
---It plays the activity's end (stands up, gets off the bed) and `OnActorActivity` tells `"end"`; a pair ends for both.
---`immediate = true` stands it up at once, without the callback.
---@param id number the actor
---@param immediate? boolean `true` = at once
---@return boolean `false` when it is in none
function StopActorUse(id, immediate) end

---An actor's activity or pair.
---@param id number the actor
---@return string the activity's name or the pair's; `""` = none
function GetActorUse(id) end

---The smart object an actor uses.
---@param id number the actor
---@return string its key; `""` = none, or an activity anywhere
function GetActorUseObject(id) end

---The level's seats, beds and work spots around a point.
---
---Every smart object of the server's level within `radius` metres (at most 500 m, 256 of them), the nearest first. `use` narrows
---them to an activity, a kind or the game's helper class; the kinds are `"sit"`, `"lie"`, `"work"`, `"wait"`, `"lean"`, `"pray"`,
---`"eat"`, `"drink"`, `"talk"`, `"dance"` and `"cheer"`. `freeOnly` leaves out the ones an actor uses. Empty without the tables export
---of this version (re-export).
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius? number metres (10 when not given)
---@param use? string|nil an activity, a kind or a helper class
---@param freeOnly? boolean `true` = only the free ones
---@return table `{{key =, activity =, kind =, helper =, x =, y =, z =, yaw =, distance =, user =}, ...}`: the key SetActorUse takes, the activity done there, its kind, the game's helper class, the place (metres, yaw degrees), the distance and the actor using it (`nil` = free)
function GetSmartObjects(x, y, z, radius, use, freeOnly) end

---The nearest free seat, bed or work spot.
---
---The first of `GetSmartObjects(x, y, z, radius, use, true)`.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius? number metres (10 when not given)
---@param use? string|nil an activity, a kind or a helper class
---@return table|nil the object's table as GetSmartObjects gives it; `nil` when none is free in reach
function GetNearestSmartObject(x, y, z, radius, use) end

---Two actors in one of the game's pair animations, face to face.
---
---`pair` is `"talk"`, `"talk2"`, `"talk_drink"`, `"talk_drunk"`, `"dance"`, `"dance2"`, `"couple_dance"` (the woman takes the
---woman's part), `"watch"` or a pair's game name (the pairs). The second actor walks to its place facing the
---first, then both play until `StopActorUse` on either or a `MoveActor`; `OnActorActivity` tells each `"start"` and `"end"`
---with the pair's name.
---@param first number the actor who stays where it is
---@param second number the actor who comes to it
---@param pair? string a word above or a pair's name (`"talk"` when not given)
---@return boolean `false` for an unknown pair, the same actor twice, or an actor that is not standing free
function PlayActorPairAnim(first, second, pair) end

---The names PlayActorPairAnim takes.
---@return table the plain words, then the game's pair names
function GetPairAnims() end

-- ======== Zones =================================================================
-- A **zone** is a region the server watches for the mode: a box between two corners, or a circle around a point with any height
-- unless a `zMin`/`zMax` band is given. Once per tick every player in the world is tested against every zone and the mode hears
-- `OnPlayerEnterZone` and `OnPlayerLeaveZone` on the edges. Ids start at `1` and are reused after a destroy; there are 4096.
-- A zone has a private data bag (`SetZoneData`). Zones go with a reload.
-- 
-- A zone can also be a **target**: `SetZoneHittable` makes it catch the arrows, bolts and balls players shoot and the swings
-- they throw. The server flies every shot itself from where it left the bow, stops it at the ground, at the level's walls (with
-- the collision export) and at a body it struck, and calls `OnProjectileHitZone` for every target the arrow reached, at the
-- moment it got there; a swing that reaches a target calls `OnMeleeHitZone`. A target is invisible and stops nothing - put a
-- prop or an actor there for something to see. `CreateSphereZone` makes a ball-shaped zone, and `AttachZoneToEntity` lets a
-- zone ride a prop, an actor, a horse or a cart, for a moving target.

---**Called by the server** - A player's position of record entered a zone.
---@param pid number the player
---@param zone number the zone
function OnPlayerEnterZone(pid, zone) end

---**Called by the server** - A player left a zone - walked or was moved out, despawned, respawned elsewhere, disconnected.
---@param pid number the player
---@param zone number the zone
function OnPlayerLeaveZone(pid, zone) end

---**Called by the server** - A player's arrow, bolt or ball reached a target zone.
---
---Called for every zone marked with `SetZoneHittable` that the shot's flight entered before it stopped - at the ground, at a
---wall (when the server has the collision export) or in a body it struck - at the moment the arrow got there, a quarter of a
---second later still. A shot flies on through a zone, so one arrow can reach several. A zone the shooter stands in does not
---count for the shot leaving it.
---@param pid number the shooter
---@param zone number the zone reached
---@param weapon string the bow, crossbow or gun by its table name
---@param ammo string the arrow, bolt or ball by its table name
---@param x number where the shot entered the zone, metres
---@param y number metres
---@param z number metres
function OnProjectileHitZone(pid, zone, weapon, ammo, x, y, z) end

---**Called by the server** - A player's swing reached a target zone.
---
---Half a second after the swing began, the server reaches from the player's chest along their facing as far as the drawn weapon
---reaches (a fist about a metre) and calls this for every zone marked with `SetZoneHittable` the reach enters. It is a
---reach, not the blade's path: a training post or a straw dummy, not a duel.
---@param pid number the player
---@param zone number the zone reached
---@param weapon string the drawn weapon by its table name; `"fists"` without one
---@param x number where the reach entered the zone, metres
---@param y number metres
---@param z number metres
function OnMeleeHitZone(pid, zone, weapon, x, y, z) end

---A box zone between two corners.
---
---The corners may be given in any order. `nil` when the 4096 ids are used up.
---@param x1 number one corner, metres
---@param y1 number metres
---@param z1 number metres
---@param x2 number the opposite corner
---@param y2 number metres
---@param z2 number metres
---@return number the zone's id; `nil` when none is free
function CreateZone(x1, y1, z1, x2, y2, z2) end

---A circular zone around a point - a cylinder of any height, or of a band.
---
---Without `zMin` and `zMax` the height does not matter; with `zMin < zMax` only that band counts.
---@param x number the centre, metres
---@param y number metres
---@param radius number metres
---@param zMin? number the bottom of the band
---@param zMax? number the top of the band; without a band any height counts
---@return number the zone's id; `nil` when none is free
function CreateCircleZone(x, y, radius, zMin, zMax) end

---A ball-shaped zone around a point - a target hung in the air, or the space around a prop.
---
---A player is inside when their position of record is within `radius` of the centre, like any zone; as a target
---(`SetZoneHittable`) it catches what flies or swings into the ball.
---@param x number the centre, metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@return number the zone's id; `nil` when none is free
function CreateSphereZone(x, y, z, radius) end

---Makes a zone a target - it catches the shots and swings that reach it.
---
---A target hears every arrow, bolt or ball a player shoots into it (`OnProjectileHitZone`) and every swing whose reach gets
---there (`OnMeleeHitZone`). Any zone can be one: a box, a circle, a sphere. Players walking into it still count as being
---in the zone.
---@param id number the zone
---@param hittable? boolean `true` (the default) = a target; `false` = an ordinary zone again
---@return boolean `false` when there is no such zone
function SetZoneHittable(id, hittable) end

---Whether a zone is a target (SetZoneHittable).
---@param id number the zone
---@return boolean `false` for an ordinary zone or no such zone
function IsZoneHittable(id) end

---Lets a zone ride an entity - a moving target, a zone around a cart.
---
---Every tick the zone's centre is put `ox`, `oy`, `oz` metres from the entity's position: a prop, an actor, a horse, a cart.
---`nil` as the entity leaves the zone where it is. A destroyed entity leaves the zone where it last was.
---@param id number the zone
---@param entity number|nil the entity; `nil` detaches the zone
---@param ox? number the offset from the entity, metres (0 by default)
---@param oy? number metres
---@param oz? number metres
---@return boolean `false` when there is no such zone or entity
function AttachZoneToEntity(id, entity, ox, oy, oz) end

---Removes a zone.
---
---Nobody hears a leave for it. Its id may be reused by the next zone.
---@param id number the zone
---@return boolean `false` when there is no such zone
function DestroyZone(id) end

---Whether the player is inside a zone, as of the last tick's test.
---@param pid number the player
---@param id number the zone
---@return boolean
function IsPlayerInZone(pid, id) end

---Whether a point lies inside a zone.
---@param id number the zone
---@param x number metres
---@param y number metres
---@param z? number metres (`0` without)
---@return boolean
function IsPointInZone(id, x, y, z) end

---The players inside a zone right now.
---@param id number the zone
---@return table a list of pids
function GetZonePlayers(id) end

---The zones a player is inside right now.
---@param pid number the player
---@return table a list of zone ids
function GetPlayerZones(pid) end

---Every zone the mode has made.
---@return table a list of zone ids
function GetZones() end

---A zone's shape.
---@param id number the zone
---@return table `{circle=, sphere=, minX=, minY=, minZ=, maxX=, maxY=, maxZ=, x=, y=, z=, radius=, hittable=, entity=}`: `circle` true for a circle zone and `sphere` for a sphere, the bounds, the centre (`z` 0 for a circle of any height) and radius (a box's centre and half its diagonal), whether it is a target, the entity it rides (`nil` = none); `nil` when there is no such zone
function GetZoneInfo(id) end

---Stores a value on a zone, private to the server.
---
---Any Lua value; gone with the zone. The mode's way to mark what a zone is for.
---@param id number the zone
---@param key string the key
---@param value any the value; `nil` removes the key
---@return boolean `false` when there is no such zone
function SetZoneData(id, key, value) end

---A value stored on a zone with SetZoneData.
---@param id number the zone
---@param key string the key
---@return any the value; `nil` when unset or no such zone
function GetZoneData(id, key) end

-- ======== The world - clock, weather, terrain, the navmesh, the geometry ========
-- The server owns the **world clock** and the **weather**: every client follows them, so the whole server sees one time of day and
-- one sky (`[world]` in `server.toml` sets the start). The clock is hours since midnight (`13.5` = 13:30) and runs at a ratio of
-- game seconds per real second; the weather is a **preset** name or one of the level's own sky profiles
-- (Weather); the rain is a lever on top. The **terrain height** comes from the level's heightmap when the server
-- has one, and the **navigation mesh** - the game's own, when the operator exported it (World data) -
-- answers for walks, floors and reachability: the NPC actors walk around walls on it by themselves. The **collision geometry**
-- - the level's walls, roofs, floors and trees, exported from the game's own physics world - answers rays: what is in the
-- way, whether two points see each other, the true floor under a point. The doors the server knows are open let a ray through.

---The world clock, in hours since midnight.
---@return number `0` .. `24`; `13.5` = 13:30
function GetWorldTime() end

---Sets the world clock for everyone.
---
---Every client's calendar follows. The game's own calendar only moves **forward**: a jump backwards is applied as a jump to
---the same time the next day.
---@param hours number hours since midnight, `0` .. `24` (`13.5` = 13:30)
function SetWorldTime(hours) end

---Hours as HH:MM.
---@param hours? number hours since midnight; without it, the world clock now
---@return string `"13:30"`
function FormatWorldTime(hours) end

---How fast the world clock runs - game seconds per real second.
---@return number `15` is the game's own pace, `0` frozen
function GetTimeRatio() end

---Sets how fast the world clock runs.
---@param ratio number game seconds per real second; `15` = the game's own pace, `0` = frozen
function SetTimeRatio(ratio) end

---The rain every client shows.
---@return number `0` .. `1`: the weather's own rain, or the amount `SetRain` forced
function GetRain() end

---Forces rain on every client, or hands the rain back to the weather.
---
---The rain is a lever on top of the weather profile: the profile sets the clouds, the fog and the light, and each preset
---brings its own rain (`showers` 0.5, `drizzle` 0.25, `storm` 1, the rest none; a variant its own - Weather)
---- the same amount on every client. This
---forces another amount; `-1` hands the rain back to the weather. `/rain` is the built-in.
---@param intensity number `0` .. `1`; `-1` = the weather's own rain
function SetRain(intensity) end

---The sky profile every client follows.
---@return string a profile name (`cloudless_sunny`, `foggy_storm` ...): the mode's, or the one the server's rotation is on
function GetWeather() end

---Changes the sky for everyone - by a preset name or a level profile.
---
---A **preset** is a friendly name for one of the level's time-of-day profiles: `clear` (or `sunny`), `fair`, `cloudy`, `overcast`,
---`showers`, `drizzle` (or `fog`), `storm`, `dry_storm` (`GetWeatherPresets` maps them; Weather lists the
---profiles). A profile name passes through as it is. Each client blends the new sky in over `blendSeconds` (`[world]
---weather_blend`, 10 s, without them). `""` hands the sky back to the **server's rotation**: a sky rolled from the chances
---every 3 to 5 game hours (`SetWeatherChances` - the fair ones most often by default), the same for every client. The
---`/weather` built-in is the same call (`/weather auto` for the rotation).
---@param presetOrProfile string a preset or a profile name; `""` = the server's rotation
---@param blendSeconds? number seconds the change blends in over (`[world] weather_blend`)
---@return boolean `false` for a name that is neither a preset nor a profile
function SetWeather(presetOrProfile, blendSeconds) end

---The preset names and the profiles they stand for.
---@return table `{preset = profile, ...}`
function GetWeatherPresets() end

---How often each kind of weather comes up in the server's rotation, and how long a sky stays.
---
---The server rolls the sky for everyone (`[world] weather ""`, or after `SetWeather("")`): at every roll each kind comes up by
---its **weight** - relative numbers, so `{clear = 70, showers = 25, storm = 5}` is a storm about one sky in twenty. The kinds
---are `clear`, `fair`, `cloudy`, `overcast`, `showers`, `drizzle`, `storm`, `dry_storm` (the other preset names - `sunny`,
---`rain`, `fog` - are aliases and add up); a kind left out, or at `0`, never comes up. A key may also be one of the level's own
---profiles, such as a kind's `_B` variant (Weather lists them with the game's own chances). A rolled sky
---holds `minHours` to `maxHours` of game time (3 to 5 by default; the same sky may come up again and simply stays), then the
---next is rolled. Every client follows the rolled sky and its rain, and a player who joins gets the sky up now.
---
---A sky up now that the new chances leave out goes at once (blended in over two minutes); one they keep stays for what is left
---of its hold. While `SetWeather` names a sky the chances wait for the rotation. `nil` (or `{}`) hands the rotation back to
---the server's own mix. An admin's `/weather chances` shows them.
---@param chances table `{kind = weight, ...}` - weights of `0` or more; `nil` = the server's own mix
---@param minHours? number the shortest a rolled sky stays, in game hours (above `0`, up to `168`); `nil` = 3 to 5
---@param maxHours? number the longest, not below `minHours`; `nil` = `minHours`
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (an unknown kind, a weight below 0, every weight 0, a hold out of range)
---@return string reason
function SetWeatherChances(chances, minHours, maxHours) end

---The rotation's chances and how long a sky stays.
function GetWeatherChances() end

---The terrain height at a point, from the level's heightmap.
---
---The server has a heightmap when `[validation] heightmap` names one the operator exported from the game; without one, or
---outside the sampled area, `nil`. Use it to place things on the ground where a `z` below `0` is not accepted.
---@param x number metres
---@param y number metres
---@return number metres; `nil` without a heightmap or outside it
function GetTerrainHeight(x, y) end

---Whether the server has the level's navigation mesh.
---
---`[validation] navmesh` names the file the operator exported from their game (the navigation guide). With it
---the NPC actors walk around walls and the functions below answer; without it they answer `nil` / `false` and an actor
---walks a straight line to its target.
---@return boolean
function HasNavmesh() end

---The corners of a walk between two points on the navigation mesh.
---
---The route an NPC actor would take, string-pulled to its corners: the first is the start snapped to the mesh, the last
---the end. `nil` when either point is off the mesh (more than 2 m from it sideways or 4 m up or down - a wall, a roof, the
---air), when no way joins them, or without a navmesh. Positions in metres, the level's world space. A path takes well
---under a millisecond across a village; a mode that asks every tick for every actor should not.
---
---Every search is bounded. An end on a part of the mesh that no way leads to (a closed room, a ledge) answers `nil` at
---once; any other search that visits more than `navmesh_search_nodes` nodes or takes longer than `navmesh_search_ms`
---milliseconds stops and answers `nil` too (both in `[validation]`, see the server's configuration; 16384 nodes and
---100 ms by default - a walk of several hundred metres through a town usually needs a few thousand). The server log
---names each such search with its two points. The same two points that ran out of budget answer `nil` at once for the
---next five seconds.
---@param x1 number the start
---@param y1 number
---@param z1 number
---@param x2 number the end
---@param y2 number
---@param z2 number
---@return table of `{x=, y=, z=}` corners, the start first; `nil` for no way
function FindPath(x1, y1, z1, x2, y2, z2) end

---Whether a walk joins two points on the navigation mesh.
---
---The same test as `FindPath` without the corners - a spawn point that can be walked out of, a goal that can be reached.
---Bounded the same way: a search past its budget answers `false`.
---@param x1 number the start
---@param y1 number
---@param z1 number
---@param x2 number the end
---@param y2 number
---@param z2 number
---@return boolean `false` off the mesh, unreachable, or without a navmesh
function IsReachable(x1, y1, z1, x2, y2, z2) end

---The navigation mesh's floor at a point.
---
---The height of the walkable surface under (or near) the point - a floor, a bridge, a stair - where
---`GetTerrainHeight` only knows the terrain. `nil` more than 2 m from the mesh sideways or 4 m up or down, or without
---a navmesh.
---@param x number metres
---@param y number metres
---@param z number a height near the floor asked for (the floor above or below within 4 m)
---@return number metres; `nil` off the mesh
function GetNavmeshHeight(x, y, z) end

---The nearest point on the navigation mesh.
---
---Where to put a spawn, a prop or an actor so that it stands on walkable ground: the point on the mesh nearest the one
---given, within 2 m sideways and 4 m up or down; `nil` when the mesh is farther, or without a navmesh.
---@param x number metres
---@param y number metres
---@param z number metres
function NearestNavmeshPoint(x, y, z) end

---Whether the server holds the level's collision geometry.
---
---`true` when the operator exported the level's geometry and `server.toml` names it (`[validation] collision`,
---the collision guide): `RayCast` answers, `IsLineOfSight` can say no, the floor under a player counts as the
---ground of the terrain check. Without it the three functions answer `nil`, `true` and `nil`.
---@return true when the geometry is loaded
function HasCollision() end

---The nearest surface along a line.
---
---Shoots a ray from one point to the other through the level's static geometry and answers with the first surface it
---meets: where, which way it faces, how far along, the engine's material id of a mesh triangle (0 for the primitives),
---and - when the surface belongs to a game entity (a door, a chest, a ladder) - the entity's class and name. Players,
---actors and horses are not in the geometry; the doors the server's records say are open are let through.
---@param x1 number metres, the start
---@param y1 number metres
---@param z1 number metres
---@param x2 number metres, the end
---@param y2 number metres
---@param z2 number metres
function RayCast(x1, y1, z1, x2, y2, z2) end

---Whether nothing stands between two points.
---
---`true` when a ray from the first point reaches the second without meeting the level's geometry - a wall, a roof, a
---tree, a closed door. Always `true` without the geometry. The server uses the same test on hit claims when
---`[validation] line_of_sight` is on (a blow through a wall is refused).
---@param x1 number metres
---@param y1 number metres
---@param z1 number metres
---@param x2 number metres
---@param y2 number metres
---@param z2 number metres
---@return true when the line is clear
function IsLineOfSight(x1, y1, z1, x2, y2, z2) end

---The surface under a point.
---
---The height of the first surface under the point - a ray from half a metre over it, 100 m down: the paving, a bridge, a
---roof, an upper storey, wherever the level's geometry is. Where the geometry has nothing (open terrain), `nil`: ask
---`GetTerrainHeight` then. Where a spawn, a prop or a teleport should land.
---@param x number metres
---@param y number metres
---@param z number metres, the height to look down from
function GetGroundZ(x, y, z) end

---Lets the game's own story quests run in the players' games, or keeps them asleep (the default).
---
---The game's quests are made for one player and the story's people, who are not in a multiplayer world: a quest that
---starts when a player walks into its place can play its cutscene, move the player somewhere they cannot leave and take
---everything they carry. So they sleep unless a mode turns them on. On, each player's game runs the quests of the level
---as a single-player game would - on that player's screen alone, and most of them cannot be finished.
---
---A game decides when it starts: the change reaches the players who join after it, and a game already running keeps
---what it started with. Call it when the mode starts.
---@param on boolean `true` runs the quests, `false` keeps them asleep
function SetStoryQuests(on) end

---Whether the players' games run the game's own story quests.
---@return boolean `true` when `SetStoryQuests` turned them on
function GetStoryQuests() end

-- ======== Doors and containers ==================================================
-- The level's own **doors**, **stashes** and the **loose items** on its tables and shelves are in sync on every client whatever
-- the mode does: a door one player opens swings on every screen; a chest one player loots is emptier for the next; a bowl one
-- player takes from a table is gone for everyone. A door's state of record is written by whoever uses it. A container's contents
-- are the server's from the start: the first time anyone opens a chest its contents are **rolled from the game's own loot
-- tables** - the loot preset the level placed that chest with, the way the single-player game fills it - or it opens empty when
-- the server is set that way (`[containers] loot`). One player holds a container at a time ("Someone is rummaging in it." for the
-- next), what they leave in it is what the next opener finds, and a chest somebody touched is rolled again after its **restock
-- period** (`[containers] restock`; world days on the server's clock). Stashes the game links to one master inventory share one
-- record, and a mode may link any keys itself (`LinkContainers`). A loose item the level placed (an item slot) works the same
-- way: taken by one player, that item - and only that one, never its neighbours on the shelf - is removed for the others, and the
-- level's own item comes back where it lay after the period; a mode can put items back at any time (`ResetWorldItem`,
-- `ResetWorldItems`). Every player's world follows the server's record: one who stays connected through a server restart sees the
-- items the record no longer holds taken come back. Doors, chests and
-- taken items **survive a restart** (the server's own database, made on the first start, nothing to configure). The **key** of a
-- door, a container or an item slot is the entity's level name - `AnimDoor[Door/door_village_left32_77d417c2-...]`,
-- `Stash7[Stash/stash_shelf_...]` - listed per level in Levels, and shown in the game to an admin by
-- `/objectinfo` (a label over every object around them); `GetNearestDoor` names "the door I stand at" without a key in
-- sight. Where a level gives one name to several containers or item slots (`Stash96` stands five times in `kutnohorsko`), one
-- of them keeps the name as its key and each other one is the name with its place in whole metres, `Stash96@3160,787,57` -
-- the key `OnPlayerOpenContainer` gets is that of the container the player stands at. A mode needs nothing for the sync; it
-- may veto (`OnPlayerUseDoor`,
-- `OnPlayerOpenContainer`, `OnPlayerTakeWorldItem`) or drive it (`SetDoorState`, `SetContainerItems`,
-- `SetContainerPreset`, `RollLoot`). The loot tables come with the tables export (Exporting the
-- game's tables); without it every chest opens empty and `/restock` has nothing to fill from.

---**Called by the server** - A player opened, closed, locked or unlocked a door - return `false` to refuse; for a checked door, before it moves.
---
---`open` and `locked` are the door's state **as it is now** on the player's client. Return `false` to refuse: the record stands,
---the player's door is put back, nobody else hears of it. Otherwise the state becomes the record and every client shows it.
---
---For a door you check first (`SetDoorCheck`) this is called **before the door moves**: the player's game holds the swing and
---waits for your answer, `open` and `locked` are the state the use would leave the door in, and a refusal keeps it still - no
---swing, nothing to put back. Return a text after the `false` and their chat shows it (`return false, "The vault is the guild's."`).
---The use's own reports that follow a yes are not asked about again.
---
---`side` says where the player stood. A level door has a keyhole on one side and a bolt on the other: `"inside"` is the bolt's
---side - from there the game unbolts a locked door for anyone, key or not - and `"outside"` is the keyhole's (or the side that
---cannot open the door at all while it is locked). A door without a lock of its own, and a player on an older game, give `""`.
---`wasLocked` is whether the door was locked when the use began: an opening from inside with `wasLocked` is someone unbolting it.
---To make the bolt's side ask for the key too, use `SetDoorLockSides`.
---
---Return value: `false` refuses the change (`false, "text"` also tells the player that text); anything else accepts it
---@param pid number the player
---@param key string the door's level name
---@param open boolean open now (a checked door - open once the use is done)
---@param locked boolean locked now (a checked door - locked once the use is done)
---@param side string `"inside"` (the bolt's side), `"outside"` (the keyhole's side) or `""` (no lock side)
---@param wasLocked boolean the door was locked when the use began
function OnPlayerUseDoor(pid, key, open, locked, side, wasLocked) end

---**Called by the server** - A player used your own row on a door (SetDoorPrompt) - the door itself did not move.
---
---Fires when a player within reach holds the use key on a door that carries a row of yours (`SetDoorPrompt`). What happens is
---yours to write - knock, ring for the owner, open a page with the house's price. To open the door after all, `SetDoorState`.
---@param pid number the player
---@param key string the door's level name
function OnPlayerInteractDoor(pid, key) end

---**Called by the server** - A player unlocked a chest with its key or a lockpick - return `false` to keep it locked.
---
---Their game has already unlocked it. Return `false` and their chest is locked again (the lockpick's work undone). Otherwise the
---chest is unlocked for everyone - on every screen and for a newcomer - or, where their own lock ruled it
---(`SetContainerLockedFor`), for them alone.
---
---Return value: `false` keeps it locked; anything else lets the unlock stand
---@param pid number the player
---@param key string the chest's key, as `OnPlayerOpenContainer` gets it
function OnPlayerUnlockContainer(pid, key) end

---**Called by the server** - A player wants to open a container - return `false` to refuse.
---
---Nothing has opened yet. Return `false` and the container stays shut for them, **without a word**: what the player is told is
---yours to decide. Return a text after the `false` and their chat shows it (`return false, "The guild's seal holds it shut."`,
---in the colour of the game's own refusal lines). A refusal that says nothing is also the way to open a screen of your own on a
---container, such as a chest on your web interface. Otherwise their client's loot window opens on
---the record's contents (`GetContainerItems`) and they hold the container until they close it - or for five minutes at most.
---The server has checked the request first: the player within about eight metres of the container's place, no more than four
---requests a second from one player, and nobody else holding the container. What they take and what they put in is checked
---against the record: a take is explained only by what the record held when they opened it, and a put counts only for what
---the server's records let go of - an item they never had is never booked in the container. What the container cannot hold
---(a chest keeps 200 stacks) comes back to the player, and so does a put from too far away or after the server freed
---their hold.
---
---Return value: `false` refuses saying nothing, `false, "text"` refuses and tells the player that text; anything else lets them open it
---@param pid number the player
---@param key string the container's key - its level name, or `<name>@<x>,<y>,<z>` for one of several the level gives that name
function OnPlayerOpenContainer(pid, key) end

---**Called by the server** - A player closed a container; the record holds what they left in it.
---@param pid number the player
---@param key string the container's key, as `OnPlayerOpenContainer` had it
function OnPlayerCloseContainer(pid, key) end

---**Called by the server** - A touched chest's restock period ran out and somebody is opening it - return `false` to hold it.
---
---The server is about to roll the chest's loot preset again: what players took comes back, what they put in is gone (the
---game's own rule). Return `false` and the chest stays as it is for one more period. The period is `[containers] restock`:
---the chest's own from the level (seven world days unless the level says otherwise), a number of world days, or never.
---
---Return value: `false` keeps the contents for another period; anything else lets the roll happen
---@param key string the container's level name
function OnContainerRestock(key) end

---**Called by the server** - A player's game took a loose item the level placed on a table or a shelf - return `false` to take it back.
---
---The item slot `key` held one item of class `class` (the GUID; `GetItemName` names it). Their game already put it in
---their inventory; return `false` and the server takes it out of their game at once - in every `[audit]` mode - the item goes
---back where it lay in their world, and the slot keeps its item for everyone else. Otherwise that item is gone for everyone and
---the level's own item comes back where it lay after the restock period (or when the mode puts it back - `ResetWorldItem`).
---
---The server checks the take against the level's data first, and a take that fails is taken back without asking the mode: an
---item of a slot the level's tables list must be that slot's item, taken within about eight metres of its place, not at a dice
---table, and from a slot not already taken (the leftover copy of a taken slot is tolerated once for each player and slot, for
---ordinary items only). `key` is empty for an item the tables list no slot of that class for near where the player stood - a
---loose item, and every take when the server has no tables export. Such an item is accepted only if it is an ordinary one the
---game's tables know, within a limit a minute, never of a guarded category (`[audit] guarded_categories`), and ammunition only up to what the
---player shot themselves.
---
---Return value: `false` refuses the take; anything else accepts it
---@param pid number the player
---@param key string the item slot's level name
---@param class string the item class GUID
function OnPlayerTakeWorldItem(pid, key, class) end

---Every door anyone touched.
---
---A door nobody used is at the level's default and not listed; the level lists have every door's key.
---@return table a list of door keys
function GetDoors() end

---A door's state of record - the shared one, or a virtual world's own.
---
---Every virtual world shares the doors of world `0` unless `SetVirtualWorldOwnDoors` gave it doors of its own; then `world` reads
---that world's.
---@param key string the door's level name
---@param world? number the virtual world whose doors to read; `0` (the default) = the shared ones
---@return boolean open two booleans `open, locked`; `nil` when nobody ever touched the door there (the level's default)
---@return boolean locked
function GetDoorState(key, world) end

---Opens, closes, locks or unlocks a door on every client - or in one virtual world's own doors.
---
---Without `world`, or for a world that shares the doors of world `0` (every world does by default), the door changes for everyone and
---is saved with the level. For a world given doors of its own (`SetVirtualWorldOwnDoors`) it changes in that world alone, for its
---players alone.
---@param key string the door's level name
---@param open boolean open
---@param locked boolean locked
---@param world? number the virtual world whose doors to set; `0` (the default) = the shared ones
function SetDoorState(key, open, locked, world) end

---Gives a virtual world doors of its own - what its players open or lock there stays in it.
---
---By default every virtual world (`SetPlayerVirtualWorld`) shares the doors of world `0`: a door used in any world moves for
---everyone. A world given its own doors starts from the level's own state of each door (shut, the level's own lock): a player's use
---there changes it for that world's players alone, and `SetDoorState` / `GetDoorState` take the world. One interior copied into
---many worlds - the flats behind one address - then has doors of its own in each copy. A player moved into or out of such a world sees
---its doors at once. A world's own doors are kept while the server runs (after a restart, set what your instances need again from
---your own storage); `false` forgets them and the world shares world `0`'s again. The mode's rules on a door (`SetDoorCheck`,
---`SetDoorPrompt`, `SetDoorLockSides`) hold in every world, and a door's key can be one world's (`SetDoorKey`); in
---`OnPlayerUseDoor` the user's world is `GetPlayerVirtualWorld`. The chests are still shared by every world.
---@param world number the virtual world (not `0`, whose doors are the shared ones)
---@param own? boolean `true` (the default) for doors of its own, `false` to share world `0`'s again
---@return boolean `false` for world `0` with `true`
function SetVirtualWorldOwnDoors(world, own) end

---Whether a virtual world keeps doors of its own (SetVirtualWorldOwnDoors).
---@param world number the virtual world
---@return boolean `false` for a world sharing the doors of world `0` (and for world `0`)
function HasVirtualWorldOwnDoors(world) end

---Decide before a door moves - the player's game waits for OnPlayerUseDoor.
---
---Names a door (its key) or every door (`"*"`) whose use waits for the mode: when a player opens or closes such a door, their game
---holds the swing and asks, and `OnPlayerUseDoor` decides **before** the door moves - `false` keeps it still (with a text, the
---player is told why), anything else lets it swing as usual. `on = false` takes a door back. The use waits for the round trip to the
---server, so name the doors you mean to judge, not every door of the level. At most 4096 doors by name (however long their names);
---changes go out to the players once, at the end of the tick, and only the doors that changed.
---@param key string the door's level name, or `"*"` for every door
---@param on? boolean `true` (the default) to decide first, `false` to take it back
---@return boolean `false` for an empty or too long key, or past 4096 doors
function SetDoorCheck(key, on) end

---Whether a use of the door waits for the mode.
---@param key string the door's level name
---@return boolean `true` when `SetDoorCheck` named it, or every door
function IsDoorChecked(key) end

---Puts a row of your own on a door ("Knock", "View the house") - its use reaches OnPlayerInteractDoor.
---
---The door shows your row beside its own: the player **holds** the use key for yours, a press still opens or closes the door. The
---text is shown as written (48 characters at most; one that starts with `@` is a text key of the game's own). Using it calls
---`OnPlayerInteractDoor` and moves nothing. While the row is up the door's own lockpick row gives way to it. `nil` or `""` takes
---it off. At most 4096 doors, and the rows' different texts together about 64 KB (a text many doors show counts once: a thousand
---doors with "Knock" or "View the house" is two texts). Changes go out to the players once, at the end of the tick, and only the
---doors that changed.
---@param key string the door's level name
---@param text string|nil the row's text; `nil` = none
---@return boolean `false` for an empty or too long key, or past 4096 doors or about 64 KB of different texts
function SetDoorPrompt(key, text) end

---A door's row of your own (SetDoorPrompt).
---@param key string the door's level name
---@return string `""` when it has none
function GetDoorPrompt(key) end

---Makes a locked door locked from both sides - its bolt's side asks for the key too.
---
---A level door's lock has two sides: a keyhole outside and a bolt inside. Locked, the outside asks for the key (or a lockpick), but
---the inside shows a plain "Open" and unbolts the door for anyone - the way a house is left in the story. `"both"` makes the inside
---ask for the key as well: the player with its key gets "Unlock and open", one who can pick locks gets the lockpick, and anyone
---else sees "Locked". `"game"` gives the door its own lock back. A door the mode locked that has no lock of its own
---(`SetDoorState`) opens for anyone from either side unless it is `"both"`. `key` may be `"*"`: every door of the level (a door's
---own `"both"` stays when `"*"` goes back to `"game"`). Keys of the mode's own make a door's key: `SetDoorKey`.
---@param key string the door's level name, or `"*"` for every door
---@param sides string `"both"` or `"game"` (the default)
---@return boolean `false` for another word, an empty or too long key, or past 4096 doors
function SetDoorLockSides(key, sides) end

---Whether a door is locked from both sides (SetDoorLockSides).
---@param key string the door's level name, or `"*"`
---@return string `"both"` or `"game"`
function GetDoorLockSides(key) end

---Makes one of your tagged items the key of a door - its holder unlocks the door the game's own way.
---
---`id` is a tagged item's id (`GivePlayerTaggedItem`: `"house-12-key"`). A player who holds that item in the bag gets the game's
---own "Unlock and open" on the locked door, from the side its lock opens from with a key (both sides with `SetDoorLockSides`
---`"both"`), and the use unlocks and opens it - `OnPlayerUseDoor` hears it as any use. The level's own key of the door still works.
---The item is the key wherever it is: dropped, in a chest or sold, it opens nothing for the one who no longer holds it. A copy is
---another tagged item with the same id in another player's bag. `nil` or `""` takes the key away. At most 4096 doors.
---
---With `world` the key is that virtual world's alone (`SetPlayerVirtualWorld` - a flat's copy of a house): for the players there it
---takes the place of the key every world shares (set without `world`), which still opens the door in every other world. `nil` or `""`
---with a world takes that world's key away, and the shared key is the door's key there again.
---@param door string the door's level name
---@param id string|nil the tagged item's id; `nil` = none
---@param world? number a virtual world whose own key this is; none (the default) = the key of every world
---@return boolean `false` for an empty or too long key or id, `"*"`, or past 4096 doors (each world's own keys: 4096 doors too)
function SetDoorKey(door, id, world) end

---The tagged item that is a door's key (SetDoorKey) - every world's, or the one for a virtual world.
---@param door string the door's level name
---@param world? number the virtual world whose players' key to read: its own, else every world's; none (the default) = every world's
---@return string the item's id, `""` when the door has none
function GetDoorKey(door, world) end

---Locks or unlocks a chest on every screen - the game's own lock, picked or opened with its key.
---
---`true` locks the chest the game's way: it shows "Locked", a player needs its key or a lockpick, and the server opens nothing for
---a player it is locked for. `false` unlocks it - the way to take the level's own locks off its chests. `nil` gives it back to the
---level (locked or not as the level placed it). `key` is a chest's key (`GetContainers`, `GetNearestContainer`, the
---level lists) or `"*"` for **every** chest of the level (a chest's own state wins over it). The state
---reaches every client at once and a newcomer when they arrive, and it survives a restart. A player who picks the lock or uses the
---key unlocks the chest for everyone - `OnPlayerUnlockContainer` may refuse. A player's own view is `SetContainerLockedFor`.
---@param key string the chest's key, or `"*"` for every chest
---@param locked boolean|nil `true` locked, `false` unlocked, `nil` the level's own
---@return boolean `false` for an empty or too long key
function SetContainerLocked(key, locked) end

---A chest's lock as the server keeps it.
---@param key string the chest's key, or `"*"`
---@return boolean|nil `true` locked, `false` unlocked; `nil` when the server keeps no lock for it (the level's own rules it)
function GetContainerLocked(key) end

---One player's own view of a chest's lock - locked for them, open for them, or back to everyone's.
---
---Over the chest's lock of record (`SetContainerLocked`) for this player alone: `true` the chest is locked on their screen and
---opens nothing for them, `false` it is open for them whatever the others see, `nil` takes their own state away. `key` may be `"*"`:
---every chest, for them (a chest's own state for them still wins). Kept for the session: set it again when they come back. A pick
---or a key that unlocks a chest their own lock ruled unlocks it for them alone.
---@param pid number the player
---@param key string the chest's key, or `"*"` for every chest
---@param locked boolean|nil `true` locked for them, `false` open for them, `nil` none of their own
---@return boolean `false` when the player is not connected or the key is empty or too long
function SetContainerLockedFor(pid, key, locked) end

---A player's own lock on a chest (SetContainerLockedFor).
---@param pid number the player
---@param key string the chest's key, or `"*"`
---@return boolean|nil their own state; `nil` when they have none
function GetContainerLockedFor(pid, key) end

---Makes one of your tagged items the key of a chest - its holder unlocks the chest the game's own way.
---
---As `SetDoorKey` for a chest (its key as `GetContainers` and `GetNearestContainer` name it): a player who holds the tagged
---item with that `id` in the bag gets the game's own "Unlock and open" on the locked chest, and the use unlocks it -
---`OnPlayerUnlockContainer` hears it like any unlock - then opens it. The level's own key still works. `nil` or `""` takes the key
---away. At most 512 chests.
---@param key string the chest's key
---@param id string|nil the tagged item's id; `nil` = none
---@return boolean `false` for an empty or too long key or id, `"*"`, or past 512 chests
function SetContainerKey(key, id) end

---The tagged item that is a chest's key (SetContainerKey).
---@param key string the chest's key
---@return string the item's id, `""` when the chest has none
function GetContainerKey(key) end

---Every container anyone opened.
---@return table a list of container keys
function GetContainers() end

---A container's contents of record.
---
---One entry per stack: the item class GUID (`GetItemName` names it), how many, the item's condition in percent. `nil` when
---nobody has opened the container yet - its contents are still the level's own, unknown to the server. One of the mode's
---**tagged items** (`GivePlayerTaggedItem`) a player put in is an entry of its own with its `id`, `name` and `text`, and it
---keeps them for whoever takes it out.
---@param key string the container's level name
---@return table a list of `{class=, amount=, health=, quality=}` (`quality` when known: an item put in keeps its own; a tagged item also `id=, name=, text=`); `nil` when never opened
function GetContainerItems(key) end

---Rewrites a container's contents; the next opener sees the new list.
---
---Each entry is a stack: the item **class GUID** (names are not resolved here - `GetItemClass` turns a name or an id into
---the GUID), an amount (`1`) and a condition in percent (`100`). An empty list empties the chest. Items taken from a container
---the server filled are the server's own in the item check. A player who has the chest open keeps the list their screen
---shows until they open it again - what they take is still limited to what it showed, and what they put in goes to the new
---contents; the next opener finds the new list. An entry with an `id` is one of the mode's **tagged items** (one item, with
---its `name` and `text` - `GivePlayerTaggedItem`): a letter left in a chest for a player to find, which keeps its tag in
---their bag.
---@param key string the container's level name
---@param items table a list of `{class=, amount=, health=, quality=}` (`amount`, `health` and `quality` optional; `id`, `name`, `text` for a tagged item)
function SetContainerItems(key, items) end

---Who has a container open right now.
---@param key string the container's level name
---@return number a pid; `nil` when nobody
function GetContainerUser(key) end

---Rolls one of the game's loot presets into a list of stacks.
---
---The presets are the game's own (`inventory_defaultJunk_default`, `inventory_smallChest_rare`, the shops' ...), read from
---your copy of the game by the tables export; the roll is the one a chest gets. Nothing for a preset the tables do not
---have (`HasLootPreset`). The list has the shape `SetContainerItems` takes and `GivePlayerItem` understands stack by stack.
---@param preset string the preset's name
---@return table a list of `{class=, amount=, health=}`; `{}` for an unknown preset
function RollLoot(preset) end

---Whether the loot tables have a preset of that name.
---@param preset string the preset's name
---@return boolean
function HasLootPreset(preset) end

---What the server knows of a container beyond its contents.
---
---`preset` is the loot preset it is rolled from (`""` none), `restock_in` the world seconds until the next opening rolls it
---again (`-1` when nothing is pending), `touched` whether a player took or put something since the last roll, and `record`
---the record it reads from - its own key, `master:...` for a stash the game links to a master inventory, another stash's key
---after `LinkContainers`. `nil` for a container nobody opened yet.
---@param key string the container's level name
---@return table `{preset=, restock_in=, touched=, record=}`; `nil` when there is no record
function GetContainerInfo(key) end

---The loot preset the level places a stash with.
---
---From the record when there is one, else from the tables export's level list - so it answers before anyone opened the chest.
---`""` when nothing is known for that key (no export, or a stash the level gives no preset).
---@param key string the container's level name
---@return string the preset name, empty when none is known
function GetContainerPreset(key) end

---Gives a container a loot preset and fills it from it now.
---
---The chest is rolled from the preset at once (whoever has it open keeps the list on their screen until they open it again) and again after every restock period
---once somebody touches it. An empty name takes the preset away: the contents stay as they are and nothing restocks.
---`false` for a preset the tables do not have.
---@param key string the container's level name
---@param preset string the preset's name, empty for none
---@return boolean `false` for an unknown preset
function SetContainerPreset(key, preset) end

---Rolls a container's preset again now.
---
---What players took comes back, what they put in is gone. `false` when the container has no preset (a chest filled by
---`SetContainerItems` alone, or one the level gives no preset). The chat command `/restock here | all | <key>` does the same
---for an admin.
---@param key string the container's level name
---@return boolean `false` when there is nothing to roll from
function RestockContainer(key) end

---Makes several stashes one - they share the first one's record.
---
---Whatever anyone puts in one is in every one of them, like the player's own chests in the single-player game (those the
---game links itself the server already shares). The others' own records, if any, are dropped. The link survives a restart.
---@param keys table a list of container keys; the first one's record serves all
function LinkContainers(keys) end

---Every loose item slot somebody emptied.
---
---The level places loose items on tables and shelves (the item slots - a bowl, a cup, a knife). One taken by any player is
---gone for everyone until it comes back where it lay after the restock period, or a mode puts it back (`ResetWorldItem`). A
---slot not listed still holds its item.
---@return table a list of item slot keys
function GetTakenWorldItems() end

---A taken loose item's slot - what it held, where, who took it, when it comes back.
---@param key string the item slot's level name
---@return table `{class=, x=, y=, z=, taken_by=, respawn_in=, pickup=}` (`respawn_in` in world seconds, `-1` never, `0` = a pickup stands there now, its id in `pickup`); `nil` for a slot that holds its item
function GetWorldItem(key) end

---Puts a pickup of the server's own where a taken loose item lay.
---
---A dropped item of the server's own appears where the item lay, for everyone; the slot stays taken while it lies there, and
---its restock clock starts again once somebody picks it up. To give the level its own item back - in its place on the table or
---the rack - use `ResetWorldItem` instead. `false` for a slot that is not empty.
---@param key string the item slot's level name
---@return boolean
function RespawnWorldItem(key) end

---Gives the level its own loose item back, in its place, on every client.
---
---The slot's record goes and every player's game shows the level's item where it lay again - on the table, the rack, the
---shelf - including a player who took it (their own copy stays theirs). A pickup that stood in for it (`RespawnWorldItem`) is
---taken away. This is what the restock period does by itself; a mode calls it to reset a house after a robbery, a stall at the
---day's start, a whole town between rounds. `false` for a slot that holds its item.
---@param key string the item slot's level name
---@return boolean
function ResetWorldItem(key) end

---Gives the level back every taken loose item, or those near a point.
---
---`ResetWorldItem` for every slot somebody emptied - or, with a point and a radius, for those whose item lay within that many
---metres of it. Returns how many came back.
---
---The server's record changes at once (`GetWorldItem` and `GetTakenWorldItems` answer the new state straight away); the
---players near each item are told a share each tick, so a batch of hundreds never floods the connection, and a player far
---away is told when they come near (the server's `[aoi] radius`). The same goes for the restock period's own returns and
---`TakeWorldItem`, so a mode never needs to spread such a batch out itself. A player who takes an item before their game
---was told is never shown it back.
---@param x? number the point, metres (all four left out = every taken slot)
---@param y? number
---@param z? number
---@param radius? number metres, above 0 (a point without a radius gives nothing back - never the whole level by a forgotten argument)
---@return number how many items came back
function ResetWorldItems(x, y, z, radius) end

---The level's loose item slots around a point - what each holds and whether it is taken.
---
---Every item slot of the level's tables export within the radius, nearest first, at most `max` (100, up to 1000): its key, the
---item class it holds, its place, and whether its item is taken now. A mode's view of a house's, a stall's or a shrine's
---things - to price a theft, to guard a table, to put things back. Empty when the server runs without the tables export.
---@param x number the point, metres
---@param y number
---@param z number
---@param radius number metres
---@param max? number the most to list (100)
---@return table a list of `{key=, class=, x=, y=, z=, taken=, interactable=}` (`interactable` false while `SetWorldItemInteractable` has the slot switched off)
function GetWorldItemsNear(x, y, z, radius, max) end

---Switches one loose item of the level off - it stays where it lies, and nobody can pick it up.
---
---With `false` the item of that one slot stays where the level placed it, on every player's screen, with no pickup prompt,
---no pickup and no physics: a display on a merchant's table, the props of a scene, a shrine's offerings. It is the slot's, never
---the item's class - the same bread on the next table can still be taken. `true` makes it usable again.
---
---Every player is told at once, and a player coming near later finds it switched off too. The switch is kept across server
---restarts with the rest of the level's record (`[containers] persist`), and it belongs to the slot whatever happens to its
---item: a taken item (`TakeWorldItem`) switched off comes back switched off (`ResetWorldItem`, the restock). The key is
---one `GetWorldItemsNear` lists; `false` and the reason for a key the level's tables export does not know (or without the
---export). Switching a slot to the state it is in already is no change and answers `true`.
---@param key string the item slot's key, as `GetWorldItemsNear` lists it
---@param interactable boolean `false` switches the item off, `true` back on
function SetWorldItemInteractable(key, interactable) end

---Whether a loose item of the level is switched on.
---
---`false` while `SetWorldItemInteractable` has the slot switched off, `true` for every other key.
---@param key string the item slot's key
---@return boolean
function IsWorldItemInteractable(key) end

---Empties a loose item slot by script.
---
---The item vanishes on every client and the restock clock runs from now. Only for a slot the tables export lists for the
---level; `false` for an unknown slot or one already empty. Hundreds at once are fine: the slots are empty on the server at
---once, and the players are told at a pace (`ResetWorldItems`).
---@param key string the item slot's level name
---@return boolean
function TakeWorldItem(key) end

---The world clock the restock timers run on.
---
---World seconds since this world's first start, running at `[world] time_ratio` per real second and kept across restarts
---with the rest of the level's objects in the server's own database. A world day is 86400.
---@return number
function GetWorldSeconds() end

---Where a door stands, from the tables export.
---
---Metres in the level's space, the door's place as the level file gives it (the same numbers the level
---lists show). `nil` for a key the export does not know, and for every door when the server runs without the tables export
---or with one older than the doors (re-run the exporter). A door of the map editor (`CreateMapDoor`, key `"KcdMp_map_" ..
---id`) answers with the map object's place, export or not. The nearest-object functions are built on it.
---@param key string the door's level name
function GetDoorPosition(key) end

---Every door of the level, touched or not.
---
---The keys of every door the tables export lists for the level - the ones `GetDoorPosition` answers for - where a mode
---finds the level's houses: a street to put someone in, a village to spread people over; then the map editor's doors
---(`CreateMapDoor`). Without the tables export (or with one older than the doors) only the map's. `GetDoors` lists only
---the doors anyone touched.
---@return table a list of door keys
function GetLevelDoors() end

---Where a container stands, from the tables export.
---@param key string the container's level name
function GetContainerPosition(key) end

---Where a loose item's slot stands, from the tables export.
---@param key string the item slot's level name
function GetWorldItemPosition(key) end

---The door nearest to a point, within a radius.
---
---"The door I stand at": the mode's command on the nearest door, a rule set by standing next to it, with no key in sight
---(`/objectinfo` shows the keys to an admin in the game). Every door the tables export lists for the level is considered,
---and every door placed with the map editor; `nil` when none is within the radius.
---@param x number the point, metres
---@param y number
---@param z number
---@param radius? number metres; `0` or none = no limit
function GetNearestDoor(x, y, z, radius) end

---The container nearest to a point, within a radius.
---@param x number the point, metres
---@param y number
---@param z number
---@param radius? number metres; `0` or none = no limit
function GetNearestContainer(x, y, z, radius) end

---The loose item slot nearest to a point, within a radius.
---@param x number the point, metres
---@param y number
---@param z number
---@param radius? number metres; `0` or none = no limit
function GetNearestWorldItem(x, y, z, radius) end

-- ======== Herbs and mushrooms ===================================================
-- The plants and mushrooms a player picks from the ground - chamomile, nettle, sage, boletus and the rest - are the **server's**:
-- a herb one player picks is gone on every screen, and it grows back for everyone at the same moment. The game's gathering takes
-- every plant of one kind within a small circle around the one picked (wider with the herbalism skill); the server keeps that
-- circle as a **picked spot** and tells the players near it. Their games take the same plants away and only the server's word
-- brings them back - after the kind's **regrow time** (the game's own hours at the server's clock speed - `GetHerbRegrowTime`;
-- a mode sets its own with `SetHerbRegrowTime`), or when the mode says so (`ResetHerb`, `ResetHerbs`). A spot grows back
-- out of sight, the way the game's own herbs do: once nobody stands within ten metres of it.
-- 
-- A mode needs nothing for the sync. It may judge every pick (`OnPlayerPickHerb`: refuse it, or give another amount of the
-- item), **switch herbs off** by kind and place (`SetHerbsEnabled` - the plants are gone and cannot be picked there), take
-- herbs away itself (`TakeHerbs`) and **plant its own** where it wants them (`CreateHerb`: the kind's plant with a "Pick"
-- prompt). A **kind** is named by its item - `"herb_chamomile"`, `"boletus"` - its class GUID, or `"*"` for every kind; the
-- kinds, what each gives and its regrow time are in the list of herbs and `GetHerbKinds`.
-- 
-- The sync rides with the level's loose items: it needs `[containers] world_items` (on by default - with it off every game keeps
-- its own herbs, as before), and `[containers] persist` keeps the picked spots across a restart. A player whose game is older
-- than the server's herbs keeps their own herbs, and what they pick is judged like any item their game makes.

---**Called by the server** - A player picked herbs or mushrooms - return `false` to refuse, or a number to give that many of the item.
---
---Called when a player's game picked herbs from the ground, after the server's own checks (the player is alive and within
---reach, the kind is not switched off there, nobody picked that spot already, and not quicker than the game's gathering can),
---and when a player picks a herb of the mode's (`CreateHerb`).
---
---Return `false` and the pick is refused: the plants grow back at once in the picker's world and the item the game gave them is
---taken back. Return a number and the player ends up with that many of the item instead of the game's amount (`0` gives
---nothing - the plants are still picked). Anything else accepts the pick as the game made it.
---
---`herb` is a table: `kind` (the item name, `"herb_chamomile"`), `class` (its class GUID), `x`, `y`, `z` (the middle of the
---circle, metres), `radius` (metres; `0` for a herb of the mode's), `count` (how many plants the game took), `amount` (what the
---game gives for them) and `key` (the picked spot's key, for `ResetHerb`).
---
---Return value: `false` refuses the pick; a number gives that many of the item; anything else accepts it
---@param pid number the player
---@param herb table `{kind, class, x, y, z, radius, count, amount, key}`
function OnPlayerPickHerb(pid, herb) end

---How long a kind of herb takes to grow back, in real seconds.
---
---`seconds` is real time on the server's clock: `0` = never on its own (only `ResetHerb` / `ResetHerbs` bring it back),
---`nil` or below `0` = the game's own time again (the kind's game hours at the server's clock speed, `[world] time_ratio`). The
---time counts from each pick: spots picked before the call keep the time they were given.
---@param kind string the item name, its class GUID, or `"*"` for every kind
---@param seconds number real seconds, up to a year; `0` never, `nil` the game's own
---@return true , or `false` and the reason
function SetHerbRegrowTime(kind, seconds) end

---A kind's regrow time in real seconds.
---@param kind string the item name, its class GUID, or `"*"` (the longest of them)
---@return number real seconds (`0` = never on its own), or `nil` for no such kind
function GetHerbRegrowTime(kind) end

---Every kind of herb and mushroom.
---@return table a list of `{kind, name, class, amount, hours, regrow}`: the item name, the English name, the class GUID, what a pick gives, the game's regrow time in game hours and the regrow time now in real seconds
function GetHerbKinds() end

---Switches a kind of herb off - or on again - on the whole level or within a circle.
---
---Off, the plants of that kind are gone from every player's world there and cannot be picked - a field kept bare, a forest
---without mushrooms. Without `x`, `y` and `radius` the whole level. A zone is a circle up to 5000 metres; switching the same
---kind off again at the same place changes the zone's radius.
---
---On again (`enabled` = `true`) switches back on every zone of that kind whose middle is within `radius` metres of `x`, `y` -
---without a place, every zone of the kind wherever it lies. The plants come back at once. Herbs a player picked are not
---affected: they still grow back on their own time.
---@param kind string the item name, its class GUID, or `"*"` for every kind
---@param enabled boolean `false` switches them off, `true` on again
---@param x number metres (optional)
---@param y number metres (optional)
---@param radius number metres (optional; `0` or none = the whole level)
---@return true , or `false` and the reason
function SetHerbsEnabled(kind, enabled, x, y, radius) end

---Where herbs are switched off.
---@return table a list of `{kind, x, y, radius}` (`radius` `0` = the whole level; `kind` `"*"` = every kind)
function GetHerbZones() end

---Takes away every herb of a kind within a circle, as a pick would - for its regrow time, a time of the mode's, or for good.
---
---The plants are gone from every player's world and come back like a picked spot - after the kind's regrow time, after
---`seconds`, or with `seconds` = `0` only when the mode resets it (`ResetHerb` with the key this returns). Nobody gets an
---item. The radius is `0.05` to `50` metres. Needs `[containers] world_items`.
---@param kind string the item name, its class GUID, or `"*"` for every kind
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@param seconds number real seconds until it grows back (optional; `nil` = the kind's regrow time, `0` = never on its own)
---@return string the spot's key, or `nil` and the reason
function TakeHerbs(kind, x, y, z, radius, seconds) end

---A picked spot grows back now, for everyone.
---
---Also a herb of the mode's (`CreateHerb`) that was picked stands again. At once, in view of the players around it.
---@param key string the spot's key (`OnPlayerPickHerb`'s `key`, `TakeHerbs`, `GetHerbsNear`)
---@return true , `false` when the server holds no picked spot of that key
function ResetHerb(key) end

---Every picked spot grows back now - or every one within a circle.
---@param x number metres (optional)
---@param y number metres (optional)
---@param z number metres (optional)
---@param radius number metres, above `0` when a place is given
---@return number how many spots grew back
function ResetHerbs(x, y, z, radius) end

---The picked spots and the mode's herbs within a circle, nearest first.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@param max number the most to list (optional, 100; up to 1000)
---@return table a list of `{key, kind, x, y, z, radius, picked, by, regrowIn, created}`: `picked` whether it is taken now, `by` the picker's name (empty for the mode's), `regrowIn` the real seconds until it grows back (`-1` never on its own, `0` when not picked), `created` whether it is a herb of the mode's
function GetHerbsNear(x, y, z, radius, max) end

---Plants a herb of the mode's - the kind's plant with a "Pick" prompt, wherever the mode wants it.
---
---The plant stands where the mode puts it, for every player in the virtual world `world` (`0` by default). The use
---key on it picks it: `OnPlayerPickHerb` is asked (its `radius` is `0`), the player gets the kind's item (or the mode's
---amount), and the plant is gone for everyone until the kind's regrow time runs out or `ResetHerb` brings it back. There is no
---gathering animation (play an emote from the callback if you want one). `RemoveHerb` takes it away for good. Up to 2000.
---Needs the meshes of the server's tables export.
---@param kind string the item name or its class GUID
---@param x number metres
---@param y number metres
---@param z number metres (on the ground)
---@param yaw number degrees (optional)
---@param world number the virtual world (optional)
---@return string the herb's key, or `nil` and the reason
function CreateHerb(kind, x, y, z, yaw, world) end

---Takes a herb of the mode's away for good - or lets go of a picked spot (it grows back at once).
---@param key string the herb's or the spot's key
---@return true , `false` for an unknown key
function RemoveHerb(key) end

-- ======== Sound files ===========================================================
-- Your own recordings played in the world through the game's own sound: a line an actor speaks (a voice you recorded or made
-- with a text-to-speech service), a song at a tavern, a bell at a place. Put the files in a `sounds/` folder next to your game
-- mode (`gamemodes/myrp/sounds/` for `gamemodes/myrp/myrp.lua`, or the folder `[client] sounds` names) and name each by its path
-- in that folder: `"herald_01.ogg"`, `"voices/elder_greeting.ogg"`.
-- 
-- - **The kinds:** `.ogg` (Vorbis), `.opus`, `.wav`, `.mp3` and `.flac`. A file may be up to `[client] sound_max_mb` (8 MB unless
--   the server owner sets it, at most 16 MB). For music and long lines Opus or Ogg gives the best sound for the size.
-- - **When players get them:** a file is sent to a player only when a sound of it reaches them, the first time it does - nobody
--   downloads a server's whole collection at the join. Their game keeps it, so the next time it starts at once. The first time,
--   the sound starts on their screen once the file has arrived, where the others are in it by then (a short line arrives in a
--   moment; a song of several megabytes takes a few seconds). `PreloadSound` sends a file ahead so it starts at once - a song
--   before the bard plays, the lines of a scene as a player walks in. With `[client] sounds_cdn` the players' games fetch the files
--   from the server owner's own web host instead of from the server.
-- - **How it sounds:** positional, from the actor's mouth or the place; in the place's reverb (a church echoes); muffled by the
--   walls between the sound and the listener, as players' voices are; on the game's master and **sound effects** volume (as the NPCs' own lines). With lip sync (the
--   default for an actor) the actor's mouth moves with the sound.
-- - **Who hears it:** every player within `range` metres who sees the actor. A player who comes into range while it plays hears
--   the rest of it from where it is. The server reads each file's length and tells you its end in `OnEntitySoundEnd`.

---**Called by the server** - A sound of PlayEntitySound or PlaySoundAt is over.
---
---`reason` says why: `"finished"` (it played to its end), `"stopped"` (`StopSound`, `StopEntitySounds`) or
---`"removed"` (its actor or entity was destroyed). A loop ends only when it is stopped. Chain a conversation of your own
---recordings here.
---@param id number the actor or entity it played at; `0` for a sound at a place
---@param sound number the sound's id, as PlayEntitySound returned it
---@param file string the file's path in the sounds folder
---@param reason string `"finished"`, `"stopped"` or `"removed"`
function OnEntitySoundEnd(id, sound, file, reason) end

---Plays one of your sound files at an actor, an animal or another entity, through the game's own sound.
---
---`file` is the sound's path in your sounds folder. The sound follows the entity as it moves - from an actor's mouth,
---which moves with it (`lipsync`). Up to 4 sounds may play at one entity, 256 on the whole server.
---
---`options` is a table, every field optional:
---
---| Field | Default | |
---|---|---|---|
---| `volume` | `1` | `0` to `2` |
---| `range` | `20` | metres it carries, `1` to `200` |
---| `loop` | `false` | it plays again from the start until `StopSound` |
---| `lipsync` | `true` | an actor's mouth moves with it (not an animal's, nor an entity's) |
---@param id number the actor, animal or entity
---@param file string the file's path in the sounds folder (`"line_01.ogg"`, `"voices/elder.ogg"`)
---@param options? table `{volume, range, loop, lipsync}`
---@return number the sound's id; `nil` and the reason when it cannot play (no such entity, no such file, not a sound file, a file over the size limit)
function PlayEntitySound(id, file, options) end

---Plays one of your sound files at a place, through the game's own sound.
---
---As `PlayEntitySound`, at a point with nothing to follow: a bell in a tower, music in a tavern, a crowd at a market.
---`options` takes `volume`, `range` and `loop` as PlayEntitySound does, and `world`, the virtual world (`0`).
---@param x number metres
---@param y number metres
---@param z number metres
---@param file string the file's path in the sounds folder
---@param options? table `{volume, range, loop, world}`
---@return number the sound's id; `nil` and the reason when it cannot play
function PlaySoundAt(x, y, z, file, options) end

---Sends one of your sound files ahead into a player's game, so a sound of it later starts at once.
---
---A file goes to a player only when a sound of it first reaches them, and the sound starts on their screen once it has
---arrived. Send a big file ahead - a song before the bard plays it, the lines of a scene as a player enters the place - and
---it starts at once. Nothing plays. Without `pid` the file goes to every player in the game; a player whose game has it
---already downloads nothing.
---@param file string the file's path in the sounds folder
---@param pid? number the player; leave it out for every player in the game
---@return true `nil` and the reason when the file cannot be played or the player is not in the game
function PreloadSound(file, pid) end

---Ends a sound now on every screen.
---
---`OnEntitySoundEnd` then runs with `"stopped"`.
---@param sound number the sound's id
---@return boolean `false` when it was not playing
function StopSound(sound) end

---Ends every sound playing at an entity.
---@param id number the actor, animal or entity
---@return number how many were playing
function StopEntitySounds(id) end

---Whether a sound still plays.
---@param sound number the sound's id
---@return boolean
function IsSoundPlaying(sound) end

---How long one of your sound files plays.
---
---Read from the file itself - no game needed. Use it to time what follows a line.
---@param file string the file's path in the sounds folder
---@return number seconds; `nil` and the reason when the file cannot be played
function GetSoundLength(file) end

-- ======== Accounts, admins, bans and the audit ==================================
-- The server keeps **no accounts**: a name is whoever typed it, and the server remembers nothing about a player between visits.
-- A mode that wants accounts builds them on its own database - a table of names and password hashes, a `/register`
-- and a `/login` of its own - with three helpers from here: `SetSecretCommand` (the clients mask the password as it is typed),
-- `HashPassword` and `VerifyPassword`. The shipped `freeroam.lua` is the worked example; the databases
-- guide walks through it. **Admins** are the mode's too: `SetPlayerAdmin` in `OnPlayerConnect` (or after the mode's own login)
-- unlocks the server's admin-only built-in commands and whatever the mode gates on it - from a list in the
-- script, a column in the mode's database, any rule the mode likes. **Bans** are the one thing about a person the server itself
-- keeps: a name or an address, in the server's own database, across restarts.
-- 
-- The **audit** (`[audit]`) compares what a player's game says with what the server knows happened, in two halves. The **item
-- check** holds what a player carries - the purse too - against the server's records: the spawn outfit, `GivePlayerItem`,
-- pickups, takes from containers, sales to a shop, the game's own making. An item nothing explains is removed from the player's
-- game - never a kick, never a violation - and the mode is asked first (`OnPlayerAuditViolation`; `OnPlayerNativeItem` for what
-- the game made itself). The **progression check** judges levels, XP, perk points and perks, the nourishment and the energy, and
-- what a player carries (`OnPlayerProgressViolation`, `GetPlayerProgressAudit`, `GetPlayerWeight`). Both start in `observe`,
-- which only logs and takes nothing away; `[audit] mode = "enforce"` acts (the
-- server configuration says what each does). A *violation* is a cheat the server can prove - a game that ignores an order,
-- forges a claim or goes silent - and `OnPlayerCheatDetected` hears it, with every hint, before `[audit] action` decides what
-- happens to the player.

---**Called by the server** - The item check found items the server cannot explain - return `false` to vouch for them.
---
---The player holds `amount` of an item class - what their game reports - where the server's records credit `allowed`: what it
---bound to the player (the spawn outfit, `GivePlayerItem`, a pickup, a take from a container, a shop purchase) plus the gives
---still on their way. The excess has stood for a second and a half and is about to be removed from their game, one exact item
---at a time. **A single unexplained item is removed, never a kick**: a player is kicked only for cheating proven beyond doubt,
---through `OnPlayerCheatDetected` and `[audit] action`. With `[audit] mode = "observe"` the call comes all the same and the
---removal is only logged. For the purse `class` is the game's money item and the amounts are its own count, tenths of a
---Groschen (`10` = one Groschen). The class may be one of a horse's saddlebags that the player's game holds, and the call does
---not say which. Return `false` to vouch: the records take the whole excess, in `observe` too, and nothing is removed. Anything
---else and the excess goes.
---
---**When it is asked.** Once the excess has stood its second and a half and is still there; never for an item whose pickup or
---take the server itself refused (`OnPlayerPickup`, `OnPlayerTakeWorldItem`) - that one goes at once, in every mode; and at
---most 8 times in a tick and 30 times a minute for one player, after which the removal goes ahead without asking, so answer from
---memory and never from a database query. What the game made itself is `OnPlayerNativeItem`'s, asked as the item arrives.
---Vouch only for what the mode handed out in a way the server does not see - an event's reward given by a client script - and
---never for a class in general: a vouched item is the player's from then on.
---
---Return value: `false` vouches for the items; anything else lets the excess be removed
---@param pid number the player
---@param class string the item class GUID (`GetItemName` names it)
---@param amount number how many the player holds (what their client reports)
---@param allowed number how many the server's records credit
---@param origins string where the unexplained items came from, comma-separated (empty when nothing is known): `native <maker>` - the game made it
itself (`native unmapped` is a maker the server cannot name, see `OnPlayerNativeItem` for the others), `unknown` - the count
went up with nothing of the game's own seen making it (an edited amount, or a way of the game's the server does not follow),
`foreign_inv` - moved in from an inventory the server does not follow, `outfit`, `pickup`, `level`, `container`, `ammo`,
`own drop`. A server older than 0.43 passes nothing here
function OnPlayerAuditViolation(pid, class, amount, allowed, origins) end

---**Called by the server** - The player's game made an item of its own - return `true` to adopt it, `false` to have it removed.
---
---In multiplayer the server gives every item the player carries, but the game still makes a few itself: a craft, a butchering, a
---loot, a die, a tool's work, the vial a drink leaves. The server has no record behind such an item; this callback is asked
---first, as the item arrives (in `observe` too - there the answer only changes what the log says). `kind` names the producer:
---
---- `craft` - alchemy, cooking, drying, preparing; `butcher` - an animal butchered; `loot` - an animal looted;
---- `tool` - what a lockpick, a blade or a shovel makes; `dice` - the dice game's own dice; `eat` - what a meal leaves, an empty
---  vial or a core; `wear` - the broken twin a destroyed weapon is swapped for (the server pairs it with the item that broke, so
---  this reaches the mode only when it cannot);
---- `script` - made by the game's own Lua, which a cheat tool's items arrive as too; `setitems` - the game's own dressing of a
---  spawn outfit (credited without asking inside the spawn's first seconds);
---- `unmapped` - made by a part of the game the server has no name for, which is where most unmodelled game code lands;
---  `foreign_inv` - moved in from an inventory that is not the player's;
---- `smith` - what the player forged at an anvil: an item one of the game's smithing recipes makes, arriving while the player's
---  smithing session is open (from the anvil's start until half an hour after its start or its last product), with that recipe's
---  materials gone from the player's bag in the session;
---- `herb` is named for completeness: herbs picked in the world arrive as a take from the level (`OnPlayerTakeWorldItem`).
---
---Return `true` to adopt the item (the records take it, as if the server had given it, whatever its class and number), `false`
---to have it removed, or nothing to leave it to the server's rule. The rule: an item the game made and no mode adopted is
---accepted when it is an ordinary item, no more than 100 at once, within a limit of value a minute - a bigger limit for a
---producer that really makes that kind of item (a craft makes food, herbs and alchemy, a butchering food and materials), a tight
---one for the rest, so a normal craft passes and a flood does not; it is refused for the guarded categories
---(`[audit] guarded_categories`: weapons, armour, ammunition, money) until a mode adopts them here; and everything made by a
---script of the game is refused while story quests are off. Items made by code outside the game are never asked about: they are
---a `foreign_call` hint and are never credited, so under `enforce` they are removed. **A `smith` item is accepted, a forged sword
---or a horseshoe too**, two pieces a minute at most - unless you return `false` (only the town's smiths may forge, say). The
---materials it was forged from are spent with it; an item made at the anvil while none of its recipes' materials left the bag is
---not the smith's (a line in the log says so) and is judged like any other. The anvil's hammer and tongs, which the game puts in
---the player's bag while they forge and takes back after, are the anvil's during the session too. What the recipes make and take
---comes from the game tables export; with an export made before it (the server's log says so at the start) a melee weapon or a
---horseshoe made at an anvil counts as forged and no materials are checked.
---
---Return value: `true` adopts the item, `false` has it removed, nothing (or `nil`) leaves it to the server's rule
---@param pid number the player
---@param kind string the producer - `craft`, `butcher`, `herb`, `loot`, `dice`, `tool`, `eat`, `wear`, `smith`, `script`, `setitems`, `unmapped` or `foreign_inv`
---@param class string the item class GUID (`GetItemName` names it)
---@param amount number how many were made
function OnPlayerNativeItem(pid, kind, class, amount) end

---**Called by the server** - A sign of cheating - return `false` to tolerate a proven one.
---
---Every detection of the audit and of the server's other measures goes through here. `proven` is `true` for what the server
---holds against the player's game beyond doubt - an order it ignored, a claim it can disprove, a game gone silent, a forged
---value written back again and again - and then the
---`[audit] action` (`log`, `kick` or `ban`) follows unless you return `false`. **A proven cheat acts in `observe` too.**
---Everything else is advisory: it can be wrong (a modded server's speeds, an overlay, a lag burst, a client the cheater
---controls) and is only counted and logged; **what it means is the mode's to decide** - kick, freeze or flag the player here
---through the API. The log says `anti-cheat: <kind> (proven|advisory): <detail>` and, for a proven one, what happened to the
---player (`, kick`, `, ban`, `, log only` or `, tolerated by the game mode`); a kick's reason is `cheating: ` and the kind with
---its underscores as spaces. For each kind the log holds the first five lines of a player's visit and then every 25th, with the
---running count. `count` is that running count - how many of this kind the player raised this visit, this one included.
---
---**How often you hear a kind**: the ones a moving player can raise with every step - `speed`, `blink`, `noclip`, `jump`,
---`fall`, `horse` - and the floods `ledger_flood`, `foreign_call` and `loot_flags` reach you five times a visit, then once every
---5 seconds per kind; `count` says how many came in between. The advisory kinds of the progression and weight checks are held
---back as said below. Every other kind, and every proven one, reaches you each time.
---
---**Proven**
---
---- the item check: `removal_ignored` - an exact order to take an item out, sent three times, and the item still there after
---  about a minute and a half; `forged_claim` - the game's reports do not count up, or an item is stamped with an order the
---  server never made, three times within a minute; `ledger_silent` - no report of the bag for two minutes, or none within twenty
---  seconds of the spawn's strip; `memory_write_repeat` - the same item's count written up again after the server took it away,
---  three times within half a minute;
---- the progression check: `progress_write_repeat` - the same forged XP, level or perk points written back after the server put
---  them back, three times within ten minutes; each time the forged rise must be at least 25 XP, or 2 or more perk points or a
---  perk (only under `enforce`, only for a rule that acts, never on a server with story quests on); `vitals_write_repeat` - the
---  same for a frozen nourishment or energy (this version cannot raise it: the rules it needs are not measured yet).
---
---**Advisory**
---
---- movement and combat: `speed` (a way of moving held over its cap, beyond the allowance), `blink` (a step of more than two
---  metres at a pace over the cap - a teleport - four within two minutes), `noclip` (six steps through a wall or out of the
---  terrain's window within a minute), `jump`, `fall` (a landing from four metres or more with no damage from the player's game),
---  `horse` (a horse galloping on stamina it has not got, or a loose horse moving faster than a rider could make it), `never_hit`
---  (a player whose server actors never seem to hit), `void_ratio` (a victim whose guard voids almost every blow), `contact_ratio`
---  (an attacker whose blows on players mostly land with the victim's game showing no touch - for tuning, never acted on). `[validation]
---  strict = false`, the default, only reports `jump`, `fall`, `horse` and the per-gait part of `speed` (a way of moving held
---  over its own cap); `true` also pulls the player back. `blink`, the steps the `max_speed` caps refuse, and `noclip` are
---  reported whatever `strict` says: the server's step checks act on their own (a wall check pulls the player back with
---  `[validation] no_clip`);
---- what the player's own game signals about itself - hints, since a cheat that controls the game can silence or fake them:
---  `code` (the game's code patched in memory), `code_guarded` (a patch inside a function the progression and nourishment checks
---  rely on), `integrity` (one of the multiplayer client's own patches overwritten), `timescale` (the game's clock running
---  faster or slower than the real one, or the game's speed changed from outside the game), `clock` (the game's calendar
---  drifting from the server's), `state` (health or stamina written behind the game's back), `save_reenabled` (saving switched
---  back on), `inventory_overflow` (a bag with more items than the game's client can read), `foreign_call` (an item made by code
---  outside the game);
---- the item check: `ledger_desync` (the player's list of items and the server's records disagree; the server asks for the
---  whole list again, up to three times), `ledger_flood` (more than twenty reports about items a second, or an impossibly long
---  one), `ledger_unavailable` (the game says its item reporting cannot run), `removal_refused` (the game refused an order three
---  times for an item it does not mark undeletable), `horse_desync` (a horse's saddlebags that do not match its record after two
---  fills), `level_amount` (more taken from a level item than the level's data holds), `loot_flags` (a bag with more items the
---  game refuses to delete - quest items - than a character can hold, or money or a weapon marked that way, which a body
---  search would otherwise spare), `wear_frozen` (25 blows taken in armour that can still wear, and the player's game wore
---  none of it - an item that never loses its condition; `SetItemWear` at 0 for armour takes the check away);
---- the progression check (`OnPlayerProgressViolation`): `progress` (a rise of XP, a level, perk points or a perk that nothing
---  explains), `progress_ack` (the player's game does not confirm the orders the server sends it), `progress_gate` (the player's
---  game says its own XP counting is not running, so the awards it makes cannot be seen), `vitals` (a nourishment or energy held
---  over the game's maximum, or a maximum the player's game reports that is not the game's), `vitals_rewrite` (written back to
---  its maximum and written up again), `weight` for a carry capacity the player's game reports above what the strength, perks,
---  potions and drinks allow (`GetPlayerWeight` judges by the server's own figure). The other `weight` hints (sprinting or
---  mounting a horse while carrying more than the game allows, a horse's saddlebags holding more than the game lets them; an
---  overloaded player's jump is never judged, the game allows it) and the hints about a nourishment or energy that falls too
---  slowly or rises with no meal wait for their measurements: they are counted and logged and not told to the mode yet.
---
---**The advisory kinds of the progression and weight checks, and `code_guarded`, are evidence for a rule of the mode's own,
---never a reason to kick by themselves**: a lag burst, an overlay or a mod can raise any of them. The server counts every one,
---but tells the mode (and its log) of one at most every 10 seconds and 30 times an hour per player and kind. A proven kind is
---never held back.
---
---Return value: `false` tolerates the `[audit] action` for this event; anything else lets it happen (an advisory one never acts)
---@param pid number the player
---@param kind string what was found - `speed`, `blink`, `noclip`, `jump`, `fall`, `horse`, `never_hit`, `void_ratio`, `contact_ratio`, `code`, `integrity`, `timescale`, `state`, `removal_ignored`, `progress_write_repeat`, ...
---@param proven boolean `true` = held against the client beyond doubt (the `[audit] action` follows); `false` = a signal that can be wrong
---@param detail string a line for the log
---@param count number how many of this kind the player raised this visit, this one included
function OnPlayerCheatDetected(pid, kind, proven, detail, count) end

---Whether the player is an admin.
---
---A player the mode promoted with `SetPlayerAdmin` this session. It unlocks the server's admin-only built-in commands
---(`/give`, `/tp`, `/kick`, `/objectinfo` ...) and whatever the mode gates on it.
---@param pid number the player
---@return boolean
function IsPlayerAdmin(pid) end

---Makes the player an admin for the session - or takes it back.
---
---Admins are the mode's to decide: the server keeps no list and no accounts. Promote in `OnPlayerConnect` from a list in the
---script or a row of the mode's database, or after the mode's own login. The flag lasts until the disconnect or a reload
---(`OnPlayerConnect` runs again after a reload, so a mode that promotes there keeps its admins).
---@param pid number the player
---@param admin boolean `true` promotes, `false` demotes (`true` without)
---@return boolean `false` when not connected
function SetPlayerAdmin(pid, admin) end

---Declares a chat command secret - the clients mask its argument as it is typed.
---
---For a mode's own `/login <password>` and `/register <password>`: from the call on, a player typing that command sees the
---argument as asterisks on their chat line, and the Up arrow never recalls the line. Declare at init; the list reaches
---every client and a reload empties it. The server never echoes or logs a command's argument itself - what the mode's own
---`Log` lines carry is the mode's business.
---@param name string the command's name, with or without the slash (case-insensitive)
---@param secret? boolean `false` shows it again (`true` without)
function SetSecretCommand(name, secret) end

---Hashes a password for the mode's own accounts - one text to store as it is.
---
---PBKDF2-SHA256 with a random salt and 20 000 rounds, everything in one text (`pbkdf2$...`) that `VerifyPassword` checks
---later. Store that text in the mode's database; never the password. The hash costs a few milliseconds on the server's
---thread - a registration's worth, not something to run every tick.
---@param password string the password as the player typed it
---@return string the hash text
function HashPassword(password) end

---Whether a password made a hash text from HashPassword.
---@param password string the password as the player typed it
---@param hash string what `HashPassword` returned at the registration
---@return boolean `false` for a wrong password, an empty or a malformed hash
function VerifyPassword(password, hash) end

---Kicks the player and bans their name and address.
---
---A join attempt under the name or from the address is refused with the reason until the ban runs out; `seconds` `0` or none =
---for good. Kept in the server's own database across restarts. A name ban is only as strong as the name (nobody proves a
---name to the server); the address ban is the one that holds. Like a `Kick`, it is announced to nobody else - a mode that
---wants it known says it (`OnPlayerDisconnect` gets `"kicked: banned: <reason>"`).
---@param pid number the player
---@param reason string shown to the player now and at every refused join
---@param seconds? number how long; `0` or none = for good
---@return boolean `false` when not connected
function Ban(pid, reason, seconds) end

---Bans a name; whoever is on under it is kicked.
---@param name string the player name (case-insensitive)
---@param reason string the reason
---@param seconds? number how long; `0` or none = for good
function BanName(name, reason, seconds) end

---Bans an address; whoever is on from it is kicked.
---@param address string `"a.b.c.d"`
---@param reason string the reason
---@param seconds? number how long; `0` or none = for good
function BanAddress(address, reason, seconds) end

---Lifts every ban on a name or an address.
---@param nameOrAddress string a name or an address
---@return boolean `true` when there was one
function Unban(nameOrAddress) end

---Whether a name or an address is banned right now, and why.
---@param nameOrAddress string a name or an address
---@return string the reason, e.g. `"banned: speed hacking (9,000 min left)"`; `nil` when not banned
function IsBanned(nameOrAddress) end

---How many times the item check took unexplained items out of the player's game this session.
---
---One count for each removal the item check ordered because nothing explained the items - whatever the number of items in it -
---since the player joined, plus the removals for a pickup or a take the server itself refused. **It is not a count of
---violations**: a removal is the check working, and an honest player whose game and the server disagree for a moment gets one,
---so never ban or kick on it. Under `[audit] mode = "observe"` it counts only the removals that happen in every mode (the items of
---a refused pickup or take); what observe would have removed is in the log. A cheat the server can prove is
---`OnPlayerCheatDetected`'s, not this count's. `0` for a player who is not there.
---@param pid number the player
---@return number
function GetPlayerAuditViolations(pid) end

-- ======== Gates =================================================================
-- The level's **gates** - the animated defensive pieces, a portcullis that drops and a drawbridge that lifts - belong to the
-- server. The game gives players no hand on them (its own story moves them through cutscenes), so nothing happens to a gate
-- unless a mode or an admin's `/gate` asks for it; every client then plays the motion from the server's clock, a newcomer
-- sees the gate wherever its cycle stands, and a gate turned round mid-way carries on from where it is rather than snapping
-- to an end. A gate has a **cycle**: `closed`, `opening`, `open`, `closing`. **Open always means passable** - a portcullis
-- raised, a drawbridge lowered - and every gate starts a server run that way; a change survives a restart with the doors
-- (`world.json`). The **key** is the entity's level name. The retail levels have seven gates. On
-- `kutnohorsko`: the Suchdol fortress portcullis (`suchdol_fortres_gate_bars3`, a full open takes about 12 s, a close about
-- 5 s), the Malesov drawbridge (`malesov_drawbridge1`, about 8 s either way - the game ships one clip for it, so lowering
-- runs the lifting backwards), the Malesov courtyard gate (`malesov_courtyard_gate`, the wooden double gate barred by a
-- latch), the gate of Raborsch fortress (`raborsch_gate`) and the gate of Ruthard Palace in Kuttenberg
-- (`ruthard_palace_gate`). On `trosecko`: the door in Trosky castle's south gate (`trosky_south_gate`) and the gate of
-- Nebakov fortress (`nebakov_gate`). The last five have no animation: in the story the
-- game swaps their shut and open halves as the campaign goes, so here they are at the other end **at once** (no `opening` /
-- `closing`); their halves are level layers (`SetLevelLayer`). The story starts them shut, but a server starts them
-- **open** like the other two, so a mode that never names them needs nothing for its players to walk through. `klaster` has
-- none.
-- 
-- A mode that wants them otherwise drives them like the others. On a `trosecko` server, Trosky's south gate shut from the
-- first start, an admin's `/castlegate` to open it or shut it again, and everyone told when it moves:
-- 
-- ```lua
-- function OnGameModeInit()
--   -- the gate's end is kept across a restart: once shut, this is refused with "is already closed"
--   SetGateState("trosky_south_gate", false)
-- end
-- 
-- function OnPlayerCommandText(pid, cmd, args)
--   if cmd == "castlegate" then
--     if not IsPlayerAdmin(pid) then
--       SendClientMessage(pid, COLOR_RED, "Only the castle's admins move its gate.")
--       return true
--     end
--     local ok, opening, reason = ToggleGate("trosky_south_gate")
--     if not ok then SendClientMessage(pid, COLOR_RED, "The castle gate " .. reason .. ".") end
--     return true
--   end
-- end
-- 
-- function OnGateChange(key, cycle, pid)
--   -- a gate with no motion fires once, "open" or "closed", the moment it is switched
--   if key == "trosky_south_gate" then
--     SendClientMessageToAll(COLOR_YELLOW, cycle == "open" and "The gate of Trosky stands open." or "The gate of Trosky is shut.")
--   end
-- end
-- ```
-- 
-- The same lines with another key drive the others: `nebakov_gate` on `trosecko`, `malesov_courtyard_gate`, `raborsch_gate` or
-- `ruthard_palace_gate` on `kutnohorsko`.

---**Called by the server** - A gate's cycle changed - it started moving, or came to rest.
---
---`cycle` is `"opening"` or `"closing"` when a cycle starts (from `SetGateState`, `ToggleGate` or an admin's `/gate`) and
---`"open"` or `"closed"` when the motion ran its length. `pid` is the admin whose `/gate` started it, `-1` for the mode or
---the server (a settle is always `-1`). A gate of the kind `"gate"` has no motion: it fires once, `"open"` or
---`"closed"`, with the `pid` of whoever switched it.
---@param key string the gate's level name
---@param cycle string `"opening"`, `"closing"`, `"open"` or `"closed"`
---@param pid number the admin whose /gate did it, -1 for the mode or the server
function OnGateChange(key, cycle, pid) end

---Every gate of the level.
---
---The keys of the level's gates, whatever their state - three on `kutnohorsko`, one on `trosecko`, none on `klaster`.
---@return table a list of gate keys
function GetGates() end

---What the server knows of a gate - its kind, cycle, openness and place.
---
---`kind` is `"portcullis"`, `"drawbridge"` or `"gate"` (the five made of level layers: the Malesov courtyard gate, Raborsch's,
---Ruthard Palace's, Trosky's south gate, Nebakov's); `cycle` is `"closed"`, `"opening"`, `"open"`
---or `"closing"`; `openness` walks from 0 (closed) to 1 (open) while a cycle runs; `x`, `y`, `z` is where the gate stands
---(metres); `openSeconds` and `closeSeconds` are how long a full cycle takes each way (0 = the piece has no clip that way
---and a cycle is refused; both 0 for a `"gate"`, which is at the other end at once).
---@param key string the gate's level name
---@return table `{kind, cycle, openness, x, y, z, openSeconds, closeSeconds}`, or `nil` for a key that is no gate
function GetGateInfo(key) end

---Starts a gate towards open (passable) or closed.
---
---A gate already at that end, or heading there, is refused (`"is already open"`, `"is already closing"` ...); a gate moving
---the other way turns round from where it is. The motion plays on every client from the server's clock, and
---`OnGateChange` fires now (`"opening"` / `"closing"`) and when it comes to rest. A gate of the kind `"gate"` is there at
---once: the seconds are 0 and `OnGateChange` fires `"open"` / `"closed"` straight away.
---@param key string the gate's level name
---@param open boolean `true` towards open (a portcullis raised, a drawbridge lowered), `false` towards closed
function SetGateState(key, open) end

---Sends a gate the other way - from the end it rests at, or back from the way it is moving.
---
---Heads away from whichever end the gate is at, reversing one already moving from where it has got to. What `/gate` does
---with no argument.
---@param key string the gate's level name
function ToggleGate(key) end

---The gate nearest a point, within a radius.
---
---A gate is a big thing: the radius is tens of metres, not the couple a door needs (60 by default, the same as `/gate`).
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius? number metres (default 60)
---@return string the gate's key, or `nil` when none lies within the radius
function GetNearestGate(x, y, z, radius) end

-- ======== Level layers ==========================================================
-- The retail levels are full of **story layers**: parts of the level the single-player story shows and hides as it goes - a
-- gate shut or open, a wall whole or broken, a camp that appears for a chapter. A mode switches any of them on or off for
-- every player at once, the scenery and whatever stands in it together. The server remembers the layers it switched and
-- gives them to everyone who joins later; a layer it never touched stands as the level has it. A switch lasts for the run:
-- after a restart every layer is back as the level has it, so switch yours again when the mode starts
-- (`OnGameModeInit`). The gates made of layers - the Malesov courtyard gate, the gates of Raborsch and Ruthard Palace, the door
-- in Trosky's south gate and the gate of Nebakov - are driven through `SetGateState`, which remembers its end across restarts.
-- 
-- A **name** is the layer's full name as the level lists it, a GUID and all (`gate_open_a12b1f05-20f2-4d96-825c-57aea7eec798`);
-- every level's list is its own `leveldata.xml` inside the level's `level.pak` in the game folder. A name the level does not
-- have changes nothing - the player's game writes a line about it in its log. An admin tries a name in the game with
-- `/layer <name> on|off`.
-- 
-- The story's doors and gates that open as the campaign goes are such pairs: a shut layer and an open one at the same spot.
-- Show one and hide the other. The five gates above are already `SetGateState`'s and start a server open, whatever the
-- last column says - leave their layers to it, or the gate's end of record no longer matches what the players see; the
-- rest are a mode's to switch:
-- 
-- | Level | Where (x, y, z) | Shut layer | Open layer | At the story's start |
-- |---|---|---|---|---|
-- | kutnohorsko | 492, 397, 110 - the Malesov courtyard gate | `gate_closed_7521eeb3-a073-4ed0-a6b0-c4f28662ce64` | `gate_open_a12b1f05-20f2-4d96-825c-57aea7eec798` | shut |
-- | kutnohorsko | 625, 939, 97 | `_gateClosed_333eeddb-75c8-46ba-b198-a34b782af916` | `_gateOpened_6a4f3cb1-4ec5-4fab-ae0d-b2668bae693b` | open |
-- | kutnohorsko | 1424, 3856, 118 - the gate of Raborsch | `_enviro_8c959192-3590-486e-9ba3-7710220b81f9` and its barrier `gateBarrier_42dacb18-e0a1-4d4a-af1d-0d0c3a740a8d` | `_enviro_704db1e3-9f9d-485a-9903-d750465211c5` | shut |
-- | kutnohorsko | 1572, 2742, 198 | `ammoStandingDoorsClosed_3f7e6a2e-52b6-42eb-af72-0be68b24a30c` | `ammoStandingDoorsOpened_d5ae0f36-333b-48c8-89c9-a521bc8adf42` | shut |
-- | kutnohorsko | 3004, 681, 52 - the gate of Ruthard Palace (Kuttenberg) | `_enviro_b47eca21-382f-4139-b6f0-035f6b00e645` | `_enviro_c016c439-3032-4d4e-aced-c21f4e0eb777` | shut |
-- | kutnohorsko | 3160, 705, 59 | `closed_7e695498-0e5b-44d8-a709-d5b9db956b48` | `open_e12f7609-72e9-4986-9a60-7fb2f70f00bc` | shut |
-- | kutnohorsko | 3273, 711, 49 | `series_M33_closed_03a2dccf-5915-4b8a-806a-c075adf17d49` | `series_M33_open_7312e5b6-d00a-4a9a-9158-25bddcf88fb5` | open |
-- | trosecko | 2522, 2593, 178 - the door in Trosky's south gate | `closed_58e73ca0-b151-4782-8256-c27cff2faafd` | `open_f84fd4ff-472b-4fa8-b321-3453e8e46480` | shut |
-- | trosecko | 2435, 2650, 200 - Trosky | `closed_382af151-34ff-4593-b7a3-47b8f86e9601` | `open_d2670ef8-8b5f-4888-9619-71c6e59220f5` | open |
-- | trosecko | 2402, 2606, 208 - Trosky | `closed_a7e0becc-3434-48e0-a50c-4d45766b7216` | `open_35b343c5-06b9-411a-a469-43acbd2d7207` | open |
-- | trosecko | 2327, 2067, 111 | `closed_20789307-18df-4f59-b9d9-2482b5d7d8de` | `openworld_afe1facd-5750-4825-9cbb-09879bbc5f19` | open |
-- | trosecko | 1884, 1208, 49 - the gate of Nebakov | `_enviro_b47cb32f-a357-454f-9d82-f14a5304db9e` | `_enviro_e42466fa-a77d-4eda-bc30-3054d72409e1` | shut |
-- | trosecko | 1631, 1571, 78 - Semine | `closedGate_e7fb589e-a824-45d9-9a28-081f9c682f70` | `openGate_d141e039-f6c8-4d65-aabb-78f7d8876736` | open |
-- | klaster | 1290, 1050, 26 | `closed_8125ceb2-6277-41b8-93a2-82a31e8258d8` | `opened_f96643f2-c3fe-4e7a-be82-f2d019c1d490` | open |
-- 
-- The story's quests stay asleep unless a mode wakes them (`SetStoryQuests`), and every player's game still sets the
-- level's story layers the way the story's start leaves them - the switches here start from there. Switch layers with care:
-- some bring the story's own people or objects with them, and a layer that belongs to a cutscene can put things where
-- nothing makes sense outside it. Try a layer on a test server first.
-- 
-- **Finding a layer.** Stand at the wall, fence or heap you are after and type `/layer near [radius]` (10 m by default): it lists the
-- layers with a solid piece around you, the nearest first; a mode asks the same with `GetLevelLayersNear`. Both need the game's
-- tables exported with this version or later (they carry where each layer's pieces stand). Then try the name with `/layer <name> off`.
-- When a layer is switched off, the server's own collision leaves its pieces out as well, so shots, the ground and line of sight no
-- longer stop at a fence the players walk through.
-- 
-- Some stretches of wall or fence are a layer of their own and can simply be taken away - Suchdol's wooden fence around its moat, for
-- one, which every player's game puts up at the story's start:
-- 
-- | Level | Where (x, y) | Layer |
-- |---|---|---|
-- | kutnohorsko | Suchdol's fence, north of the moat (752-781, 3390), about 30 m | `_enviro_42bc6bcf-ee00-462b-9e13-feb67caf65f7` |
-- | kutnohorsko | Suchdol's fence, west side (717, 3328-3371), about 45 m | `_enviro_85efbddf-dbac-4b30-8175-593702607b9d` |
-- | kutnohorsko | Suchdol's fence, east side (784, 3344-3354), about 10 m | `_enviro_63144b81-9459-4649-95b2-7c7086e18b46` |
-- 
-- A siege that breaks a stretch down after a few hits counts the shots in `OnSiegeImpact` - a whole stretch goes at once:
-- 
-- ```lua
-- local NORTH_FENCE = {layer = "_enviro_42bc6bcf-ee00-462b-9e13-feb67caf65f7", x0 = 750, x1 = 783, y0 = 3387, y1 = 3393, hits = 0}
-- 
-- function OnSiegeImpact(id, x, y, z, shooter, shot, what, target)
--   local f = NORTH_FENCE
--   if x >= f.x0 and x <= f.x1 and y >= f.y0 and y <= f.y1 then
--     f.hits = f.hits + 1
--     if f.hits == 3 then
--       SetLevelLayer(f.layer, false)   -- the fence comes down for everyone
--       SendClientMessageToAll(COLOR_YELLOW, "The north fence of Suchdol is down!")
--     end
--   end
-- end
-- ```
-- 
-- The levels also fence players off with **invisible barriers**: walls no one sees that stop a player at deep water ("you cannot
-- swim"), at the edge of the map and along some story paths. A mode lifts them in a circle of its choosing with
-- `SetLevelBarriers` - so a siege's attackers can wade Suchdol's moat to their ladders - and puts them back the same way. A
-- barrier piece that reaches into the circle is lifted whole, so keep the circle small near the map's edge. Like the layers, the
-- areas last for the run.

---Switches one of the level's story layers on or off for every player.
---
---The layer changes on every client at once and on the screen of everyone who joins later. Refused for a name no layer
---could have (layer names are letters, digits, `_` and `-`, 96 characters at most) and for a layer this server already
---switched that way. A name the level does not have is accepted but changes nothing. Not kept across a restart.
---@param name string the layer's full name, with its GUID
---@param on boolean `true` shows the layer, `false` hides it
function SetLevelLayer(name, on) end

---A layer as this server switched it.
---
---`true` or `false` for a layer the server switched; `nil` for one it never touched - it stands as the level has it, which
---the server does not know.
---@param name string the layer's full name, with its GUID
---@return boolean on or off; `nil` when never switched
function GetLevelLayer(name) end

---Every layer this server has switched.
---
---A table by layer name, `true` for the ones switched on and `false` for the ones switched off - the layers a gate made of
---layers switched among them.
---@return table `{[name] = on, ...}`
function GetLevelLayers() end

---The level's story layers with a solid piece near a point.
---
---Every layer with a solid piece (a wall, a fence, a door, a heap) within `radius` of the point, the nearest first - how to find
---the layer of something a mode wants gone or back; admins ask the same with `/layer near [radius]`. Needs the game's tables
---exported with this version or later; with an older export the list is empty. The level's few huge ground layers are not listed.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres (10 when not given)
---@return table `{{name =, near =, pieces =, distance =, on =}, ...}`: the layer's full name, how many of its pieces lie within the radius, how many it has, the nearest one's distance, and `true` / `false` as this server switched it (`nil` when never switched)
function GetLevelLayersNear(x, y, z, radius) end

---Lifts or puts back the level's invisible barriers in a circle, for every player.
---
---`on = false` lifts every invisible barrier that reaches into the circle - a player then walks or wades where the level
---stopped them; `on = true` puts them back. The change reaches every player at once and everyone who joins later.
---
---Lifting again at a place already lifted (its middle within 1 m) changes that area's radius instead of adding a second
---one. Putting back takes away every lifted area whose middle lies within `radius` of the point (at least 1 m), so a large
---radius puts back every area at once. At most 64 areas; not kept across a restart - lift them again in
---`OnGameModeInit`. Scenery, water and everything else stay as they are: only the invisible walls go.
---@param x number the circle's middle on the map, metres
---@param y number metres
---@param radius number metres, 0.1 to 500 when lifting; when putting back, how far from the point a lifted area's middle may be
---@param on boolean `false` lifts the barriers, `true` puts them back
function SetLevelBarriers(x, y, radius, on) end

---The areas where the level's invisible barriers are lifted.
---
---One entry per lifted area, in the order they were lifted.
---@return table `{{x =, y =, radius =}, ...}`
function GetLevelBarriers() end

-- ======== The map's areas =======================================================
-- An **area** is a named piece of the level - a box, a cylinder, a sphere or a polygon standing on the ground - that the server checks
-- every player against ten times a second. A mode hears `OnPlayerEnterArea` and `OnPlayerLeaveArea` by the area's name and builds
-- its rules on them: a town where nobody fights, a market that takes a tax, a race's finish line, a plot that belongs to a player. Areas
-- live in the server's map like its placed objects: written, there after a restart and after a
-- mode reload (a mode's own with `persist = false` last for its run only). An admin draws one with `/map area` in the game.
-- 
-- An area may carry the mode's own values (`SetAreaProperty`: an owner, a tax, `pvp = false`), kept with it. Its **label** is shown to
-- every player who comes in when it is public ("Kuttenberg market"). An area on a map layer that is switched off holds nobody
-- (`SetMapLayer`). Places are in metres; a box is at most 2 km across and 500 m high.
-- 
-- An area can also be a **trespass zone** of the game's own kind: inside it the game shows its trespass icon - blue for someone's
-- home, red where nobody may go - and the mode hears `OnPlayerTrespassChange` (`SetAreaTrespass`, `SetPlayerAreaTrespass` for
-- one player, `SetPlayerTrespass` anywhere). The level's own houses, keeps and camps carry the game's trespass too; a mode switches
-- them off (`SetLevelTrespass`) or makes one public for its owner. Nobody reacts on their own in multiplayer - a fine, a warning or a
-- guard's call are the mode's. And an area can be a **roof**: `SetAreaRain` caps the rain a player inside sees (`0` = dry), for the
-- buildings put up with the map editor.

---**Called by the server** - A player came into one of the map's areas.
---
---Checked ten times a second against where the player stands. A player standing in several areas gets one call for each. After a
---mode reload the new mode hears every player's areas as entered again.
---@param pid number the player
---@param area string the area's name
function OnPlayerEnterArea(pid, area) end

---**Called by the server** - A player left one of the map's areas.
---
---They walked out, were moved, or the area was changed, taken away or its layer switched off. Not when they leave the server
---(`OnPlayerDisconnect`).
---@param pid number the player
---@param area string the area's name
function OnPlayerLeaveArea(pid, area) end

---**Called by the server** - The trespass level a player's game shows changed.
---
---They walked into a house or a keep of the level (its own trespass areas, as their game reports them), into or out of an area with a
---trespass level (`SetAreaTrespass`), or the mode changed one of the rules. `level` is what they see now: `"personal"` shows the
---game's blue icon (someone's home), `"prohibited"` the red one (no entry), `"public"` none; `"semipublic"` and `"semipersonal"` are
---trespass the game shows no icon for. Nobody reacts on their own in multiplayer - what follows is the mode's. Not when they leave the
---server.
---@param pid number the player
---@param level string the level now: `"public"`, `"semipublic"`, `"semipersonal"`, `"personal"` or `"prohibited"`
---@param was string the level before
---@param source string what set it: `"level"` (the level's own areas), `"area"` (one of the map's areas) or `"player"` (`SetPlayerTrespass`)
---@param area string|nil the map's area that set it (with `"area"`)
function OnPlayerTrespassChange(pid, level, was, source, area) end

---Makes one of the map's areas.
---
---`shape` and the numbers in `opts`:
---
---- `"box"` - `x1`, `y1`, `z1`, `x2`, `y2`, `z2`: two opposite corners;
---- `"cylinder"` - `x`, `y`, `radius`, `zmin`, `zmax`;
---- `"sphere"` - `x`, `y`, `z`, `radius`;
---- `"polygon"` - `points` (`{{x, y}, ...}`, 3 to 64, the outline without crossing itself), `zmin`, `zmax`.
---
---Any of them takes `label` (what players see), `public` (`true` shows the label to whoever comes in), `color` (`0xRRGGBB`, the
---editor's outline), `nav` (what the server's actors make of it: `"auto"` nothing, `"block"` they never walk into it, `"walkable"` a
---floor at its bottom they walk on), `trespass` (the game's trespass level inside - `SetAreaTrespass`), `rain` (the most rain inside,
---`0` .. `1` - `SetAreaRain`), `layer` (`"base"`) and `persist` (`true`). A name is used once - letters, digits, `_ . -` and
---spaces, at most 64.
---@param name string the area's name
---@param shape string `"box"`, `"cylinder"`, `"sphere"` or `"polygon"`
---@param opts table the shape's numbers and the options above
---@return number the area's id; `nil` and the reason when the server has no map, the name is taken or a number is out of its bounds
function CreateArea(name, shape, opts) end

---Gives an area a new shape, label, colour or layer.
---
---The same `shape` and `opts` as `CreateArea`, whole; `opts.name` renames it. The area keeps its id and its values. Players who
---are no longer in it leave it at the next check, those it now holds enter.
---@param name string the area
---@param shape string its shape
---@param opts table the shape's numbers and the options
---@return boolean `true`; `false` and the reason
function SetArea(name, shape, opts) end

---Takes an area off the map; whoever was in it leaves it.
---@param name string the area
---@return boolean `true`; `false` and the reason
function DeleteArea(name) end

---An area as it stands.
---@param name string the area
---@return table `{id, name, shape, ...the shape's numbers, label, public, color, nav, trespass, rain, layer, persist, by, revision, props}` (`props`: the mode's values on it; `by`: the admin who last changed it, `""` for the mode; `trespass` and `rain` are `nil` when the area sets none); `nil` when there is none
function GetArea(name) end

---Every area of the map, by name.
---@return table a list of `GetArea`'s tables
function GetAreas() end

---The names of the areas holding a point.
---@param x number metres
---@param y number metres
---@param z number metres
---@return table the names, sorted (the areas whose layer is on)
function GetAreasAt(x, y, z) end

---Whether a player is in an area now.
---
---As of the last check, at most a tenth of a second ago.
---@param pid number the player
---@param name string the area
---@return boolean
function IsPlayerInArea(pid, name) end

---The areas a player is in now.
---@param pid number the player
---@return table the names, sorted
function GetPlayerAreas(pid) end

---Keeps one of the mode's values on an area.
---
---A string, a number or a boolean; `nil` takes the key away. The values are kept with the area in the map - after a restart too
---(an area with `persist = false` lasts for the run). At most 32 keys an area.
---@param name string the area
---@param key string the value's name (1 .. 64 characters)
---@param value string|number|boolean|nil the value
---@return boolean `true`; `false` and the reason
function SetAreaProperty(name, key, value) end

---One of the mode's values on an area.
---@param name string the area
---@param key string the value's name
---@return string|number|boolean the value; `nil` when the area has none of that name
function GetAreaProperty(name, key) end

---Makes an area one of the game's trespass zones.
---
---Inside it a player's game shows its trespass icon and the mode hears `OnPlayerTrespassChange`. The levels by the game's own names:
---`"personal"` - the blue icon (a home, a private room); `"prohibited"` - the red icon (a castle's keep, a guarded camp);
---`"semipublic"` and `"semipersonal"` - trespass with no icon; `"public"` - no trespass, and the level's own trespass there taken
---away (a house of the level a player owns). `nil` - the area says nothing and the level's own areas decide. Where areas overlap,
---the highest level counts. Kept in the map with the area (the editor's area panel sets it too).
---@param name string the area
---@param level string|nil the trespass level, or `nil`
---@return boolean `true`; `false` and the reason
function SetAreaTrespass(name, level) end

---An area's trespass level for one player.
---
---Over the area's own (`SetAreaTrespass`) - `"public"` for the owner of a house, `"prohibited"` for someone banished from a
---guild hall; an area with no level of its own becomes a trespass zone for this player alone. `nil` gives them the area's own again.
---Kept while they are connected.
---@param pid number the player
---@param name string the area
---@param level string|nil the trespass level, or `nil`
---@return boolean `true`; `false` and the reason (no such area, an unknown level, not connected)
function SetPlayerAreaTrespass(pid, name, level) end

---One player's trespass level wherever they stand.
---
---Over every area and the level's own - a prisoner shown the red icon, an event's guests shown nothing. `nil` hands it back to the areas.
---@param pid number the player
---@param level string|nil the trespass level, or `nil`
---@return boolean `true`; `false` and the reason
function SetPlayerTrespass(pid, level) end

---Switches the level's own trespass areas on or off.
---
---The level's houses, keeps and camps show the game's trespass icon (on by default). Off, a place is trespass only where one of the
---map's areas says so (`SetAreaTrespass`).
---@param on boolean `true` on, `false` off
function SetLevelTrespass(on) end

---Whether the level's own trespass areas are on.
---@return boolean
function IsLevelTrespassOn() end

---The level's own trespass areas for one player.
---
---Over `SetLevelTrespass`; `nil` follows it again.
---@param pid number the player
---@param on boolean|nil `true` on, `false` off, `nil` the server's
---@return boolean `false` when the player is not connected
function SetPlayerLevelTrespass(pid, on) end

---The trespass level a player's game shows now.
---
---With what set it: `"level"` - the level's own areas (their game's word: `"public"` until it has reported), `"area"` - one of the
---map's areas (its name third), `"player"` - `SetPlayerTrespass`.
---@param pid number the player
function GetPlayerTrespass(pid) end

---The most rain a player inside an area sees.
---
---`0` keeps it dry - a roof or a ceiling built with the map editor lets no rain through on its own; `nil` gives the area the world's
---rain again. Where areas overlap, the lowest counts. The player sees the rain capped wherever they look while they are inside (out of
---a window too). Kept in the map with the area (the editor's area panel sets it too).
---@param name string the area
---@param amount number|nil `0` .. `1`, or `nil`
---@return boolean `true`; `false` and the reason
function SetAreaRain(name, amount) end

---The most rain one player sees, wherever they stand.
---
---Over the areas' (`SetAreaRain`); `nil` hands it back to them. The world's rain (`SetRain`) stays everyone else's.
---@param pid number the player
---@param amount number|nil `0` .. `1`, or `nil`
---@return boolean `false` when the player is not connected
function SetPlayerRain(pid, amount) end

---The rain a player's game shows now.
---
---The world's rain, capped by their own (`SetPlayerRain`) or their areas' (`SetAreaRain`).
---@param pid number the player
---@return number `0` .. `1`; `nil` when the player is not connected
function GetPlayerRain(pid) end

-- ======== The server's map ======================================================
-- The **server's map** is what the server adds to the level and takes out of it: the game's own meshes placed anywhere - a house, a
-- wall, a fence, barrels, a market's stalls - turned every way and scaled, and parts of the level itself removed - a house, a wall, a
-- rock, a tree, one of its entities. It lives on the server ([[docs:getting-started/server-config.md|`[world] map`]]): every player's
-- game downloads it when they join - before they appear in the world - keeps it for the next join, and gets every change at once.
-- Players walk through what was removed and stand on what was placed, and the server's own collision follows both.
-- 
-- Admins build it in the game with the map editor (`/editor` - Using the map editor) or with
-- `/map` (`/map place <mesh>`, `/map near`, `/map move`, `/map turn`, `/map scale`, `/map delete`, `/map layer`); a game mode builds it
-- with the functions below. Besides meshes the map holds the game's working things - lights,
-- particle effects, sounds (`CreateMapLight`, `CreateMapEffect`, `CreateMapSound`, `/map place light|effect <name>|sound
-- <trigger>`) and markers only the mode reads (`CreateMapMarker`, `GetMapMarkers`) - and any object may carry a use prompt that
-- players see with the game's own hint (`OnPlayerUseMapObject`, `/map use <id> <prompt>`). What either makes is written into the map and is there after a
-- restart - unless the mode passes `persist = false`: such a record lasts for the run of the mode only, is never written, and goes
-- when the mode is reloaded, so a mode that places its own set pieces in `OnGameModeInit` never doubles them.
-- 
-- The owner's own **pictures** (PNG files in the map folder's `pictures/`) and the web interface's surface pages hang on boards
-- (`CreateMapPicture`, `CreateMapSurface`); any object may sit on another (`attach`) and move with it.
-- 
-- Every object and removal belongs to a **map layer** (`"base"` unless named): a layer switched off takes everything in it out of
-- every game at once and back when it is switched on - an event's build, a winter market. A mesh is named by its path in the game's
-- files (`"objects/manmade/common_furniture/barrels/barrel_a.cgf"` - the meshes list). Places are in metres; a turn
-- is `yaw` (about the up axis, as a player's yaw: `0` faces +Y), `pitch` (the front tipped up) and `roll` (leaned sideways), in
-- degrees.

---**Called by the server** - A player's game has the server's map - or could not get it.
---
---Runs once a join on a server with a map, as soon as the player's game says where it stands: `"drawn"` - every object and
---removal is in their game (it comes before their spawn: their game holds the spawn until then, for up to a minute) -, `"failed"`
---(the download or the drawing failed; `reason` says why) or `"unsupported"` (their game cannot draw a map at all). A player
---whose game failed plays without the map - they may walk through what was placed and see what was removed; a mode whose world
---needs the map can tell them or `Kick` them.
---@param pid number the player
---@param state string `"drawn"`, `"failed"` or `"unsupported"`
---@param reason string why it failed (`""` when drawn)
function OnPlayerMapReady(pid, state, reason) end

---**Called by the server** - A player's edit in the in-game map editor, before it is made - return `false` to refuse it.
---
---Runs for every edit from the in-game editor (`SetPlayerEditor`, an admin's `/editor`) after the editor's own scope allowed
---it, never for the mode's own functions. `edit` says what it would do: `label` (what the editor calls it - `"move"`,
---`"place"` ...), the counts `placed`, `changed`, `deleted`, `removed` (parts of the level taken out), `restored`, the
---`meshes` it places, the `layers` it switches, the `places` (`{x, y, z}`) of every object it places or moves, the `areas`
---(names) it draws, changes or deletes and `navLinks` (how many nav links it draws or deletes). Refused, the
---player's editor says so and nothing changes. An undo or redo of an edit already made is not asked again.
---
---Return value: `boolean` - `false` refuses the edit; anything else lets it through
---@param pid number the player
---@param edit table `{label, placed, changed, deleted, removed, restored, meshes, layers, places, areas, navLinks}`
function OnMapEdit(pid, edit) end

---**Called by the server** - A player pressed the use key on a map object with a use prompt.
---
---A map object's `use` (`CreateMapObject`'s option, the editor's "Use prompt") shows as the game's own use hint over it; the
---key on it comes here once the server checked that the player stands within reach of it. What it does is the mode's - a lever, a
---sign to read, a well to drink from.
---@param pid number the player
---@param id number the map object (`GetMapObject`)
function OnPlayerUseMapObject(pid, id) end

---Opens the in-game map editor for a player - with what they may do - or closes it.
---
---In the editor the player flies, picks the game's meshes from its panel, places, moves, turns and scales them with the mouse
---and takes level things out; every edit reaches every player at once and is written into the map, and the player's undo and
---redo are their own. The panel needs the web interface in their game; without it the editor says so.
---
---`scope` is `"admin"` (everything an admin's `/editor` gives), `"builder"` (place objects and change or delete their own -
---nothing of the level, no layers, no areas) or a table over `"admin"`'s rights: `place`, `changeOthers` (objects someone else
---made), `delete`, `removeLevel` (take parts of the level out), `layers` (switch map layers), `areas` (draw, change and delete
---the map's areas and nav links), `maxObjects` (how many objects of their
---own they may have on the map, `0` = no cap) and `layer` (the one map layer they edit - what they place goes into it, made if
---it is new). `OnMapEdit` decides each edit after the scope. `nil` or `false` closes the editor.
---@param pid number the player
---@param scope string|table|nil `"admin"`, `"builder"`, a table of rights, or `nil` to close it
---@return boolean `true`; `false` and the reason when the server has no map, the map is read-only or the player cannot fly now (on a horse, dead ...)
function SetPlayerEditor(pid, scope) end

---What a player's open map editor may do.
---@param pid number the player
---@return table `{place, changeOthers, delete, removeLevel, layers, areas, maxObjects, layer}`; `nil` when their editor is closed
function GetPlayerEditor(pid) end

---Places one of the game's meshes on the level, for every player.
---
---The object stands at (`x`, `y`, `z`) for everyone in the world now and everyone who joins later. `z` below `0` = on the ground
---there, which needs the level's heightmap or navmesh on the server (the terrain guide); without them
---give `z` (`GetPlayerPos` has it). Players and the server's collision meet it unless `solid = false`; the server learns a mesh's
---shape from the first admin's game that draws one, then its collision and its actors' paths (`MoveActor`, `FindPath`) know
---every object of that mesh (`nav` says how). With `persist = false`
---it lasts for this run of the mode only - make it again in `OnGameModeInit`. A new `layer` name makes the layer, switched on.
---One of the game's own ladders (the meshes the levels climb: `ladder_rustic_225` .. `ladder_rustic_575`, `ladder_siege_10m` and
---`ladder_siege_10m_long` in `objects/manmade/common_fixtures/ladders/`) is climbed like the level's while it is solid and not
---stretched: lean its top against a wall or a loft's edge (a `pitch` of 5 to 15 degrees, as the level's lean) with its foot on the
---ground, and its climb is on the open side; a `scale` makes the climb longer or shorter with it.
---@param mesh string the mesh's path in the game's files (the meshes list)
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table any of `yaw`, `pitch`, `roll` (degrees), `scale` (`0.05` .. `20`, `1`; or `{x, y, z}` - a mesh stretched along its own axes, each `0.05` .. `20`), `material` (one of the game's in place of the mesh's own), `tint` (`0xRRGGBBAA`), `solid` (`true`; one of the game's chairs never blocks a player, as the level's do not - the server's collision still meets it), `nav` (what the server's actors make of it: `"auto"` / `"block"` in their way, `"walkable"` they walk on it - a bridge, a ramp -, `"ignore"` left out; `"auto"`), `view` (how far away it is still drawn, `1` .. `255` - `255` as far as the game draws; `0` = by its size), `lod` (how soon the game swaps in the mesh's simpler models as players move away, `1` .. `255`: `100` is the game's normal; higher swaps sooner and draws lighter - a town of many buildings - `255` the soonest; lower keeps the detailed model farther; `0` = the game's own), `layer` (`"base"`), `group` (a folder for the editor), `persist` (`true`), `use` (a use prompt players see on it - `OnPlayerUseMapObject` hears the key; `""`), `params` (a chair's: `"table"` sits the player at a table - the game's at-a-table pose; none = sitting on their own), `attach` (the id of the map object it sits on: it moves, turns and stretches with that one and goes when that one is deleted - a lamp on a cart, a sign on a wall; `0` = none), `rain` (`true`: a roof keeps the rain out under it, as the level's own roofs do; `false` lets it fall through - an awning of cloth, a pergola)
---@return number the object's id; `nil` and the reason when the server has no map, the map is read-only or a value is out of its bounds
function CreateMapObject(mesh, x, y, z, opts) end

---Changes a map object - moves, turns, scales it, or anything else it has.
---
---`changes` holds the fields to change, with the names `GetMapObject` gives them (`x`, `y`, `z`, `yaw`, `pitch`, `roll`, `scale`,
---`material`, `tint`, `solid`, `nav`, `view`, `lod`, `layer`, `group`, `persist`, `rain`); the rest stay. Every player sees it change at once.
---@param id number the object
---@param changes table the fields to change
---@return boolean `true`; `false` and the reason when there is no such object or a value is out of its bounds
function SetMapObject(id, changes) end

---Takes a map object off the level for everyone.
---@param id number the object
---@return boolean `true`; `false` and the reason when there is no such object
function DeleteMapObject(id) end

---A map object as it stands.
---@param id number the object
---@return table `{id, mesh, x, y, z, yaw, pitch, roll, scale, material, tint, solid, view, lod, layer, group, persist, by, revision, nav, use, params, attach, rain, key, prefab, part_of}` (`mesh` is `"entity:light"`, `"entity:effect"`, `"entity:sound"`, `"entity:marker"` or `"entity:door"` for what `CreateMapLight` and its kin make, `params` their settings; `"picture:<name>"` or `"surface:<page>"` for a board - `CreateMapPicture`, `CreateMapSurface`; `"prefab:<name>"` for a prefab placed as one unit - `CreateMapPrefab` -, `prefab` then its prefab's name; `part_of` the unit an object of a unit belongs to - `GetMapPrefabParts` -, `nil` for an object of its own; `attach` the object it sits on, `0` none; `key` a door's key; `scale` a number, or `{x, y, z}` for a mesh stretched along its own axes) (`by`: the admin who last changed it, `""` for the mode; `revision`: the map's revision at that change); `nil` when there is none
function GetMapObject(id) end

---The map objects around a point, nearest first.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@return table a list of `GetMapObject`'s tables, nearest first, at most 256 (a prefab unit and each of its objects - those with `part_of` set)
function GetMapObjectsNear(x, y, z, radius) end

---Hangs one of the map's pictures on the level - a poster, a banner, a painting, a shop's sign.
---
---A **picture** is a PNG file the owner puts in the map folder's `pictures/` folder (its name - letters `a`-`z` first, then letters,
---digits, `_` and `-` - is the picture's; at most 2048 pixels a side, 64 pictures and 8 megapixels in all; `ReloadMapPictures` or
---`/map pictures reload` after adding one). The server reads it and every player's game gets its pixels with the map, once, and keeps
---them. It stands on a board at (`x`, `y`, `z`) - its middle -, its face looking where `yaw` turns (as a player's yaw: `0` faces +Y),
---`opts.width` metres wide (`1`) and as tall as the picture is for that width unless `opts.height` says otherwise; `pitch` tips it
---back, `roll` turns it about its face. A picture with see-through parts shows the world behind them, soft, unless `transparent` is
---`"cutout"` (hard edges) or `false` (a plain board under them). With `attach` it sits on another map object and moves with
---it. It is a map object like any other (`SetMapObject`, `DeleteMapObject`, a layer, `persist`); never solid. In the editor:
---"Pictures and pages" in the panel, then a click on a wall.
---@param name string the picture's name (its file's, without `.png`)
---@param x number metres - the board's middle
---@param y number metres
---@param z number metres
---@param opts? table any of `yaw`, `pitch`, `roll` (degrees), `width` (metres, `0.1` .. `20`; `1`), `height` (metres; the picture's shape), `transparent` (`true` / `"blend"` soft, `"cutout"` hard, `false` a plain board; soft for a picture with see-through parts, else plain), `glow` (`0` .. `1`: how bright it stays at night; `0`), `use` (a use prompt - `OnPlayerUseMapObject`), `attach` (the map object it sits on), `layer`, `group`, `persist`
---@return number the map object's id; `nil` and the reason (no such picture, a size out of bounds, no map ...)
function CreateMapPicture(name, x, y, z, opts) end

---Hangs one of the web interface's surface pages on the level as a map object - a notice board that stays with the map.
---
---The same board as `CreateWebSurface`'s - a page of the interface's `ui.toml` `[surfaces.<page>]`, live on every screen near it -,
---but kept in the server's map: it is there after a restart, the editor moves it, it may sit on another map object (`attach`) and an
---export carries it. The map makes its surface for it: `GetMapObjectSurface` gives it, and the surface functions take it like any
---(`SendWebSurfaceMessage`, `OnPlayerWebSurfaceReady` ...). It is as wide as `opts.width` (metres, `1`) and as tall as the page's
---shape for that width unless `opts.height` says otherwise; `use` is its prompt (`OnPlayerUseWebSurface` hears it). Move it with
---`SetMapObject` (never `SetWebSurfacePos`: the map puts it back). A page the interface does not have shows nothing until it does.
---@param page string the page's name in `ui.toml` (`[surfaces.<page>]`)
---@param x number metres - the board's middle
---@param y number metres
---@param z number metres
---@param opts? table as `CreateMapPicture`'s: `yaw`, `pitch`, `roll`, `width`, `height`, `transparent`, `glow`, `use` (or `prompt`), `attach`, `layer`, `group`, `persist`
---@return number the map object's id; `nil` and the reason (no such page, a size out of bounds, no map ...)
function CreateMapSurface(page, x, y, z, opts) end

---The web surface a "surface:" map object shows.
---@param id number the map object (`CreateMapSurface`)
---@return number the surface (an entity id, for the surface functions); `nil` when the object is none or its page is not in the interface
function GetMapObjectSurface(id) end

---The map object a web surface of the map shows.
---@param surface number a web surface (an entity id)
---@return number the map object's id; `nil` for a mode's own surface (`CreateWebSurface`)
function GetWebSurfaceMapObject(surface) end

---The map's pictures - the PNG files of its pictures folder.
---@return table a list of `{name, width, height}` (pixels), by name
function GetMapPictures() end

---Reads the map's pictures folder again - a picture added, changed or taken away.
---
---Every player's game gets the map anew: the ones whose boards show a changed picture download it. Admins: `/map pictures reload`.
function ReloadMapPictures() end

---Places a light on the level, for every player.
---
---One of the game's own lights at (`x`, `y`, `z`) - a lantern's glow, a fire's, a cold moonlit window. It is a map object like a
---placed mesh (moved, changed and deleted with `SetMapObject` / `DeleteMapObject`, on a layer, `persist` as theirs), never solid
---and nothing the server's actors walk around. Its settings are its `params` (`"r g b radius strength style"`); the editor's inspector
---changes them too.
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table any of `r`, `g`, `b` (the colour, `0` .. `1`; a warm `1, 0.75, 0.5`), `radius` (metres, `0.1` .. `50`; `6`), `strength` (`0` .. `20`; `1`), `style` (the game's light style - `0` steady, others flicker or pulse; `0`), and `CreateMapObject`'s `layer`, `group`, `persist`, `use`
---@return number the light's id; `nil` and the reason
function CreateMapLight(x, y, z, opts) end

---Places one of the game's particle effects on the level - a fire, smoke, a candle's flame - for every player.
---@param effect string the effect's name in the game's files (`"WH_Particels.fires.candle"`, `"WH_Particels.smokes.chimney"`): letters, digits, `_` and `.`
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `size` (`0.05` .. `20`; `1`), and `CreateMapObject`'s `yaw`, `layer`, `group`, `persist`, `use`
---@return number the effect's id; `nil` and the reason (a name that is no effect's shows nothing in the game)
function CreateMapEffect(effect, x, y, z, opts) end

---Places a sound of the game's - a crackling fire, a brook, a smithy's loop - on the level, for every player.
---
---The sound plays where it stands, heard as the game's own sounds are (louder near it, through walls muffled); a looping trigger
---loops, a one-shot plays when the player's game draws it.
---@param trigger string the game's audio trigger (`"a_l_hot_wood_loop"`): letters, digits, `_` and `.`
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `CreateMapObject`'s `layer`, `group`, `persist`, `use`
---@return number the sound's id; `nil` and the reason
function CreateMapSound(trigger, x, y, z, opts) end

---Places a marker - a point only the editor and the mode know - on the level.
---
---Players never see a marker; the editor draws it, and the mode finds it by its tag with `GetMapMarkers`: spawn points, a race's
---gates, where a merchant stands - placed and moved by the admins in the editor, read by the mode.
---@param tag string what `GetMapMarkers` looks for (`"spawn"`; a-z, 0-9, `_` and `-`, at most 32; `""` = none)
---@param x number metres
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `CreateMapObject`'s `yaw` (which way it faces), `layer`, `group`, `persist`
---@return number the marker's id; `nil` and the reason
function CreateMapMarker(tag, x, y, z, opts) end

---Places one of the game's doors on the level - it opens, closes and locks for everyone.
---
---The game's own door with one of its door models: players open and close it with the use key, and the server keeps its state like a
---level door's - the same functions take it by its key (`SetDoorState`, `GetDoorState`, `SetDoorCheck`, `SetDoorKey`,
---`OnPlayerUseDoor`), and it is a door to `GetNearestDoor`, `GetDoorPosition`, `GetLevelDoors` and `/objectinfo`. Locked, it
---has a keyhole on both sides, whichever way it faces: the mode's key (`SetDoorKey`), a lockpick or the mode's word opens it. It is
---a map object like a placed mesh (moved and deleted with `SetMapObject` / `DeleteMapObject`, `persist` as theirs); its `params`
---are `"model [locked]"`.
---@param x number metres - the door's hinge
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `model` (one of the game's doors, `"objects/characters/assets/doors/lvl3_door_f_left.cdf"`), `locked` (it starts locked; `false`), and `CreateMapObject`'s `yaw`, `layer`, `group`, `persist`
function CreateMapDoor(x, y, z, opts) end

---A place to sit or a bed to sleep in, on any object - players use it with the game's own Sit and Sleep.
---
---The game's own seat: a player's use key shows "Sit" (a bed: "Sit", and held, "Sleep") and their game sits, lies down or sleeps
---there as on the level's own benches and beds - the other players see it like any sitting. **The game's furniture needs none**: a
---chair, bench or bed of the game's own meshes placed with `CreateMapObject` or the editor gets its seats by itself (while it
---stands upright at its own size; a chair sits the player on their own unless its `params` are `"table"` - the game's
---sitting-at-a-table pose); a seat is for anything else - a log, a crate, a wagon's bed, a mode's own furniture. Put it on
---the floor where the sitter's feet are, at the seat's front edge; `yaw` is where the sitter looks (a bed's: the way the bed lies).
---It is a map object (moved and deleted with `SetMapObject` / `DeleteMapObject`, `persist` as theirs); its `params` are the pose.
---@param pose string `"bench_low"` (a stool, a low bench; the default), `"bench_high"` (a bench or chair with a back), `"table_left"` / `"table_right"` (a bench at a table), `"chair_table"` / `"chair_table_low"` (a chair at a table: the arms on it), `"ground"`, `"bed_high"`, `"bed_low"`, `"bed_ground"` (a bedroll), `"bed_bench"` (sleeping on a bench), `"bed_left"` / `"bed_right"` (a double bed's halves)
---@param x number metres - where the sitter's feet are
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `CreateMapObject`'s `yaw` (where the sitter looks), `layer`, `group`, `persist`
---@return number the seat's id; `nil` and the reason
function CreateMapSeat(pose, x, y, z, opts) end

---The map's markers of a tag.
---@param tag? string the tag (`nil` or `""` = every marker)
---@return table a list of `GetMapObject`'s tables, by id (`params` is the tag, `yaw` the way it faces)
function GetMapMarkers(tag) end

---Takes a part of the level out on every player's game - a house, a wall, a tree, an entity.
---
---`kind` says what it is: `"brush"` - a static mesh of the level (a house, a wall, a rock) - or `"vegetation"` (a tree, a bush),
---named by `opts.mesh` and found by the centre of its box at (`x`, `y`, `z`), within 5 cm; or `"entity"`, one of the level's
---entities, named by `opts.class` and `opts.name` and found at its position, within 5 m. Admins measure both by looking at the
---thing; a mode takes the values from there - or from a player's own look: a client script's
---GetLookTarget gives a tree's or a building's `mesh` and `center`, sent up with
---`SendServerEvent` (its `kind` says which: `"vegetation"` is `"vegetation"` here, `"static"` is `"brush"` - many of the level's
---small stones are vegetation). Players walk through where it stood and the server's collision follows; `RestoreLevelObject`
---puts it back.
---`opts.layer` and `opts.persist` as an object's.
---@param kind string `"brush"`, `"vegetation"` or `"entity"`
---@param x number metres
---@param y number metres
---@param z number metres
---@param opts table `mesh` (a brush or vegetation), `class` and `name` (an entity), `layer`, `persist`
---@return number the removal's id; `nil` and the reason when the server has no map or something is missing
function RemoveLevelObject(kind, x, y, z, opts) end

---Puts a removed part of the level back for everyone.
---@param id number the removal
---@return boolean `true`; `false` and the reason when there is no such removal
function RestoreLevelObject(id) end

---Every part of the level the map takes out.
---@return table a list of `{id, kind, class, name, mesh, x, y, z, layer, persist, by, revision}`
function GetLevelRemovals() end

---Switches a map layer on or off for every player.
---
---Everything in the layer - objects and removals - shows or goes in every game at once, and the server's collision follows. A
---new name makes the layer. The switch is written into the map: it is still so after a restart.
---@param name string the layer
---@param on boolean `true` shows it
---@return boolean `true`; `false` and the reason when the server has no map
function SetMapLayer(name, on) end

---Every map layer and whether it is on.
---@return table `{name = on, ...}`
function GetMapLayers() end

---The server's map - what it holds and where it stands.
---@return table `{objects, removals, revision, hash, folder, readOnly, reason}`: `hash` is the fingerprint every player's game draws (an admin's `/map hash` shows it), `folder` is where it is written (`""` = the server has no map), `readOnly` (and `reason`) a map the server will not write over
function GetMapInfo() end

---Writes the map to its folder now.
---
---The map writes itself a few seconds after each edit; this writes it at once - before a backup, say.
---@return boolean `false` when the server has no map or it is read-only
function SaveMap() end

---Writes the map as one file, to keep or to carry to another server.
---
---The file is `exports/<name>.zip` in the map's folder: every record of the map (not the run-only ones) and the shapes and prefabs
---that go with it. Another server of the same level imports it (`ImportMap`) from its own map folder's `exports/` - copy the file
---there. Admins: `/map export <name>`.
---@param name string letters, digits, `_` and `-`, at most 48
function ExportMap(name) end

---The exports in the map's folder, newest first.
---@return table a list of names (without `.zip`)
function GetMapExports() end

---Brings an export into the map - merged beside what is there, or replacing it.
---
---`"merge"` adds every record of the export as a new one and its layers (an area whose name the map already holds is left out) - a
---market built on one server added to another's map. `"replace"` makes a backup of the map first, then the map is the export, every
---record under its own id - so the same export gives the same fingerprint (`/map hash`) on every server that imports it; the run-only
---records go too, and every player's game draws the new map at once. Shapes and prefabs the export carries come along. Admins:
---`/map import <name> merge|replace`.
---@param name string the export's name (`GetMapExports`)
---@param mode? string `"merge"` (the default) or `"replace"`
function ImportMap(name, mode) end

---Writes a backup of the map now.
---
---A backup is an export in the map's `backups/` folder (`<level>-<date>.zip`). The server makes one by itself every day it runs (and at
---a start when the newest is a day old) and before an import replaces the map, and keeps the newest 14. Bring one back by copying it
---into `exports/` and `ImportMap` with `"replace"`. Admins: `/map backup`, `/map backups`.
function BackupMap() end

---Adds a layer saved from the Sandbox editor to the map.
---
---Reads `exports/<name>.lyr` (or `.xml`) in the map's folder - a layer file of CryEngine's Sandbox editor - and adds its brushes and
---geometry entities (their meshes, places, turns, materials), lights and particle effects as new map objects on a map layer of the
---Sandbox layer's name. A mesh keeps an uneven scale (stretched along its own axes); a light's or an effect's becomes the mean of the three. What else the layer holds (areas, AI
---points, other entities) is named in the answer and left out. The format is CryEngine's; files from Warhorse's own modding tools have
---not been tried. Admins: `/map import sandbox <name>`.
---@param name string the file's name without its extension
function ImportSandboxLayer(name) end

---Shows (or hides) a map layer to one player alone.
---
---The player's game draws the layer on or off whatever the map's own switch is (`SetMapLayer`) - a quest's camp only its hero sees,
---a house's furnished rooms for its owner. Their game alone: the server's own world keeps the map's switch - a layer shown to one
---player is not solid on the server (nothing holds back a walker there), one hidden from them still holds them back - and so do the
---areas. `nil` gives the player the map's own switch again; a rejoin starts from the map's.
---@param pid number the player
---@param layer string a map layer
---@param on? boolean `true` shown, `false` hidden, `nil` the map's own switch
---@return boolean `false` when the map has no such layer
function SetPlayerMapLayer(pid, layer, on) end

---The map layers a player sees otherwise than everyone.
---@param pid number the player
---@return table `{[layer] = on, ...}`
function GetPlayerMapLayers(pid) end

---The map's prefabs - sets of objects saved under a name.
---@return table a list of names
function GetMapPrefabs() end

---Saves map objects as a prefab, to place again anywhere.
---
---The objects' places are kept relative to the ground under the first one; the same name overwrites - and every unit of that
---prefab on the map (`CreateMapPrefab`) changes with it, on every player's game. A unit among the ids is saved as its objects.
---Prefabs live in the map's `prefabs/` folder and go with an export. In the editor, select the objects and use "Save as prefab";
---admins: `/map prefab save <name> <id...>`.
---@param name string letters, digits, `_` and `-`, at most 48
---@param ids table a list of map object ids (at most 256)
function SaveMapPrefab(name, ids) end

---Places a prefab's objects as new map objects.
---@param name string the prefab
---@param x number metres - where its pivot goes
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table `yaw` (degrees, turns the whole prefab about its pivot), `layer` (`"base"`), `persist` (`true`)
---@return table the new objects' ids in the prefab's order; `nil` and the reason
function PlaceMapPrefab(name, x, y, z, opts) end

---Places a prefab as one unit - one map object drawn as the prefab's objects, that follows the prefab.
---
---`PlaceMapPrefab` copies a prefab's objects into new map objects, each sent, saved and tracked on its own. A **unit** is one map
---object (`mesh` `"prefab:<name>"`): one record on the network, in the map's files and in an undo, that every player's game and the
---server draw as the prefab's objects at its place, turn and scale - a village of eighty houses is eighty records, not two thousand.
---It **follows its prefab**: saving the prefab again (`SaveMapPrefab`, the editor's "Save as prefab") changes every unit of it at
---once. Its objects are solid, have their doors, seats, lights and use prompts, and stand in the server's collision and navmesh as
---if placed one by one; each has an id of its own, the same in every game and after a restart (`GetMapPrefabParts`) - a door's key,
---the id `OnPlayerUseMapObject` names. They are changed through the unit: move, turn, scale (one number), `solid`, `view`, `lod`,
---`layer` with `SetMapObject` on the unit's id; to change one of them, `UnpackMapPrefab` first.
---
---A prefab used by a unit cannot be deleted; a unit holds no web surface board. Every object of a unit counts toward the map's
---10,000. `SetMapObject` and `CreateMapObject` with `"prefab:<name>"` as the mesh make and change units too. Admins: `/map prefab
---unit <name>`; the map editor's prefab list places units with "As one unit".
---@param name string the prefab
---@param x number metres - where its pivot goes
---@param y number metres
---@param z number metres; below `0` = on the ground
---@param opts? table as `CreateMapObject`'s: `yaw`, `pitch`, `roll`, `scale` (one number), `solid` (`false`: none of its objects is), `view`, `lod` (over its objects' own; `0` = theirs), `layer`, `group`, `persist`, `attach`
---@return number the unit's id; `nil` and the reason
function CreateMapPrefab(name, x, y, z, opts) end

---A prefab unit's objects as they stand on the level.
---@param id number the unit
---@return table a list of `GetMapObject`'s tables in the prefab's order (each with `part_of` = the unit; a door's `key`); empty for no unit
function GetMapPrefabParts(id) end

---Turns a prefab unit into the prefab's objects, each a map object of its own.
---
---One edit: the unit goes, its objects stay where they stood as ordinary map objects (they no longer follow the prefab), and what
---sat on the unit stays where it is. The map editor's inspector has "Unpack" for a selected unit; admins: `/map prefab unpack <id>`.
---@param id number the unit
---@return table the new objects' ids in the prefab's order; `nil` and the reason
function UnpackMapPrefab(id) end

---Takes a prefab off the list (its placed objects stay).
---
---Refused while a unit of it stands on the map (`CreateMapPrefab`) - delete or unpack those first.
---@param name string the prefab
function DeleteMapPrefab(name) end

---Lets the server's actors go between two points their walk cannot join - a jump down, a gap, a ladder.
---
---The server's actors (`MoveActor`, a chase) and `FindPath` walk the level's navmesh; a link joins two places on it that no
---walk does - the top and the foot of a wall they may jump down, the two ends of a placed bridge the navmesh does not know yet.
---The navmesh around both ends is rebuilt with it within a couple of seconds. Like a placed object it is written into the map
---and there after a restart, unless `persist = false`. The admins' editor draws them too, and `/map navlink` makes one where an
---admin stands.
---@param x1 number metres - where the link starts
---@param y1 number metres
---@param z1 number metres
---@param x2 number metres - where it leads
---@param y2 number metres
---@param z2 number metres
---@param opts? table any of `radius` (how near an end an actor must come, metres, `0.6`), `twoWay` (`true`; `false` = from the first point only), `type` (a word of the mode's, `"jump"`), `layer` (`"base"`), `persist` (`true`)
---@return number the link's id; `nil` and the reason when the server has no map or the map is read-only
function CreateNavLink(x1, y1, z1, x2, y2, z2, opts) end

---Takes a nav link off the map.
---@param id number the link's id
---@return boolean `true`; `false` and the reason
function DeleteNavLink(id) end

---The nav links with an end near a point.
---@param x number metres
---@param y number metres
---@param z number metres
---@param radius number metres
---@return table a list of `{id, x1, y1, z1, x2, y2, z2, radius, twoWay, type, layer, persist, by, revision}`, the nearest first (at most 256)
function GetNavLinks(x, y, z, radius) end

-- ======== Catalogues ============================================================
-- The server resolves the game's things by **id, name or GUID** through the tables export (`[combat] tables`): items
-- (the item catalogue), souls (the souls), buffs (the buff
-- list) and meshes (the meshes; `GetMeshPath` and `FindMeshes` are with the props). Every function
-- that takes an item, a soul or a buff accepts any of the keys; these look them up, search them and turn one key into another. The
-- **id** is the row number of the name-sorted export - stable for one export of one game build, so keep the name or the GUID in
-- anything durable. Without the export only GUIDs pass, unchecked.

---The class GUID an item key stands for.
---
---`key` is an item's id, the game's name (`shortswordBroad`, case-insensitive), its English name (`Duelling longsword`; when
---several classes share one, the plainest answers) or a GUID (passed through). `nil` when the catalogue knows no such item.
---@param key string|number an item's id, name, English name or GUID
---@return string the class GUID; `nil` when unknown
function GetItemClass(key) end

---The game's name of an item key.
---
---Turns a class GUID - what the client reports, what the callbacks carry - into the name the catalogue lists.
---@param key string|number an item's id, name, English name or GUID
---@return string the name (`shortswordBroad`); `""` when unknown
function GetItemName(key) end

---The catalogue's entry for an item key.
---@param key string|number an item's id, name, English name or GUID
---@return table `{id=, name=, class=, category=, display=, weight=, price=}`: the id, the game's name, the class GUID, the category (`MeleeWeapon`, `Armor`, `Food` ...), the English name (`""` when the export had none), the weight and the price (the game's own column, in tenths of a Groschen: a torch is `60`); `nil` when unknown
function GetItemInfo(key) end

---Items whose name, English name or category holds every word of a pattern.
---@param pattern string words to look for, case-insensitive
---@param max? number at most this many (`10`)
---@return table a list of `{id=, name=, class=, category=, display=}`
function FindItems(pattern, max) end

---The soul GUID a horse key stands for - the Horse archetype only.
---@param key string|number a soul's name (`Horse2`, `Pebbles`), id or GUID
---@return string the soul GUID; `nil` when the key is not a horse soul
function GetHorseSoul(key) end

---The soul catalogue's entry for a key, of any archetype.
---@param key string|number a soul's name, id or GUID
---@return table `{id=, name=, guid=, archetype=}`; `nil` when unknown
function GetSoulInfo(key) end

---Souls whose name or archetype holds every word of a pattern.
---
---`"Horse"` alone lists the breeds; `"Dog"` the dogs; a word of a name narrows it.
---@param pattern string words to look for, case-insensitive
---@param max? number at most this many (`10`)
---@return table a list of `{id=, name=, guid=, archetype=}`
function FindSouls(pattern, max) end

---The GUID a buff key stands for.
---@param key string|number a buff's name (`well_rested`), id or GUID
---@return string the buff GUID; `nil` when unknown
function GetBuffGuid(key) end

---The buff catalogue's entry for a key.
---@param key string|number a buff's name, id or GUID
---@return table `{id=, name=, guid=, class=, display=, duration=}`: the class is what `claimed_buffs` names, the duration the game's own in game minutes (`-1` = until removed); `nil` when unknown
function GetBuffInfo(key) end

---Buffs whose name, English name or class holds every word of a pattern.
---@param pattern string words to look for, case-insensitive
---@param max? number at most this many (`10`)
---@return table a list of `{id=, name=, guid=, class=, display=}`
function FindBuffs(pattern, max) end

-- ======== Parties ===============================================================
-- Players grouped with a leader (v38, the guide): the server keeps the group, the invitation with its
-- timeout and the toast on the target's screen, the party frames every member sees (the others' name, health, stamina, wounds,
-- at any distance and in any world) and the no-friendly-fire rule. **The server ships no party commands**: `/invite`,
-- `/accept`, `/p` and every rule around them - who may invite, a level gate, leader-only invitations - are the mode's, written
-- around these callbacks and functions (the shipped freeroam mode carries the plain ones). A party is a **number**; ids count
-- up and are never reused while the server runs. A party exists with two or more members and ends when it falls to one - there
-- is no party of one. One party and one pending invitation per player. `[party]` in the server's configuration holds the size
-- (5), the invitation's timeout (30 s), the frames' default, what the leader's leaving does and the friendly fire.

---**Called by the server** - A player wants to invite another; return false to refuse.
---
---Fires from `InviteToParty` before the toast goes out, after the server's own checks (the target free, the party not
---full, no invitation pending). The place for the mode's rule: leader-only invitations, a level gate, a cooldown. Without
---the callback every invitation the server admits goes through.
---
---Return value: `false` refuses the invitation (`InviteToParty` returns `false, "refused"`); anything else lets it through
---@param from number the inviter
---@param target number the player invited
function OnPartyInvite(from, target) end

---**Called by the server** - An invitation was answered - or ran out, or fell through.
---
---`answer` is `"accepted"` (the join follows at once), `"declined"`, `"timeout"` (`[party] invite_timeout` passed) or
---`"cancelled"` - the party filled or ended before the answer, a side disconnected, or the target joined another party.
---@param from number the inviter
---@param target number the player invited
---@param answer string `"accepted"`, `"declined"`, `"timeout"` or `"cancelled"`
function OnPartyInviteResponse(from, target, answer) end

---**Called by the server** - A party came into being.
---
---The first accepted invitation (or the mode's first `AddPlayerToParty`) makes the group with the inviter leading. Fires
---before the two joins (`OnPlayerJoinParty` with `"create"` for the leader, then the newcomer's reason).
---@param party number the new party's id
---@param leader number the leader
function OnPartyCreate(party, leader) end

---**Called by the server** - A player joined a party - the leader too, at the party's birth.
---
---Every member arrives through here: `reason` is `"create"` (the leader, as the party is made), `"invite"` (an accepted
---invitation) or `"mode"` (`AddPlayerToParty`).
---@param party number the party
---@param pid number the member
---@param reason string `"create"`, `"invite"` or `"mode"`
function OnPlayerJoinParty(party, pid, reason) end

---**Called by the server** - A member is gone from the party.
---
---`reason` is `"left"` (`RemovePlayerFromParty`), `"kicked"` (the same with `"kicked"`), `"disconnect"`, or `"disband"`
---- the mode's `DisbandParty`, the leader's leaving under `leader_leaves = "disband"`, or the last member standing when
---the party fell to one. The member's label is gone with the membership.
---@param party number the party
---@param pid number the member who left
---@param reason string `"left"`, `"kicked"`, `"disconnect"` or `"disband"`
function OnPlayerLeaveParty(party, pid, reason) end

---**Called by the server** - The lead changed hands.
---
---By the mode (`SetPartyLeader`) or by the leader leaving, when the next member in join order takes over (`previous` is
---then the one who left).
---@param party number the party
---@param pid number the new leader
---@param previous number the one before
function OnPartyLeaderChange(party, pid, previous) end

---**Called by the server** - The party is over.
---
---Fires last, after every member's `OnPlayerLeaveParty`. `reason` is `"empty"` (the party fell to one member), `"mode"`
---(`DisbandParty`) or `"leader"` (the leader left and `[party] leader_leaves` is `"disband"`). A reload of the mode
---drops every party without this callback.
---@param party number the party that ended
---@param reason string `"empty"`, `"mode"` or `"leader"`
function OnPartyDisband(party, reason) end

---Sends a party invitation - the mode's /invite.
---
---The server checks both players (connected, not the same, the target in no party and with no invitation pending, the
---inviter's party not full), asks `OnPartyInvite`, and puts the toast with its countdown on the target's screen - two
---keys answer it, or the mode's `AcceptPartyInvite` / `DeclinePartyInvite`. The party is made when the invitation is
---accepted, with the inviter leading, when they have none; an inviter who is already in one invites into it. The
---invitation belongs to that party: the inviter leaving it does not withdraw it; the party filling or ending, or a side
---disconnecting, does.
---@param from number the inviter
---@param target number the player to invite
---@return boolean ok `true`, or `false, reason` - `"not connected"`, `"self"`, `"in a party"` (the target), `"full"`, `"pending"` (the target has one already) or `"refused"` (`OnPartyInvite` said no)
---@return string reason
function InviteToParty(from, target) end

---Accepts the player's pending invitation - the mode's /accept.
---
---The same road as the toast's accept key: the player joins the inviter's party (making it when there is none). `false`
---without a pending invitation. When the party filled or ended meanwhile the invitation is cancelled instead
---(`OnPartyInviteResponse` `"cancelled"`).
---@param pid number the invited player
---@return boolean `false` when nothing was pending
function AcceptPartyInvite(pid) end

---Declines the player's pending invitation - the mode's /decline.
---@param pid number the invited player
---@return boolean `false` when nothing was pending
function DeclinePartyInvite(pid) end

---The player's pending invitation.
---@param pid number the player
function GetPlayerPartyInvite(pid) end

---Puts a player into another's party without an invitation.
---
---A queue, a raid maker, a mode that groups its players itself: `pid` joins `host`'s party, which is made first (with
---`host` leading) when there is none. The join's reason is `"mode"`. `false` when either is not connected, `pid` is in a
---party already, or the party is full.
---@param host number a member of the party (or the leader of the new one)
---@param pid number the player to add
---@return boolean
function AddPlayerToParty(host, pid) end

---Takes a player out of their party - the mode's /leave and /pkick.
---
---`reason` `"left"` (the default) or `"kicked"` is what `OnPlayerLeaveParty` hears. The leader leaving hands the lead
---on (or ends the party, by `[party] leader_leaves`); a party left with one member ends.
---@param pid number the member
---@param reason? string `"left"` or `"kicked"`
---@return boolean `false` when in no party
function RemovePlayerFromParty(pid, reason) end

---Hands the lead to a member - the mode's /leader.
---@param party number the party
---@param pid number the member who leads from now
---@return boolean `false` when they are not a member
function SetPartyLeader(party, pid) end

---Ends a party.
---
---Every member leaves with `"disband"`, then `OnPartyDisband` fires with `"mode"`.
---@param party number the party
---@return boolean `false` for an unknown party
function DisbandParty(party) end

---The party the player is in.
---@param pid number the player
---@return number the party's id; `nil` in none
function GetPlayerParty(pid) end

---The party's leader.
---@param party number the party
---@return number the leader's pid; `nil` for an unknown party
function GetPartyLeader(party) end

---The members, in join order.
---@param party number the party
---@return table of pids in join order; `{}` for an unknown party
function GetPartyMembers(party) end

---How many members the party has.
---@param party number the party
---@return number 0 for an unknown party
function GetPartySize(party) end

---Whether the party is at [party] max_size.
---@param party number the party
---@return boolean
function IsPartyFull(party) end

---Whether two players are in one party.
---
---For the mode's own rules - loot shared with the party, a duel refused between friends, a party chat.
---@param a number one player
---@param b number the other
---@return boolean
function ArePartyMembers(a, b) end

---Every party on the server.
---@return table of party ids
function GetParties() end

---The party's title, shown over the members' frames.
---@param party number the party
---@param text string the title; `""` none
---@return boolean `false` for an unknown party
function SetPartyName(party, text) end

---The party's title.
---@param party number the party
---@return string `""` when none or unknown
function GetPartyName(party) end

---A line under the member's name in the frames - a role, a score.
---
---Cosmetic; goes with the membership. `""` clears it.
---@param pid number the member
---@param text string the label; `""` none
---@return boolean `false` when in no party
function SetPartyMemberLabel(pid, text) end

---The member's label.
---@param pid number the member
---@return string `""` when none
function GetPartyMemberLabel(pid) end

---Whether this player sees the party frames.
---
---`[party] frames` is the default for everyone; a mode that draws its own frames from a client script
---(`GetParty()`, `OnPartyChange` on the client) hides the server's for its players. This is the same switch as the
---`party` interface component: `SetPlayerInterface(pid, "party", "hidden")` and `SetInterfaceForAll` set it too,
---and `GetPlayerInterface` reports it; the frames' corner and stamina bar are `SetPlayerInterfaceOptions`.
---@param pid number the player
---@param shown boolean the frames on or off
---@return boolean `false` when not connected
function ShowPartyFrames(pid, shown) end

---One chat line to every member - the mode's /p.
---
---A text over 16384 bytes (UTF-8) is cut there, on a character boundary.
---@param party number the party
---@param color number 0xRRGGBBAA
---@param text string the line
---@return boolean `false` for an unknown party
function SendPartyMessage(party, color, text) end

---The mode's private storage on a party.
---
---A key and any value the mode keeps with the party; gone with it. `nil` removes the key.
---@param party number the party
---@param key string the key
---@param value any the value; `nil` removes
---@return boolean `false` for an unknown party
function SetPartyData(party, key, value) end

---A value of the mode's private storage on a party.
---@param party number the party
---@param key string the key
function GetPartyData(party, key) end

-- ======== Shops and vendors =====================================================
-- A **shop** is a thing the server keeps: a title, the items it sells with a price and a stock, what it buys from the
-- players and at what price, and its purse. Put a shop on an NPC actor - `CreateVendor` makes one in a
-- single call, `SetActorShop` puts a shop on an actor you have - and it becomes a **vendor**: "Trade" shows under its name
-- within reach and the use key opens the game's own **trade screen**, the one a merchant opens in the story - the player's
-- things on one side, the vendor's shelf on the other, a basket, the prices and both purses along the bottom, "Close deal".
-- Haggling is off. A deal closes the screen, as in the story; the use key opens it again. Open a shop on a player outright
-- with `OpenShop` - from a command, a zone, a chest - and it shows on the **shop panel** instead: a list in the game's own
-- look with a Buy tab and a Sell tab, driven with the keys (W / S move, A / D set the quantity, Tab switches the tabs, Enter
-- buys or sells, Esc closes); `SetShopScreen` keeps a vendor on the panel too.
-- 
-- Every transaction is the server's. A deal - the panel's one line or the trade screen's basket - is checked as a whole: the
-- stock, what the player carries, and the purse that changes hands, where the sales pay for the purchases (what the player
-- carries and their purse are what the server's records explain - `GetPlayerMoney`, `GetPlayerInventory`; under
-- `[audit] mode = "observe"` what their game holds). A sale takes the exact items the trade screen named, and an item the game
-- will not let go of - a quest item - is not for sale. Under `enforce` a deal in the first seconds of a visit, before the
-- server follows the player's bag, is turned down with "Not now: your items are still being checked." The mode may refuse each
-- line in `OnPlayerBuy` / `OnPlayerSell` and the whole in `OnPlayerShopDeal`; one no calls it all off. The items and the
-- money then move by the same road as `GivePlayerItem`: the purchase is a gift, the sale an exact order, so the item check
-- explains them, and a sold item is final even if the player's game claims to have kept it. Prices
-- are Groschen (`12.5` is fine). What a shop buys: `sellFactor` of an item's catalogue price (`GetItemInfo` `price`, which
-- the game keeps in tenths of a Groschen - a torch is `60`) - never more than the shop itself asks for an item it sells -
-- narrowed to some categories with `SetShopBuyCategories` and priced class by class with `SetShopBuyPrice`; the trade
-- screen offers the vendor exactly that and nothing else. The
-- screen closes when the player walks 4 m from the vendor, the vendor dies or goes, the player dies or leaves, the mode says
-- `CloseShop`, or they close it. A reload takes every shop down. A shop is a **number**; ids count up.

---**Called by the server** - The player is about to buy from a shop - return `false` to refuse.
---
---The stock and the purse were checked already: `amount` is available and the player can pay `amount x price`. Return
---`false` and nothing moves (say why with `SendClientMessage`); anything else lets the items and the money go. The
---class is the item's GUID (`GetItemInfo` names it).
---
---Return value: `false` refuses the purchase; anything else (or nothing) lets it through
---@param pid number the buyer
---@param shop number the shop
---@param class string the item's class GUID
---@param amount number how many
---@param price number Groschen a piece
---@param id string a tagged row's id (`SetShopTaggedItem`), `""` for a plain row
function OnPlayerBuy(pid, shop, class, amount, price, id) end

---**Called by the server** - The player is about to sell to a shop - return `false` to refuse.
---
---The player carries `amount` of the item (the server's records say so) and the shop can pay `amount x price`.
---Return `false` and nothing moves. The items sold vanish - a shop does not put them on its shelf by itself; a mode that
---wants a second-hand stall does it here with `SetShopItem`.
---
---Return value: `false` refuses the sale; anything else (or nothing) lets it through
---@param pid number the seller
---@param shop number the shop
---@param class string the item's class GUID
---@param amount number how many
---@param price number Groschen a piece, what the shop pays
---@param id string the sold item's id when it is one of the mode's tagged items (one with a price of its own - `SetPlayerItemPrice`), `""` otherwise
function OnPlayerSell(pid, shop, class, amount, price, id) end

---**Called by the server** - A deal is about to be done - every line at once; return `false` to call it off.
---
---Asked last: every line was checked - the stock, what the player carries, the purse that changes hands - and passed
---`OnPlayerSell` / `OnPlayerBuy`; the items and the money move right after this returns anything but `false`, so it is
---the place for what must happen only when a deal is really done. `deal.lines` lists the sales first, then the purchases,
---one line per item class: `{class=, amount=, price=, buy=, health=}` (`price` in Groschen a piece, `buy` `true` for a purchase;
---`health` the pieces' condition from 0 to 100 - 100 for a purchase, for a sale the average of the pieces it takes, the very
---items the trade screen named first; a line of one of the mode's tagged items - a tagged row bought, the player's own sold -
---also has its `id`).
---`deal.cost` is what the purchases cost and `deal.proceeds` what the sales bring; the player pays the difference, or is
---paid it. A deal on the shop panel is one line; the trade screen's "Close deal" sends the whole basket.
---
---Return value: `false` calls the deal off - nothing moves; anything else (or nothing) lets it through
---@param pid number the player
---@param shop number the shop
---@param deal table `{lines = {{class=, amount=, price=, buy=, health=, id=}, ...}, cost=, proceeds=}`
function OnPlayerShopDeal(pid, shop, deal) end

---**Called by the server** - A shop screen is about to open on a player - return `false` to keep it closed.
---
---The use key on a vendor (after `OnPlayerInteractActor`) or `OpenShop` is opening the shop on the player. Return
---`false` and nothing opens - say why with `SendClientMessage`. `vendor` is the actor the shop is on, `nil` for a shop
---opened without one.
---
---Return value: `false` keeps the screen closed; anything else (or nothing) opens it
---@param pid number the player
---@param shop number the shop
---@param vendor number|nil the vendor actor; `nil` = none
function OnPlayerOpenShop(pid, shop, vendor) end

---**Called by the server** - The shop screen closed on a player.
---
---`reason` is `""` for the player's own close (Esc), else why the server took it down: `"you walked away"`, `"the vendor
---is gone"`, `"you died"`, `"you left"`, `"closed by the game mode"` (`CloseShop`), `"the shop closed"`
---(`DestroyShop`), `"the vendor stopped trading"` (`SetActorShop` with `nil`), `"another shop opened"`.
---@param pid number the player
---@param shop number the shop
---@param reason string why; `""` = their own close
function OnPlayerCloseShop(pid, shop, reason) end

---Makes a shop - a title, whether it buys, its purse.
---
---Empty until `SetShopItem` fills it. `sellFactor` is the fraction of an item's catalogue price the shop pays when a
---player sells (`0.5` = half its worth; `0`, the default, = it buys nothing and the screen has no Sell tab). `money` is
---the purse in Groschen it pays out of (`nil` or a negative number = bottomless); what the players buy fills it. Put it
---on an actor with `SetActorShop` or open it with `OpenShop`.
---@param title string the screen's title
---@param sellFactor? number `0` .. `1` (`0`: buys nothing)
---@param money? number the purse in Groschen; `nil` = bottomless
---@return number the shop's id; `nil` when it could not be made
function CreateShop(title, sellFactor, money) end

---Removes a shop; the screens on it close, the vendors selling it stop.
---@param shop number the shop
---@return boolean `false` when there is no such shop
function DestroyShop(shop) end

---Whether a shop id names a shop.
---@param shop number the id
---@return boolean
function IsValidShop(shop) end

---Puts an item on the shelf - or changes its price and stock.
---
---`item` is any key of the item catalogue (the name, the id, the English name, the GUID); an
---unknown key returns `false` and logs. `price` is Groschen a piece. `amount` is the stock: `nil` or `-1` = unlimited,
---`0` takes the row off the shelf. A row already there is changed in place; whoever has the screen open sees it move.
---@param shop number the shop
---@param item string|number the item's name, id, English name or GUID
---@param price number Groschen a piece
---@param amount? number the stock; `nil` / `-1` = unlimited, `0` = off the shelf
---@return boolean `false` for an unknown item or shop
function SetShopItem(shop, item, price, amount) end

---Takes an item off the shelf.
---@param shop number the shop
---@param item string|number the item's key
---@return boolean `false` when it was not on the shelf
function RemoveShopItem(shop, item) end

---Puts one of your tagged items on the shelf - a prize, a charter, a key - under its own name.
---
---`item` is a tagged entry as `GetPlayerInventory` lists one: `class` (any key of the item catalogue),
---`id`, `name`, `text`, `weight` - plus `price` (Groschen a piece) and `amount` (how many: 1 by default, `-1` unlimited, `0` takes
---the row off). The shop shows the row under its `name`, and every piece sold is a tagged item with that id, name, text and weight,
---worth the price it cost (`SetPlayerItemPrice`: a shop that buys its kind takes it back at its sell factor). A player holds one
---item of an id, so one who has it already is refused ("you have one already"); give each row an id of its own for items every
---player should own apart. The row is its `id`: set again, it changes. `OnPlayerBuy` names the id.
---@param shop number the shop
---@param item table `{class=, id=, name=, text=, weight=, price=, amount=}`
---@return boolean `false` for no shop, an unknown class, an empty id or a negative price
function SetShopTaggedItem(shop, item) end

---Takes a tagged row off the shelf (SetShopTaggedItem).
---@param shop number the shop
---@param id string the row's id
---@return boolean `false` when the shop has no row with that id
function RemoveShopTaggedItem(shop, id) end

---The shelf - every row with its price and stock.
---@param shop number the shop
---@return table a list of `{class=, price=, amount=}`; `amount` `-1` = unlimited; a tagged row (`SetShopTaggedItem`) also has its `id`, `name`, `text` and `weight`; `{}` for no shop
function GetShopItems(shop) end

---The shop's purse in Groschen.
---@param shop number the shop
---@return number Groschen; `-1` = bottomless
function GetShopMoney(shop) end

---Sets the shop's purse.
---@param shop number the shop
---@param money number Groschen; `nil` or negative = bottomless
---@return boolean
function SetShopMoney(shop, money) end

---The shop's title.
---@param shop number the shop
---@return string `""` for no shop
function GetShopTitle(shop) end

---Renames the shop; open screens show the new title.
---@param shop number the shop
---@param title string the new title
---@return boolean
function SetShopTitle(shop, title) end

---Opens the shop screen on a player.
---
---The screen comes up with the Buy tab (and the Sell tab when the shop buys). With `vendor` - an NPC
---actor - the screen closes when the player walks 4 m from it or it dies; without one it stays until `CloseShop` or
---the player's Esc. A shop already open on the player is replaced. An actor with a shop of its own opens
---it on the use key without any of this.
---@param pid number the player
---@param shop number the shop
---@param vendor? number the actor the shop is on; `nil` = none
---@return boolean `false` when the player is not in the world or the shop does not exist
function OpenShop(pid, shop, vendor) end

---Closes the shop screen on a player.
---@param pid number the player
---@return boolean `false` when no shop was open
function CloseShop(pid) end

---The shop open on a player's screen.
---@param pid number the player
---@return number the shop; `nil` when none
function GetPlayerShop(pid) end

---Makes a vendor - an NPC actor nobody can hurt, selling a shop.
---
---One call for `CreateActor` (the same `soul`, place, `name`, `clothing` and `world`; no weapons - a vendor stands
---unarmed), `SetActorInvulnerable` and `SetActorShop`. The use key on it opens the shop on the game's own trade screen
---(`SetShopScreen` keeps the panel). Move it, pose it and destroy it like any actor (`MoveActor`, `SetActorAnim`,
---`DestroyEntity`); `SetActorShop` changes what it sells.
---@param shop number the shop it sells
---@param soul string|number|nil a soul's name, id or GUID; `nil` = the server's pool
---@param x number metres
---@param y number metres
---@param z number metres (below `0` = on the ground)
---@param yaw number degrees (`0` without)
---@param name? string the label over its head; `nil` = none
---@param clothing? string a clothing preset GUID; `nil` = the server default
---@param world? number the virtual world; `nil` = the shared one
---@return number the vendor's entity id; `nil` when the shop does not exist or the actor could not be made
function CreateVendor(shop, soul, x, y, z, yaw, name, clothing, world) end

---Which screen a vendor's shop opens on - the game's trade screen or the panel.
---
---`SHOP_SCREEN_TRADE` (the default) opens a vendor's shop on the game's own trade screen; `SHOP_SCREEN_PANEL` keeps it on
---the shop panel. A shop opened without a vendor (`OpenShop` with no actor) is always on the panel. A screen open now
---keeps its kind until it closes.
---@param shop number the shop
---@param screen number `SHOP_SCREEN_TRADE` or `SHOP_SCREEN_PANEL`
---@return boolean `false` for no such shop or an unknown screen
function SetShopScreen(shop, screen) end

---The screen a vendor's shop opens on.
---@param shop number the shop
---@return number `SHOP_SCREEN_TRADE` or `SHOP_SCREEN_PANEL`; `nil` for no such shop
function GetShopScreen(shop) end

---What a shop pays for one item class, whatever its sell factor says.
---
---`price` is Groschen a piece for `item` (any key of the item catalogue), bought even when the
---shop buys nothing else (`sellFactor` `0`) or the item's category is not one it buys, and paid as it is - above the
---shop's own price too, if the mode wants it so; `0` = the shop never buys that class; `nil` takes the rule off (back to
---the factor). The Sell tab and the trade screen follow at once.
---@param shop number the shop
---@param item string|number the item's name, id, English name or GUID
---@param price number|nil Groschen a piece; `0` = never; `nil` = no rule
---@return boolean `false` for an unknown item or shop
function SetShopBuyPrice(shop, item, price) end

---What a shop pays for one piece of an item now.
---
---The price the rules give: the class's own (`SetShopBuyPrice`), else `sellFactor` of the catalogue price when the
---item's category is one the shop buys (`SetShopBuyCategories`) - but never more than the shop's own price when it
---sells the item too, so buying from a vendor and selling back to it never makes money.
---@param shop number the shop
---@param item string|number the item's key
---@return number Groschen a piece; `0` = the shop does not buy it
function GetShopBuyPrice(shop, item) end

---The item categories a shop buys at its sell factor.
---
---A list of the catalogue's categories (`GetItemInfo` `category`: `"MeleeWeapon"`, `"Armor"`, `"Food"`, `"Herb"` ...).
---The ones named are bought alone; a name with a leading minus is one the shop never buys (`{"-Document"}`: everything
---but papers). `nil` or `{}` = every category. The classes of `SetShopBuyPrice` are bought regardless. The Sell tab and
---the trade screen follow at once: the screen offers the vendor nothing else.
---@param shop number the shop
---@param categories table|nil a list of category names, `-` in front = never; `nil` = all
---@return boolean `false` for no such shop
function SetShopBuyCategories(shop, categories) end

---The item categories a shop buys at its sell factor.
---@param shop number the shop
---@return table the list as `SetShopBuyCategories` set it; `{}` = every category
function GetShopBuyCategories(shop) end

-- ======== Dialogue ==============================================================
-- A **dialogue** is a conversation a game mode holds with one player, one **page** at a time: who speaks, their line, and 1
-- to 8 **choices** for the player's answer, shown on their screen in the game's own conversation look - the line as the
-- game's subtitle ("Watchman: Halt! ..."), the choices in the game's list with its gold highlight - while their movement is
-- held. The player moves with W / S (or the arrows), picks with E, Enter or Space (or a row's number, 1-8) and leaves with
-- Esc; a greyed-out choice is skipped and cannot be picked. The usual start is an
-- NPC actor with a Talk prompt (`SetActorPrompt`) and `ShowPlayerDialogue` from
-- `OnPlayerInteractActor`; any command, zone or timer may open a page too.
-- 
-- Each page carries a number of the mode's choosing, `dialogid`, which comes back with the answer in
-- `OnDialogueResponse` - the SA-MP way. A pick closes the page unless the callback shows the next one, so a conversation
-- is a chain of pages the mode walks through. A choice may be shown greyed out (`enabled = false`): something the player
-- sees but cannot pick yet. With an actor the page closes when the player walks 5 m away from it, or it dies or goes;
-- a death or leaving the server closes it too, and the mode hears why.

---**Called by the server** - A player answered a dialogue page - the choice they picked, or 0 when it closed.
---
---`option` is the choice they picked, `1` for the top one. The page then closes unless this callback shows the next one
---with `ShowPlayerDialogue` - the conversation goes on without a flicker. `option` is `0` when the page closed without
---a pick: `reason` is `""` for the player's own close (Esc), else `"you walked away"` (5 m from the actor),
---`"the actor is gone"`, `"you died"` or `"you left"`. `HidePlayerDialogue` and a page replaced by the next do not
---come here.
---@param pid number the player
---@param dialogid number the page's number, as the mode gave it to `ShowPlayerDialogue`
---@param option number the choice picked, `1` for the top one; `0` = closed without a pick
---@param reason string why it closed when `option` is `0`; `""` = the player's own close, and always `""` for a pick
function OnDialogueResponse(pid, dialogid, option, reason) end

---Shows a dialogue page on a player's screen - who speaks, their line and the choices.
---
---Opens a page, or replaces the one open on the player. `options` is a list of 1 to 8 rows, top to bottom; a row is a
---string, or a table `{text = "...", enabled = false}` for a choice shown greyed out that cannot be picked. With
---`actor` the talk is with that actor: the speaker's name defaults to its name (pass `""`), and the
---page closes when the player walks 5 m from it or it dies or goes. The player's answer comes to
---`OnDialogueResponse` with `dialogid`. Texts are cut at 1000 characters for the line, 200 for a choice.
---@param pid number the player
---@param dialogid number the page's number, of the mode's choosing - it comes back with the answer
---@param speaker string the name over the line; `""` = the actor's name (or none)
---@param text string the speaker's line; `""` = the choices alone
---@param options table 1-8 rows - strings, or `{text = "...", enabled = false}`
---@param actor? number the actor spoken to; `nil` = none
---@return boolean ok `true`, or `false, reason` (`"a page needs at least one choice"`, `"the player is dead"` ...)
---@return string reason
function ShowPlayerDialogue(pid, dialogid, speaker, text, options, actor) end

---Closes the dialogue page open on a player.
---
---The page goes without an `OnDialogueResponse` call - the mode already knows why.
---@param pid number the player
---@return boolean `false` when no page was open
function HidePlayerDialogue(pid) end

---The number of the dialogue page open on a player's screen.
---@param pid number the player
---@return number the `dialogid` given to `ShowPlayerDialogue`; `nil` when none is open
function GetPlayerDialogue(pid) end

-- ======== Emotes ================================================================
-- A player's gesture for everyone around - a wave, a bow, a cheer, a dance. Players hold **G** for the emote wheel (the
-- mouse picks, letting go of G plays it; a quick tap leaves the wheel open for a click, the number keys pick directly) and
-- hold **T** to point - the arm stays out while T is down, and the player can walk meanwhile; the others see their body
-- make it and the player sees it in first person. The server checks every pick - the player alive, standing still on foot,
-- no weapon out, not fighting - and ends a looping one (the dance) when the player steps away, crouches, draws, mounts, is
-- hit or dies; a player who comes into view later still sees a dance, or a point held.
-- 
-- The built-in emotes: `wave`, `bow`, `cheer`, `clap`, `dance` (loops), `point` (the upper body alone: it plays while the
-- player walks or crouches; T holds it), `salute`, `come`, `nod`, `sit` (on the ground: the player sits down, stays seated
-- and stands up again when it ends), `armscrossed` (the arms folded until the player moves), `drink` (a gulp from a tankard, the
-- upper body alone - the one a sip from a tankard in the hands plays, `SetCarryItemDrink`, and the others see when a player
-- drinks from the bag). The wheel shows
-- `wave, bow, cheer, clap, dance, come` unless the `[emotes]` section of
-- server.toml names others - or `SetEmoteWheel` does; the owner's own emotes go
-- in `[emotes.custom]`, a mode's through `AddEmote`. `OnPlayerEmote` can refuse a pick, `PlayPlayerEmote` makes a
-- player perform one.
-- 
-- A chat command for them is the mode's: the server has none of its own. The shipped modes answer `/anim <name>`,
-- `/anim stop` and `/anim` (the list) with `PlayPlayerEmote`, `StopPlayerEmote` and `GetEmotes` - the example under
-- `PlayPlayerEmote` is the whole command, to copy under any name.

---**Called by the server** - A player picked an emote; return false to refuse it.
---
---A pick on the wheel or the point on T, asked after the server's own checks passed (an emote of the server's list, the
---player in the world and alive, standing still on foot, no weapon out, not fighting) and before anything plays.
---Returning `false` refuses it - nothing plays and the player is told nothing, so say why yourself; nothing, `nil` or
---`true` lets it play. `PlayPlayerEmote` - a mode's own command - does not come here.
---
---Return value: `false` refuses the emote
---@param pid number who picked it
---@param name string the emote ("wave", "dance" ...)
function OnPlayerEmote(pid, name) end

---The names of every emote this server knows.
---
---The built-in ones, the owner's `[emotes.custom]` and every `AddEmote`, sorted by name - what `PlayPlayerEmote` takes.
---@return table a list of names
function GetEmotes() end

---The emotes on the wheel, in its order (clockwise from the top).
---@return table a list of names; empty = no wheel
function GetEmoteWheel() end

---Puts other emotes on everyone's wheel.
---
---At most eight known names, clockwise from the top; an empty table takes the wheel away (G and T are then the game's
---own again; a mode's command still plays emotes). Every client gets the new wheel at once. `false`, and nothing changes, when a name is
---unknown or the list is too long. The start value is `[emotes] wheel` in server.toml.
---@param names table|string a list of emote names, or one comma-separated string
---@return boolean `false` when a name is unknown or there are more than eight
function SetEmoteWheel(names) end

---A new emote, or a new look for a known one.
---
---The body the others see plays `clip` - a clip of the game's male animation set, the names
---`SetActorAnim` takes (the animation lists) - and the player's own game plays `fragment`
---with `tags`: a Mannequin fragment of the player's animation database (the fragment families of the same lists,
---`GreetingsUpperBody`, `ApplauseHappy` ...; the tags pick a variant, `+`-joined). `loop` `true` plays it until the
---player moves or it is stopped, else once. `false` when a part will not do (the server's log says which). It is not on
---the wheel until `SetEmoteWheel` puts it there; `PlayPlayerEmote` (a mode's command) takes it at once.
---
---`opts` gives it more:
---
---- **an in and an out** - `inClip` / `inFragment` / `inTags` play once before the loop and `outClip` / `outFragment` /
---  `outTags` once when it ends, on every screen: sitting down and standing up, lying down and getting up. A player who
---  comes into view while it loops sees the loop at once.
---- **`upper = true`** - an upper-body gesture: `clip` plays on the upper body for everyone (the player's own game too),
---  and walking, running or crouching do not end it. With `loop` it loops there until stopped - hands tied behind the back
---  while the player walks; a whole-body clip works too (the legs keep walking under it). It needs no fragment and has no in
---  or out.
---- **`locked = true`** - only the mode ends it (`StopPlayerEmote`, another `PlayPlayerEmote`): the player's own keys,
---  a step away, a crouch, a drawn weapon, a fight or a hit no longer end it, and the player cannot pick another emote
---  meanwhile. A death, a respawn, a horse, a knock-out and being carried still end it - play it again after them if it
---  should last (`GetPlayerEmote` says whether it still plays). Pair a locked full-body one with
---  `TogglePlayerControllable` so the player cannot walk off in it.
---
---A whole-body emote with an in or an out, or a locked one, seats the player from the in to the end of the out: their view
---turns at most 60 degrees either way and the body keeps its heading (in third person the camera turns around it), and the
---walk, jump and crouch keys stand the player up instead of moving them - a locked one waits for the mode.
---
---The fragment's state must hold while the loop plays: a fragment that plays once and stops (a lie-down, a fall) as the
---loop shows it over and over on the player's own screen - give the loop a looping fragment (`WoundedLying_1`,
---`LyingInjured`, `SittingIdle` with its tags ...) and the one-shot as the in. A lying player's own first-person view
---lies with the head (hair across the view, or inside it): `SetPlayerThirdPerson` `"force"` while they lie shows them
---from beside the body.
---@param name string 1-24 of a-z, 0-9, `_` and `-`
---@param label string what the wheel shows (the name, capitalised, when empty)
---@param clip string the body's clip
---@param fragment string the player's own fragment
---@param tags? string its fragment tags (`""`)
---@param loop? boolean until stopped (`false` = once)
---@param opts? table any of `upper` (an upper-body gesture that walks along; `false`), `locked` (only the mode ends it; `false`), `inClip`, `inFragment`, `inTags` (played once before the loop), `outClip`, `outFragment`, `outTags` (played once when it ends)
---@return boolean
function AddEmote(name, label, clip, fragment, tags, loop, opts) end

---Makes a player perform an emote - the heart of an emote command.
---
---As if they had picked it on the wheel - the server's own rules still apply (in the world and alive, standing still on
---foot, no weapon out, not fighting, not knocked out, carried or carrying) but `OnPlayerEmote` is not asked. A new emote
---replaces the one playing. When it cannot play, the second value says why in words the player can read ("Stand still
---first.", "Put your weapon away first.", "Not while knocked out.", "Not while carrying.", "There is no emote 'juggle'
---here." ...), ready for the chat. A locked emote (`AddEmote`'s `opts.locked`) asks only that the player is in the world,
---alive, on foot, not knocked out and not carried or carrying.
---@param pid number the player
---@param name string the emote (any case)
---@return boolean ok `true`, or `false, reason` - the reason as the player reads it (`"Stand still first."`, `"There is no emote 'juggle' here."` ...)
---@return string reason
function PlayPlayerEmote(pid, name) end

---Ends a player's emote on every screen.
---@param pid number the player
---@return boolean `false` when none was playing
function StopPlayerEmote(pid) end

---The emote a player is making now.
---
---A looping one lasts until the player moves or it is stopped; one that plays once counts for a few seconds.
---@param pid number the player
---@return string the name, or `nil` when none plays
function GetPlayerEmote(pid) end

-- ======== Looks and character creation ==========================================
-- A player's **look** is the parts of the game's characters their body wears: the **skin** (`body`), the **face** (`head`),
-- the **hair** and its color, and the **beard**. Each part is named as the game names it - `m_body_tan_02`,
-- `m_head_004`, `m_hair_005_blonde`, `m_beard_03` - and `GetLookParts` lists what a man's body may wear, or a woman's
-- (the look parts are the same lists on paper). A look is a Lua table
-- `{body = ..., head = ..., hair = ..., beard = ...}`; a part left out is the one the body's soul gives it (the spawn's
-- `appearance`, `SetSpawnInfo`).
-- 
-- **A woman's body**: `gender = "female"` in the table (`"gender=female"` in the one-line form) makes the player a woman -
-- her own skeleton, her walk and her voice in combat - with a woman's face, hair and skin (`f_head_013`,
-- `f_hair_004_blonde`, `f_body_pale_01`; a woman has no beard). A look whose parts are all a woman's is a woman's without
-- saying so. The two bodies' parts never mix. Everything a man wears a woman may wear too, with its protection; the game
-- has no women's armour, so a woman's dress stands in for a man's clothes and armour on her body (its cut from what she
-- wears), his hoods and helmets are left off (her own hair and face show), his boots show as they are and his scabbards
-- without their waist belt.
-- 
-- **The rejoin on a new body**: a player's own game changes its own body only while the map loads. A player whose look
-- turns from a man's into a woman's (or back) while in the world - a new character made in the mode's creator, a look
-- changed later - is asked once to restart: the game closes, joins the same server again under the same name on the new
-- body and remembers it for that server, so every later visit loads on it at once. The others see the new body at once
-- and never restart. A new character's first visit always joins on a man's body (the game loads before the mode knows the
-- character), so a new woman is asked once, after her creation. The restart is the player's game's own; what a mode does
-- about it: it keeps the look, `gender` with it, in its own database and gives it back with `SetPlayerLook` at every
-- login (a player who rejoined as a woman and gets a man's look back is asked again); it gives the look as early as it
-- can - at the login, before the player plays - so the question comes at once; and it treats the rejoin as a plain leave
-- and join, `OnPlayerDisconnect` and then `OnPlayerConnect` with nothing to tell them apart: what the mode keeps (the
-- place, what the player carries, the horses) is saved on the leave as always, and a mode with its own login asks for it
-- again. The shipped `basicrp.lua` does all of this.
-- 
-- `SetPlayerLook` gives a player a look: everyone who sees them gets it at once, their own game too (their own body, the
-- inventory's figure), and it lasts through every respawn until the next call or the end of the visit. The server
-- remembers no look past a visit - a mode that keeps them saves the look in **its own database**: `LookToString` turns it
-- into one line for a text column and `SetPlayerLook` takes that line back. `SetActorLook` dresses an NPC actor's body
-- the same way.
-- 
-- **A character creation screen** is the mode's own: its client half draws the menu,
-- shows the choices on a preview body only the player sees (`ShowLookPreview`) and asks for the look it settles on
-- (`RequestLookChange`); the server checks the parts and hands the ask to `OnPlayerLookChange`, and the look is the
-- player's once the mode takes it. A mode without that callback takes no look from a player. The shipped `basicrp.lua`
-- has a whole creator: it opens for a new character and on `/look`, and keeps the look with the account. The
-- character creator guide walks through building one.

---**Called by the server** - A player asks for a new look; return false to refuse it.
---
---The player's game asked for a look - the mode's client half called `RequestLookChange`: a character creator's
---*done*, a barber's chair. The server has checked it first: every part one of its kind in the catalogue, all of them a
---man's or all a woman's (`look.gender` is `"female"` for a woman's body), and not more than one ask a second. Returning `false` refuses it and nothing changes (say why yourself); nothing, `nil` or
---`true` takes it - the look is the player's on every screen, as `SetPlayerLook` would make it. This is the place to
---save it.
---
---A mode that does not define this callback takes **no** look from a player: nobody changes their look on a server
---whose mode offers no way to.
---
---Return value: `false` refuses the look
---@param pid number who asks
---@param look table `{body, head, hair, beard, gender}` - the parts asked for (a part left out is the soul's own); `gender` is `"female"` for a woman's body, absent for a man's
function OnPlayerLookChange(pid, look) end

---Gives a player a look - the skin, the face, the hair and the beard - on every screen.
---
---`look` is a table `{body, head, hair, beard}` of part names (`GetLookParts`), or the one line `LookToString` makes -
---what a database column gave back. A part left out, or `""`, is the one the body's soul gives it; `{}` takes the
---whole look off. Everyone who sees the player gets the new look at once - the body changes in place, no respawn - and so
---does the player's own game; it lasts through every respawn until the next call. A look given before the spawn arrives
---with it.
---
---`gender = "female"` (or a look of a woman's parts alone) gives the player a woman's body: the others see her body at
---once; her own game shows it after she rejoins, which it asks her to do when her body changed while she was in the
---world. A look set before her spawn (a saved character, at login) needs no rejoin after the first time: her game
---remembers the body for the next visit to the server.
---
---Every part is checked against the game's lists: a name that is not a part of its kind, a woman's part on a man's body
---or a man's on a woman's, or a beard on a woman, refuses the whole look - `false` and the reason, worded for a player.
---Without the tables export (`[combat] tables` in server.toml) any word of
---letters, digits and `_` passes unchecked (a name starting `f_` counts as a woman's).
---@param pid number the player
---@param look table|string `{body, head, hair, beard, gender}`, or its one-line form
---@return boolean `true`, or `false` and the reason ("There is no hair 'x'.")
---@return string|nil
function SetPlayerLook(pid, look) end

---A player's look.
---
---The parts the player's body wears as the mode (or a look the mode took, `OnPlayerLookChange`) set them; a part the
---soul decides is absent from the table - `{}` when the player wears no look of the mode's. `gender` is `"female"` on
---a woman's look, absent on a man's.
---@param pid number the player
---@return table|nil `{body, head, hair, beard, gender}`, `nil` when not connected
function GetPlayerLook(pid) end

---Gives an NPC actor a look.
---
---The same as `SetPlayerLook` for an actor of `CreateActor`: the parts replace its soul's own on every client that
---sees it, at once and for every newcomer (a change between a man's body and a woman's makes the body anew). `false`
---and the reason when a part will not do, or the entity is no actor.
---@param id number the actor
---@param look table|string `{body, head, hair, beard, gender}`, or its one-line form
---@return boolean `true`, or `false` and the reason
---@return string|nil
function SetActorLook(id, look) end

---An NPC actor's look.
---@param id number the actor
---@return table|nil `{body, head, hair, beard, gender}` (`{}` when it wears its soul's), `nil` when the id is no actor
function GetActorLook(id) end

---The parts of one kind a man's look may name - or a woman's.
---
---`kind` is `"head"` (the face), `"hair"`, `"beard"` or `"body"` (the skin); `gender` `"female"` lists a woman's parts
---(there are no beards among them), anything else a man's. Every entry is a table: `name` (what a
---look takes), `style` (the part it derives from - a hair color's hair model, a head's variant's head, a skin tone's
---group - `""` at the top), `traits` (the words the game's own crowd matches a face, a skin, a hair and a beard by:
---`"Pale Ordinary Suntanned Posh YoungAdult"`) and `generic` (`true` for the plain parts the game gives its crowds - not
---a named character's, not a wound's). `pattern` keeps the parts whose name, style or traits hold every word of it:
---`"generic"`, `"blonde"`, `"Pale"`, a hair model's name for its colors.
---
---Some names are worth knowing: `x_hair_20` is no hair (a bald head), `m_beard_00` no beard, `m_hair_barber_01` to
---`_16` and `UC_beard_barber_01` to `_08` the barber's styles. Empty without the tables export.
---@param kind string `"head"`, `"hair"`, `"beard"` or `"body"`
---@param pattern? string words every part must hold
---@param gender? string `"female"` for a woman's parts; a man's by default
---@return table a list of `{name, style, traits, generic}` in the game's order
function GetLookParts(kind, pattern, gender) end

---What a part name is.
---@param name string a part's name
---@return table|nil `{kind, name, gender, style, traits, generic}` (gender `"m"` / `"f"`), `nil` when unknown
function GetLookPartInfo(name) end

---A look as one line - what a database column keeps.
---
---`"body=m_body_tan_02;head=m_head_004;hair=m_hair_005_blonde;beard=m_beard_03"`, the parts left out missing from it,
---`""` for no look at all; a woman's starts with `gender=female;`. `SetPlayerLook`, `SetActorLook` and
---`LookFromString` take the line back; a player's client half has the same pair, so the line may travel in a script
---event too.
---@param look table|string a look
---@return string the one-line form
function LookToString(look) end

---A look's one line back into its table.
---
---`kind=name` pairs separated by `;` (or `,` or spaces), in any order; a pair of another kind is skipped. `""` is `{}`.
---`gender=female` (or `woman`) sets `gender = "female"`.
---@param text string the one-line form
---@return table `{body, head, hair, beard, gender}`
function LookFromString(text) end

-- ======== Dice ==================================================================
-- The game's own dice game between two players - the tables in the taverns, the dice, the keys, the scoring and the
-- animations of single player. Two players stand together at a dice table; the mode starts a match with
-- `StartDiceMatch` (the shipped modes answer `/dice <name> [bet]` and `/dice accept`), and both games walk their player to
-- the table and seat the other across it. Each player plays on their own screen: the throw is automatic, they pick their
-- dice and press **F** to score and throw the rest, or **Q** to score and pass; the other player's picks appear one by one
-- on the other side of the table. The challenger throws first.
-- 
-- The server keeps the two games the same and fair: it deals every throw, checks every move against the game's scoring,
-- keeps the totals and holds the stakes - the bet leaves both purses when the match starts and the winner takes both.
-- A match ends when a player reaches the goal on a pass ("goal"), gives up (**Esc** in the game, "gave up"), leaves
-- ("left"), dies ("died") or lets a move wait longer than the match's turn timeout ("timeout", `StartDiceMatch`) -
-- that player loses. A match is called off and the
-- stakes go back when a fight breaks out, a player walks away or rides off, a game could not set the table up ("failed" -
-- no dice table near the two players) or a move does not fit the dice ("out of step"). `OnDiceMatchEnd` hears every
-- ending.
-- 
-- The game type sets the goal: `0` the beggar's game (1500 points), `1` the wagoner's (2000), `5` the craftsman's (3000),
-- `9` the courtier's (4000) - the ones played without badges; the players' own dice are not used yet (every throw is a
-- fair one of plain dice).
-- 
-- The rules are the mode's, not the server's: there is nothing about dice in `server.toml`. Whether players may play at
-- all, the goal, how long a move may take and how far apart the two may stand at the start are what the mode passes to
-- `StartDiceMatch` - the shipped modes keep them in a `DICE` table at the top of their dice command, for the owner to
-- change.
-- 
-- Scoring, as the game counts it: a single one 100, a single five 50; one to five 500, two to six 750, one to six 1500;
-- three of a kind 1000 for ones and the face times 100 for the others, and every further die of the kind doubles it. Only
-- dice that score can be kept, and a throw with none is a bust - the points of that turn are lost.

---**Called by the server** - A dice match started.
---
---After `StartDiceMatch`: the stakes have left both purses and both games are on their way to the table.
---@param id number the match
---@param challenger number the player who asked for it (they throw first)
---@param opponent number the other player
---@param bet number each player's stake in Groschen (0 = none)
---@param goal number the points that win
function OnDiceMatchStart(id, challenger, opponent, bet, goal) end

---**Called by the server** - A dice match ended - who won, or why it was called off.
---
---The stakes have moved already: the winner holds both, a match called off gave each player theirs back. `reason` is
---`"goal"`, `"gave up"`, `"left"`, `"died"` or `"timeout"` when a player won, and `"a fight"`, `"walked away"`,
---`"failed"`, `"out of step"` or `"the mode"` (an `EndDiceMatch` without a winner) when it was called off. A player who
---leaves the server is still one here: the match ends before `OnPlayerDisconnect`.
---@param id number the match
---@param challenger number the player who asked for it
---@param opponent number the other player
---@param winner number the winner, `-1` when the match was called off
---@param reason string how it ended (above)
---@param bet number each player's stake in Groschen
function OnDiceMatchEnd(id, challenger, opponent, winner, reason, bet) end

---Starts a match of the game's dice game between two players - the heart of a dice command.
---
---The two must stand together at a dice table (within `range` metres of each other; the games look for the table
---nearest the challenger), in the world, alive, on foot, not fighting, not at a shop, not knocked out, not carrying or carried
---(`SetPlayerKnockedOut`, `CarryPlayer`) and not playing already, and both
---must have the stake in their purse - the money the server's records explain (`GetPlayerMoney`); under `[audit] mode =
---"enforce"` and with a stake above 0, a player in the first seconds of a visit, before the server follows their bag, is turned
---down with "Henry's items are still being checked." (a match with no stake is not held back). The stake leaves both purses at
---once and goes to the winner at the end. When it cannot start, the second value says why in words the player can read ("Hans
---is too far away - stand together at a dice table.", "Henry cannot cover the bet of 50 Groschen." ...), ready for the chat. A
---game type with badges or a rule out of its bounds is refused the same way, with a reason meant for you ("The turn timeout
---must be 5 to 3600 seconds.").
---@param challenger number the player who asks - they throw first
---@param opponent number the other player
---@param bet number each player's stake in Groschen; 0 or `nil` for none
---@param gameType number `0` beggar (1500 points, the default), `1` wagoner (2000), `5` craftsman (3000), `9` courtier (4000)
---@param turnTimeout number seconds a player may take for one move before losing the match; `nil` for 90 (5 to 3600)
---@param range number metres the two may stand apart when the match starts; `nil` for 4 (0.5 to 8)
function StartDiceMatch(challenger, opponent, bet, gameType, turnTimeout, range) end

---Ends a running dice match, with a winner or without one.
---
---The winner takes both stakes; without one the match is called off and each player gets theirs back. Both games end
---too. `OnDiceMatchEnd` hears it with the reason `"the mode"`.
---@param id number the match
---@param winner number one of its two players, or `nil` to call it off
---@return boolean `false` when the match is over already
function EndDiceMatch(id, winner) end

---The dice match a player is in.
---@param pid number the player
function GetPlayerDiceMatch(pid) end

---The state of a running dice match - the players, the stake, the goal, the totals, whose turn it is.
---@param id number the match
---@return table `{id, challenger, opponent, bet, goal, gameType, challengerScore, opponentScore, turn, turnTimeout}` (`turn` = the player to move, `turnTimeout` = the seconds a move may take), or `nil` once it is over
function GetDiceMatchInfo(id) end

-- ======== Carry items ===========================================================
-- Things carried in the hands the way the game's own people carry them - a sack on the shoulder, a basket in both hands, a
-- bucket, a crate - with the game's own pickup, its carry walk and its put-down, and every player who has the carrier in view
-- sees the same. A carry item is a world entity of kind `ENTITY_CARRY`: it lies in the world where the mode made it
-- (`CreateCarryItem`) or where a player put it down, until someone picks it up. It is nobody's property and it never enters an
-- inventory.
-- 
-- **The players' own pickup is off until a mode switches it on** (`SetItemCarrying`): then a carry item shows the game's "Pick up"
-- prompt to a player within reach whose hands are free, and the mode has the last word on each (`OnPlayerPickUpCarryItem`). The
-- mode's own orders - `PickUpCarryItem`, `GivePlayerCarryItem` - work either way.
-- 
-- One item per player, one player per item. Sacks, baskets, buckets and jugs are carried with the game's own carry: he walks (no
-- running or sprinting with a sack or a basket), his hands are busy - no weapon, no doors, no horse - and the game's put-down key
-- (the use key) lays the item down in front of him, or greys out where there is no room. Everything else - a crate, a tool, a
-- lantern, the torch tool, a tankard or a stein - goes straight into his hands the way the game's people hold it (a lantern in the
-- left; a tankard or a stein with the game's own reach for it and set it down, the rest with no pickup animation), and **holding the
-- use key a moment** puts the item down in front of him.
-- A carry item can be any item of the game, but the ones made to be carried or held look right: the sacks
-- (`mlynaruvUcen_sackcarryable`, `kejkliri_sackcarryable`, `sack_miller` ...), the baskets (`basket_b_apples`, `basket_b_bread`,
-- `laundryBasket`, `basket_full_wood` ...), the buckets (`waterBucket`, `milkBucket`), the `crate_with_silver`, the tools
-- (`shovel`, `lumberjack_axe`, `normalHammer`, `fishing_rod`), the jugs, tankards and steins (`jug_pewter_small_copper`,
-- `wooden_tankard`, `wooden_stein`) and the lanterns (`lamp_tool`, `lamp_toolFancy`, `torch_tool`). A `barrel`, a `pitchfork` or a `broom` does not: no
-- animation of the game's holds one well while walking.
-- 
-- The carry ends when the carrier puts the item down, when the game knocks it out of his hands, when the mode says so
-- (`DropPlayerCarryItem`, `TakePlayerCarryItem`), or on anything the server does to him: a death, a disconnect, a teleport
-- (`SetPlayerPos`), a respawn, a ride (`MountPlayer`), a cart seat, a flight (`SetPlayerFlying`), a knock-out, another virtual
-- world - then the item drops where he stood. A pickup that never finishes is cut after eight seconds. `OnPlayerPutDownCarryItem`
-- says why it ended and where the item lies. A player whose game cannot carry things (an older build) is never given one.
-- 
-- **Reserved state keys.** The prompt is shown through the world state key `carryitems` (`"1"` while `SetItemCarrying` is on) and
-- the entity state key `carry` (`"0"` on an item `SetEntityCarryable` took out of the prompt). Do not set them with
-- `SetGlobalState` or `SetEntityState` yourself. A mode reload (`ReloadGameMode`) switches the pickup off again with the
-- default rules; an item in someone's hands stays there.

---**Called by the server** - A player reaches for a carry item with the "Pick up" prompt - return `false` to refuse.
---
---Only while the players' own pickup is on (`SetItemCarrying`). The server has checked that the player sees the item, stands
---within reach (and in the open, when `[validation] line_of_sight` is on), has his hands free and that nobody else holds it; the
---mode has the last word. Returning `false` stops the pickup - the player is told he cannot pick it up - anything else lets it
---start. Not run for the mode's own orders (`PickUpCarryItem`, `GivePlayerCarryItem`).
---
---Return value: `false` refuses the pickup; nothing, `nil` or `true` lets it start
---@param pid number the player who reaches for it
---@param id number the carry item's entity id
---@param item string the item's name (`"waterBucket"` ...), or its class GUID when the server's item table does not name it
function OnPlayerPickUpCarryItem(pid, id, item) end

---**Called by the server** - A carry item left a player's hands - it lies at `x, y, z`.
---
---`reason` is one of: `"put down"` (the carrier's own put), `"broken off"` (the game knocked it out of his hands), `"failed"` (his
---game could not pick it up; it lies where it was), `"mode"` (`DropPlayerCarryItem`, or the mode did something to him),
---`"timeout"` (a pickup that never finished), `"died"`, `"left"`, `"moved"` (`SetPlayerPos`), `"respawned"`,
---`"another world"`, `"mounted"`, `"cart"`, `"flying"` or `"knocked out"`. After a put the item lies where the carrier's game laid
---it as long as that is within three metres of him and on his level; after anything the server did to him it lies where he
---stood. An item taken away (`TakePlayerCarryItem`, `DestroyEntity`) is gone: no call.
---@param pid number the carrier
---@param id number the carry item's entity id
---@param item string the item's name, or its class GUID
---@param reason string why it ended
---@param x number metres - where the item lies
---@param y number metres
---@param z number metres
function OnPlayerPutDownCarryItem(pid, id, item, reason, x, y, z) end

---Switches the players' own pickup of carry items on or off, with its rules.
---
---On, a carry item shows the game's "Pick up" prompt to a player within reach whose hands are free, and his ask is checked (the
---reach, that nobody else holds it, `OnPlayerPickUpCarryItem`). **Off by default.** A carry that runs goes on when it is switched
---off; the mode's own orders (`PickUpCarryItem`, `GivePlayerCarryItem`) do not need it.
---
---`rules` is a table, every key optional: `range` (metres a player may stand from the item when he reaches for it, `2.5`; held at
---`4` at the most - a player's ask is checked against the range plus a metre, because the games' positions are a few frames old).
---Without `rules` the earlier ones stay; a `rules` table that leaves a key out puts that key back to its default. A mode reload
---(`ReloadGameMode`) switches the pickup off again and resets the rules. The world state key `carryitems` is the server's - this
---call writes it.
---@param enabled boolean `true` shows the prompt and answers asks; `false` (the default) takes it away
---@param rules? table `{range}` - how far a player may reach
function SetItemCarrying(enabled, rules) end

---Whether the players' own pickup of carry items is on, and its rules.
---@return boolean `enabled`, and the rules table - `{range}`, the defaults until `SetItemCarrying` gave others
---@return table
function GetItemCarrying() end

---Lays a carry item in the world - a sack, a basket, a bucket to be picked up and carried.
---
---`item` is an item of the game - its name (`"waterBucket"`), id or class GUID; the ones made to be carried look right (see the
---group's description). The item lies at `x, y, z` facing `yaw` (degrees) on every screen that has it in view, the way a dropped
---item lies: it settles on the ground below the point. `world` is the virtual world it is in (`nil` or `-1` = the default world,
---`0`). It stays until someone carries it off, the mode removes it (`DestroyEntity`) or the server restarts.
---@param item string the item's name, id or class GUID
---@param x number metres
---@param y number metres
---@param z number metres - it falls to the ground below the point
---@param yaw? number degrees, the way it faces
---@param world? number the virtual world; `-1` (the default) = world 0
---@return number|nil the new entity's id; `nil` when the item is unknown or the world is full
function CreateCarryItem(item, x, y, z, yaw, world) end

---Has a player pick up a carry item - the mode's own order.
---
---The player's game plays the pickup and the carry, and everyone who has him in view sees it. Works with the players' own pickup
---switched off; `OnPlayerPickUpCarryItem` is not asked. Without `atOnce` the item must lie within six metres of him and in his
---view; with `atOnce` it goes into his hands wherever it lies (the other players see it in his hands at once).
---
---`false` and the reason ("You are carrying something already.", "Someone else has it." ...) when the player is dead, not in the
---world or in another virtual world than the item; when he is on horseback, in a cart, flying, in a dice match, in a fall or a
---pull-down, knocked out, carrying or carried, in a fight, at a shop or in a dialogue; when he holds a carry item already or
---someone else holds this one; when it is too far; or when his game cannot carry things (an older build).
---@param pid number the player
---@param entityId number the carry item (`CreateCarryItem`)
---@param atOnce? boolean `true`: straight into his hands, wherever it lies
---@return boolean `true` when the pickup started; `false` and the reason when it did not
---@return string
function PickUpCarryItem(pid, entityId, atOnce) end

---Makes a new carry item and puts it in a player's hands.
---
---The item (as in `CreateCarryItem`) is made at the player's feet - half a metre in front of him, or right where he stands with
---`atOnce` - and he picks it up at once, the mode's own order (`PickUpCarryItem`'s checks, without the reach). `nil` and the
---reason when the item is unknown or he cannot carry it now (the new item is removed again then).
---@param pid number the player
---@param item string the item's name, id or class GUID
---@param atOnce? boolean `true`: the other players see it in his hands at once
---@return number|nil the new item's entity id; `nil` and the reason when none was given
---@return string
function GivePlayerCarryItem(pid, item, atOnce) end

---Makes a player let go of what he carries - at once, where the mode says.
---
---The item leaves his hands on every screen at once (no put-down animation) and lies at `x, y, z` - or, without a place, a step
---in front of him (at his feet when a wall is there). `OnPlayerPutDownCarryItem` follows with the reason `"mode"`. `false` when
---he carries nothing.
---@param pid number the carrier
---@param x? number metres - where it lies; all three or none
---@param y? number metres
---@param z? number metres
---@return boolean `true` when he let go of something
function DropPlayerCarryItem(pid, x, y, z) end

---Takes away what a player carries, for good.
---
---The item leaves his hands on every screen and is removed from the world (the same as `DestroyEntity` on it). No
---`OnPlayerPutDownCarryItem` follows. `false` when he carries nothing.
---@param pid number the carrier
---@return boolean `true` when something was taken
function TakePlayerCarryItem(pid) end

---What a player carries in his hands, if anything.
---@param pid number the player
---@return number the carry item's entity id and its item's name (or class GUID) - from the moment his pickup starts; `nil` when he carries none
---@return string|nil
function GetPlayerCarryItem(pid) end

---Who holds a carry item, if anyone.
---@param entityId number the carry item
---@return number|nil the player holding it (or reaching for it); `nil` when it lies in the world
function GetCarryItemHolder(entityId) end

---Fills a tankard or a stein - what a sip from it gives and how many sips are left.
---
---A player holding a tankard or a stein drinks from it with the left mouse button: the game's drinking animation plays
---on every screen and the sip is a use of `item` as the inventory's would be - `OnPlayerUseItem` decides (`false` refuses
---it), its alcohol and health apply, so a few sips of beer get the drinker drunk. One sip at a time - about five and a half
---seconds apart, the drinking animation's length; a press sooner does nothing. By default a tankard or a stein holds
---4 sips of beer; any other carry item holds nothing and cannot be filled. `sips` `-1` never empties, `0` is empty (the
---player is told "It is empty."); `item` `""` takes the drink away. `false` for an entity that is no tankard or stein (a carry item
---of the `wooden_tankard` or `wooden_stein` classes) or an item the catalogue does not know.
---@param entityId number the carry item
---@param item string the drink - an item of the catalogue (`"beer"`, `"wine"`, `"mead"`, a GUID); `""` none
---@param sips number the sips in it; `-1` endless
---@return boolean
function SetCarryItemDrink(entityId, item, sips) end

---What a carry item holds to drink.
---@param entityId number the carry item
---@return string the drink's item class (`""` none) and the sips left (`-1` endless)
---@return number
function GetCarryItemDrink(entityId) end

-- ======== Carrying ==============================================================
-- The game's own grab, carry and put-down: a player - or an NPC actor the mode makes - takes a body that lies down over the
-- shoulder, walks with it and puts it down, and every player who has both bodies sees the same. The body can be a character
-- that lies dead (an NPC actor's, or a dead player's when `[combat] corpse_seconds` keeps it), a **knocked-out** player
-- (`SetPlayerKnockedOut`) or a knocked-out NPC actor (`SetActorKnockedOut`); a mode can also have any player or actor carried
-- (`CarryPlayer`, `CarryEntity`), who then shows knocked out for the carry and wakes after it. A new guide walks through it:
-- Knocking a player out and carrying them.
-- 
-- **The players' own grab is off until a mode switches it on** (`SetCarrying`): then the game's "grab" prompt shows on a body
-- that lies down, within reach, as far as the rules allow, and the mode has the last word on each (`OnPlayerCarry`). The mode's
-- own orders - `CarryPlayer`, `CarryEntity`, `ActorCarryEntity`, `ActorCarryPlayer` - work either way.
-- 
-- One carry per carrier, one carrier per body. The carrier's pace is held to the carry's speed (a quarter above it is allowed:
-- the games' positions are a few frames old) and he cannot sprint, jump, fight, ride, take a cart seat, make an emote or start a
-- dice match; a carried player's own game is carried by the carrier's body, so the server does not judge his position meanwhile,
-- and he cannot fight or act. After the put his first moments - his game puts him down a metre or two from where the server has
-- him - pass the movement checks within four metres, for three seconds.
-- 
-- A carry ends when the carrier puts the body down, when the game breaks it off (a blow on the carrier), when `StopCarry` says so,
-- or on anything the server does to one of the two: a death, a disconnect, a teleport (`SetPlayerPos`), a respawn, a ride
-- (`MountPlayer`), a cart seat (`PutPlayerInCart`), a flight (`SetPlayerFlying`), another virtual world
-- (`SetPlayerVirtualWorld`, `SetEntityVirtualWorld`), the body or the carrying actor removed (`DestroyEntity`) - then every
-- screen lets go at once. A grab or a put that never finishes is cut after eight seconds. `OnPlayerCarryEnd` says why. A put
-- ordered while the grab still goes on (`StopCarry`) waits for the grab to finish, then plays. A body the game could not grab
-- stays where it lay. Where a carrier puts a body down is the game's own put as long as it lies within a few metres of him, on
-- his level, on the ground and not behind a wall; otherwise the server lays it a step ahead of him. A player's game that cannot
-- carry (an older or unsupported build) takes no part in a carry: the server starts nothing with it. A dead player's corpse
-- (`corpse_seconds`) is a body like any other: it is carried, searched where it lies after the put, and it goes when its time
-- runs out. The server keeps at most two corpses of one player, and a quarter of `[world] max_entities` in all, as bodies that can
-- be carried - a new one past a limit takes the oldest one's place - so that nobody can fill the world's entity table with
-- them.
-- 
-- A knocked-out player's health stays as it is; they drop, their screen goes dark, they cannot fight, ride, act, make an emote or
-- start a dice match, and they are carried the way a corpse is. The knock-out ends when its timer runs out, when the mode says so,
-- or with a death, a disconnect or a respawn (`OnPlayerWake`).
-- 
-- **Reserved state keys.** The grab's prompt is shown through two state keys the server writes: the world state `carry` (`"1"`
-- while `SetCarrying` is on, cleared when it is off) and the entity state `carry` (`"0"` on a body `SetEntityCarryable` took
-- out of the grab). Do not set `carry` with `SetGlobalState` or `SetEntityState` yourself - the next `SetCarrying` or
-- `SetEntityCarryable` overwrites it, and a `"1"` with the grab off shows a prompt that every ask then refuses. A mode
-- reload (`ReloadGameMode`) takes the grab down with the old mode: it is off with the default rules and every body is
-- carryable again until the new mode's `OnGameModeInit` calls `SetCarrying` (a carry that runs goes on).

---**Called by the server** - A player reaches for a body with the game's grab - return `false` to refuse.
---
---Only while the players' own grab is on (`SetCarrying`). The server has checked that the player has the body in view and
---within reach (and in the open, when `[validation] line_of_sight` is on), that the rules allow this kind of body and that nobody
---else has it; the mode has the last word. Returning `false` stops the grab - the player is told they cannot carry it - anything
---else lets it start. Not run for the mode's own orders (`CarryPlayer`, `CarryEntity`).
---
---`kind` is `"player"` (a knocked-out player; `id` is their player id), `"corpse"` (a body that lies dead; `id` is the entity id)
---or `"actor"` (a knocked-out NPC actor; `id` is the entity id). `victim` is the player id of the dead player a corpse was, `-1`
---for anyone else - or a player who has left.
---
---Return value: `false` refuses the grab; nothing, `nil` or `true` lets it start
---@param pid number the player who reaches for it
---@param kind string `"player"`, `"corpse"` or `"actor"`
---@param id number the player's id, or the entity id
---@param victim number the player a corpse was; `-1` otherwise
function OnPlayerCarry(pid, kind, id, victim) end

---**Called by the server** - A player began carrying a body - the grab starts.
---
---After the grab was allowed (or ordered): the carrier's game plays the grab, which takes about three seconds, then the carry.
---Not run for a carry an NPC actor makes (`ActorCarryEntity`) - poll `GetEntityCarrier` for those. `kind` and `id` are as in `OnPlayerCarry`.
---@param pid number the carrier
---@param kind string `"player"`, `"corpse"` or `"actor"`
---@param id number the player's id, or the entity id
function OnPlayerCarryStart(pid, kind, id) end

---**Called by the server** - A carry is over - the body lies at `x, y, z`.
---
---`reason` is one of: `"put down"` (the carrier's own put), `"mode"` (`StopCarry`, or the mode knocked the carrier out),
---`"hit"` (the game broke the carry off - a blow on the carrier), `"failed"` (the carrier's game could not take the body),
---`"timeout"` (a grab or a put that never finished), `"carrier died"`, `"target died"` (a carried player or actor), `"carrier left"`,
---`"target left"`, `"moved"` (the server moved one of them - `SetPlayerPos` - or put one of them in another virtual world -
---`SetPlayerVirtualWorld`, `SetEntityVirtualWorld`), `"respawned"`, `"mounted"`, `"cart"`, `"flying"`, or
---`"destroyed"` (the body, or the actor that carried it, was removed). Every reason but `"put down"`, `"hit"`, `"failed"` and `"mode"`
---from a put is a forced end: the screens let go at once.
---
---A player put down by the carry has a short allowance after it for the games' own put (see the group's description); a
---body that is an entity lies at `x, y, z` for everyone, and a dead player's corpse is searched there. When the server put
---the body nowhere itself - `"failed"` (the body was never lifted), or the server moved the carried player (`"moved"`,
---`"respawned"`, `"mounted"`, `"cart"`) or lost the body (`"target left"`, `"destroyed"`) - `x, y, z` is the place the server's
---record has it at that moment: for a player the server moves, the place he is moved *from*. Not run for a carry an NPC actor
---makes.
---@param pid number the carrier
---@param kind string `"player"`, `"corpse"` or `"actor"`
---@param id number the player's id, or the entity id
---@param reason string why it ended
---@param x number metres - where the body lies
---@param y number metres
---@param z number metres
function OnPlayerCarryEnd(pid, kind, id, reason, x, y, z) end

---**Called by the server** - The player was knocked out.
---
---After `SetPlayerKnockedOut` (also a second call that only sets the timer anew does not run it again). A carry the player made
---ends first (`OnPlayerCarryEnd` with `"mode"`).
---@param pid number the player
function OnPlayerKnockedOut(pid) end

---**Called by the server** - The player is no longer knocked out.
---
---`reason` is `"woke"` (the timer ran out), `"mode"` (`SetPlayerKnockedOut` with `false`), `"died"`, `"left"` (the player is
---still a player in this callback, the goodbye follows) or `"respawned"`. A player woken while somebody carries them stays
---carried and is up after the put.
---@param pid number the player
---@param reason string `"woke"`, `"mode"`, `"died"`, `"left"` or `"respawned"`
function OnPlayerWake(pid, reason) end

---Switches the players' own grab on or off, with its rules.
---
---On, the game's "grab" prompt shows on a body that lies down - a dead character's, a knocked-out player's or actor's, as the
---rules allow - and a player's ask is checked (the reach, that nobody else has the body, `OnPlayerCarry`). **Off by default.**
---A carry that runs goes on when it is switched off; the mode's own orders (`CarryPlayer`, `CarryEntity`, `ActorCarryEntity`,
---`ActorCarryPlayer`) do not need it.
---
---`rules` is a table, every key optional: `range` (metres a player may stand from the body when they reach for it, `3`; a value
---is held between `0.5` and `6`, and a player's own ask is checked against the range plus a metre - `7` at the most - because the
---games' positions are a few frames old), `speed` (the carrier's pace in metres per second, `2.4`; held between `0.5` and `4`),
---`corpses` (the prompt works on a dead body, `true`), `players` (on a knocked-out player, `true`), `actors` (on a knocked-out NPC
---actor, `true`). Without `rules` the earlier ones stay. **A `rules` table that leaves a key out puts that key back to its
---default**, not to what an earlier call set: pass every rule you want to keep each time.
---
---A mode reload (`ReloadGameMode`) switches the grab off again and resets the rules: the new mode's `OnGameModeInit` sets what it
---wants. The world state key `carry` is the server's (see the group's description) - this call writes it.
---@param enabled boolean `true` shows the prompt and answers asks; `false` (the default) takes it away
---@param rules? table `{range, speed, corpses, players, actors}` - what the grab takes and how fast the carrier walks
function SetCarrying(enabled, rules) end

---Whether the players' own grab is on, and its rules.
---@return boolean `enabled`, and the rules table - `{range, speed, corpses, players, actors}`, the defaults until `SetCarrying` gave others
---@return table
function GetCarrying() end

---Has a player carry another player over the shoulder - the mode's own order.
---
---The carrier's game plays the grab and the carry, the target's game is carried by the carrier's body, and everyone who has both
---bodies sees it. The target need not be knocked out: they show knocked out for the carry and wake after it - unless the mode
---knocked them out (`SetPlayerKnockedOut`), then they stay down. Works with the players' own grab switched off. `speed` is the
---carrier's pace in metres per second (`nil` or `0` = the rules' of `SetCarrying`, `2.4` by default; any other number is held between `0.3` and `4`).
---`OnPlayerCarryStart` follows; `OnPlayerCarry` is not asked.
---
---`false` and the reason ("Hans is too far away (8.2 m; 6 m at most).", "Hans is on horseback." ...) when either player is dead,
---not standing in the world or in another virtual world; when either is on horseback, in a cart, flying, in a dice match, in a
---fall or a pull-down, or already carrying or carried; when the carrier is also knocked out, in a fight, at a shop or in a
---dialogue; when they are more than six metres apart or cannot see each other yet; or when a player's game cannot take part (an
---older build).
---@param carrier number the player who carries
---@param target number the player who is carried
---@param speed? number the carrier's pace in m/s; `nil` = the rules' speed
---@return boolean `true` when the grab started; `false` and the reason when it did not
---@return string
function CarryPlayer(carrier, target, speed) end

---Has a player carry an NPC actor's body - or a dead player's corpse - the mode's own order.
---
---`id` is the entity: an NPC actor (`CreateActor`) - dead or alive; a living one shows knocked out for the carry and wakes after
---it, unless the mode knocked it out (`SetActorKnockedOut`) - or the entity of a dead player's corpse (the body that stays when
---`[combat] corpse_seconds` is above 0; a corpse's entity id is the `entityId` the server logs, and shows in `GetEntities` as an
---NPC). The carrier is checked as in `CarryPlayer` (dead or not in the world, on horseback, in a cart, flying, in a dice match,
---in a fall or a pull-down, knocked out, already carrying or carried, in a fight, at a shop, in a dialogue) and the speed is
---`CarryPlayer`'s too. The body must be in the carrier's virtual world and view, within six metres, and not carried, carrying,
---seated on a cart or (a corpse) being searched; an animal cannot be carried. Works with the players' own grab switched off.
---@param carrier number the player who carries
---@param id number the entity
---@param speed? number the carrier's pace in m/s; `nil` = the rules' speed
---@return boolean `true` when the grab started; `false` and the reason when it did not
---@return string
function CarryEntity(carrier, id, speed) end

---Puts down the carry of a player - the carrier or the carried one.
---
---`pid` is either party - the carrier or the carried player - and **which one may order it is the mode's to decide**: a
---command that lets players put down what they carry should check `IsPlayerCarrying` first, or the carried player ends his
---own carry by typing it. The carrier's game plays the put-down (about two seconds), and the body lies where the game puts it - or
---at `x, y, z` (and `yaw`, degrees - which counts only together with `x, y, z`, with `immediate` too) when they are given;
---`OnPlayerCarryEnd` follows with `"mode"`. A put ordered while the
---grab still goes on (the first three seconds) waits for it to finish, then plays. With `immediate` the carry ends now, with no
---animation, the body at the place given or a step ahead of the carrier. `false` when `pid` is neither carrying nor carried.
---@param pid number the carrier, or the carried player
---@param x? number metres - where the body is to lie
---@param y? number metres
---@param z? number metres
---@param yaw? number degrees - the body's heading there; used only together with `x, y, z`, ignored alone
---@param immediate? boolean `true` to end it at once, without the put-down
---@return boolean `false` when there was no carry to stop
function StopCarry(pid, x, y, z, yaw, immediate) end

---Whether the player carries a body or another player.
---@param pid number the player
---@return boolean `true` from the start of the grab to the end of the put-down
function IsPlayerCarrying(pid) end

---Whether another player or an NPC actor carries the player.
---@param pid number the player
---@return boolean
function IsPlayerCarried(pid) end

---Whom or what the player carries.
---@param pid number the carrier
---@return string the kind - `"player"`, `"corpse"` or `"actor"` - and the id (a player's id, or the entity id); `nil` when they carry nothing
---@return number
function GetPlayerCarrying(pid) end

---Who carries the player.
---@param pid number the carried player
---@return string the kind - `"player"` or `"actor"` - and the id (a player's id, or the entity id); `nil` when nobody carries them
---@return number
function GetPlayerCarriedBy(pid) end

---Who carries the body.
---@param id number the entity - a body, or an NPC actor
---@return string the kind - `"player"` or `"actor"` - and the id (a player's id, or the entity id); `nil` when nobody carries it
---@return number
function GetEntityCarrier(id) end

---Takes a body out of the players' grab, or puts it back.
---
---With `false` the game's "grab" prompt does not show on this entity and a player's ask for it is refused - the mode's own orders
---(`CarryEntity`, `ActorCarryEntity`) still carry it. The default is `true` (as far as the rules of `SetCarrying` allow).
---It lasts as long as the entity does, or until a mode reload (`ReloadGameMode`). The entity's state key `carry` is the
---server's (see the group's description).
---@param id number the entity
---@param enabled? boolean `false` takes it out of the grab, `true` (the default) puts it back
---@return boolean `false` when there is no such entity
function SetEntityCarryable(id, enabled) end

---Has an NPC actor carry a body - a guard dragging a corpse.
---
---The actor stands still for the grab (about three seconds - `MoveActor` answers `false` meanwhile), then carries: walk it with
---`MoveActor` and the body goes with it. `ActorPutDown` puts it down. The same body rules as `CarryEntity`; works with the
---players' own grab off. No callback tells an actor's carry - poll `GetEntityCarrier`. `false` when `actorId` is not a standing
---NPC actor, or either is busy.
---@param actorId number the NPC actor that carries
---@param entityId number the body, or the NPC actor, it carries
---@return boolean `true` when the grab started
function ActorCarryEntity(actorId, entityId) end

---Has an NPC actor carry a player.
---
---The player shows knocked out for the carry and wakes after it, unless the mode knocked them out (`SetPlayerKnockedOut`). The same rules as
---`CarryPlayer`; `false` when the actor is not a standing NPC actor, either is busy, or the player's game cannot be carried.
---`IsPlayerCarried` and `GetPlayerCarriedBy` tell it is going on.
---@param actorId number the NPC actor that carries
---@param pid number the player
---@return boolean `true` when the grab started
function ActorCarryPlayer(actorId, pid) end

---Has an NPC actor put down what it carries.
---
---The put takes about two and a half seconds, then the body lies at `x, y, z` (and `yaw`, degrees, which counts only together with
---`x, y, z`) when given, else a step ahead of the actor. Ordered while the actor still grabs, it waits for the grab to finish. `false` when the actor carries
---nothing.
---@param actorId number the NPC actor
---@param x? number metres
---@param y? number metres
---@param z? number metres
---@param yaw? number degrees
---@return boolean
function ActorPutDown(actorId, x, y, z, yaw) end

---Knocks a player out, or wakes them - the game's own knock-out, health as it is.
---
---A knocked-out player drops, their screen goes dark, everyone who has their body sees them lie, and their health stays as it
---is (bleeding goes on - a bleed-out is a death). They cannot fight, ride, act, make an emote or start a dice match; a grab
---carries them (`SetCarrying`). `seconds` above `0` wakes them by itself after that long (24 hours at the most); `0` or `nil` keeps them down until the
---mode wakes them (`on` `false`), they die, leave or respawn. Knocking out one who is out already sets the timer anew. A player
---who carries someone puts them down. `OnPlayerKnockedOut` and `OnPlayerWake` tell it.
---
---`false` and the reason ("They are riding.", "They are in a cart." ...) when the player is not in the world, dead, on a horse (the
---mode can `ThrowPlayerFromHorse` first), in a cart, flying, in a dice match, or in a fall or a pull-down. A game from an older
---or unsupported build is knocked out all the same - the server holds the player down whatever his game shows - but takes no
---part in a carry. Waking a player who is not knocked out answers `true`.
---@param pid number the player
---@param on? boolean `true` (the default) knocks them out, `false` wakes them
---@param seconds? number how long they stay down, at most `86400` (24 hours); `nil` or `0` until woken
---@return boolean `true` when done; `false` and the reason when it could not be
---@return string
function SetPlayerKnockedOut(pid, on, seconds) end

---Whether the player is knocked out.
---@param pid number the player
---@return boolean
function IsPlayerKnockedOut(pid) end

---Knocks an NPC actor out, or wakes it.
---
---The actor drops where it stands for everyone who has its body: its walk stops, its fight ends, its AI stays still while it is
---down (a vendor knocked out trades with nobody). `seconds` above `0` wakes it after that long (24 hours at the most); `0` or `nil` keeps it down until
---woken (`IsActorKnockedOut`). A knocked-out actor can be carried by the grab (`SetCarrying`, the `actors` rule) and by
---`CarryEntity`. Dying ends it. `false` when `actorId` is not a living NPC actor.
---@param actorId number the NPC actor
---@param on? boolean `true` (the default) knocks it out, `false` wakes it
---@param seconds? number how long it stays down, at most `86400` (24 hours); `nil` or `0` until woken
---@return boolean
function SetActorKnockedOut(actorId, on, seconds) end

---Whether the NPC actor is knocked out.
---@param actorId number the NPC actor
---@return boolean
function IsActorKnockedOut(actorId) end

-- ======== Discovery - the map and the places a player found =====================
-- What a player **discovered** is what the game's own map and journal remember about them: the **places** they found - the named
-- locations (villages, towns, camps), the points of interest and the kinds of them - the **books** they read and how far they studied
-- each, the **map pin** and legend switches they set, and the parts of the world map they **uncovered** (the fog of war, on a server that
-- keeps it). By default a server keeps none of it: nothing they find outlives the visit.
-- A game mode that wants a character to keep what it found turns **tracking** on, saves what the server records, and puts it back at the
-- next login - the same way it keeps the character's progression.
-- 
-- **Kinds.** `"places"`, `"reading"`, `"ui"` (the map pin and the legend) and `"fog"` (the uncovered map) - the constants
-- `DISCOVERY_PLACES`, `DISCOVERY_READING`, `DISCOVERY_UI` and `DISCOVERY_FOG` are the same words. Wherever a set of kinds is taken it
-- is `true` (every kind), a name, or a list of names; `nil`, `false` and `{}` are none, except where a function says otherwise
-- (`ForgetPlayerDiscovery`, `SetPlayerDiscoveryTracking`). The places, the pin and the fog are kept **per level**; the reading is
-- **global** (the game keeps the books once for the whole game, so its record is the same whatever the level).
-- 
-- **The fog.** With `[ui] map_fog = true` in the server's settings the world map stays clouded where a player has not been, and the
-- clouds lift as they walk. Tracking `"fog"` keeps what each character uncovered, so a returning player sees the parts of the map they
-- explored; without `map_fog` every player's map is revealed whole at each spawn, and the fog's record is simply the whole map.
-- `RevealPlayerMap` uncovers the whole map, and a saving mode then saves the whole map: call it only for a character that should keep it.
-- 
-- **Tracking is off unless the mode turns it on.** `SetDiscoveryTracking` names the kinds the players' games report, usually in
-- `OnGameModeInit`; `SetPlayerDiscoveryTracking` gives one player a set of their own. With nothing tracked no message is sent and no
-- player's game does any work: a mode that never calls these functions sees no change at all.
-- 
-- **The record.** The server keeps, for each player, what their game reports: a block per kind, sent when it changed and again after
-- every spawn. The record is a **union**: it only grows. Every report is added to what the record holds - a place found, a book
-- studied further - and nothing a report leaves out is taken away, so a restore that went wrong halfway, a report that
-- arrives late, or a player's game that has forgotten something can never shrink what the mode saves. (The map pin and the legend are
-- the player's own marks, not discoveries: the newest report replaces them, and a restore of them replaces what the game shows.)
-- `GetPlayerDiscovery` reads the record. Each block is
-- **data the server keeps for you**: a base64 text of a fixed, versioned format (`format` says which), up to about 64,000 characters, ready
-- to save as it is in a text column and to hand back to `SetPlayerDiscovery` later; saved records stay readable across server updates.
-- Treat the text as opaque: do not edit it.
-- 
-- **Saving a character.** Save the record when `OnPlayerDiscoveryChange` says it grew (at most once a kind every few seconds, so a long walk
-- is a few calls), on a timer and in `OnPlayerDisconnect`; put it back with `SetPlayerDiscovery` when the player logs in. What a
-- player found in their last seconds is in the record you read in `OnPlayerDisconnect`: a change still waiting for its window is told
-- to `OnPlayerDiscoveryChange` just before the goodbye (and when the mode is reloaded or the server stops), so a mode that saves what
-- it was told misses nothing; a mode can also save every kept kind at the goodbye. Write only the blocks that differ from what you
-- saved last. **Never write before the restore has gone out**: until then the record holds only what the player found since they
-- joined, and saving that over the stored character loses the rest. For a character with nothing saved yet, make the first save
-- once `IsPlayerDiscoveryKnown` says the game has reported, so the first rows hold what the game knows rather than an empty record.
-- 
-- **Restoring.** `SetPlayerDiscovery` takes the record at once - `GetPlayerDiscovery` right afterwards answers it - and sends it to the
-- player's game, which adds it to what it already holds, exactly and silently, without the notices of a discovery in play. A restore made
-- before the player is in the world waits for their spawn. The game answers every restore, applied or given up
-- (`OnPlayerDiscoveryRestore`). A restore never takes anything the player found since they joined: pass `replace` only for a mode that
-- switches one game between characters, and call `ForgetPlayerDiscovery` (or `SetPlayerDiscovery` with `replace`) at each switch.
-- 
-- **A labelled map.** A revealed map shows the land and no names. `RevealPlayerMap` with `"places"` (or `"all"`) shows one player the
-- whole map and also finds the places of the level, so the revealed map is labelled - provided the player's game can do it. No player's
-- game does it in this version: the map is revealed without the names, and the places the player found - or a restore put back -
-- show theirs as ever.
-- 
-- **Several characters in one game.** A mode that lets a player switch characters without leaving calls `ForgetPlayerDiscovery` at
-- the switch - every kind, the places too - and then `SetPlayerDiscovery` with the next character's record; or `SetPlayerDiscovery`
-- with `replace`, which forgets the kinds it carries first. The second character's map then shows only what it found.
-- 
-- **Limits.** The game's own story quests, if the mode runs them (`SetStoryQuests`), can undo places the player found: keep them off in
-- a mode that saves places. A player whose game cannot read a kind - an unknown version of the game, or an older KCD:MP - reports
-- nothing of it and applies nothing of it; `capable` in the record says which kinds their game can do.

---**Called by the server** - What the player discovered grew - the moment to save it.
---
---The player's game reported more of a kind than the record held - a place found, a book studied further -
---or it reported a kind for the first time. That first whole report is also the sign that `GetPlayerDiscovery` now holds the game's own
---state: a mode that restores a character waits for it before it trusts what it reads. The record already holds the new state when this
---runs. It runs at most once per kind every five seconds, with the rest waiting for the next window, so a walk across the map is a few
---calls and not hundreds - read the record then and write only what differs from your last save.
---
---A change still waiting for its window when the player leaves is told at once, just before `OnPlayerDisconnect` (and before a
---reloaded or stopped mode's own goodbye), so what a player found in their last seconds reaches a mode that saves what it is told.
---
---It does **not** run for a set of the mode's own (`SetPlayerDiscovery`).
---@param pid number the player
---@param kind string `"places"`, `"reading"`, `"ui"` or `"fog"`
---@param level string the level of the record; empty for the global reading
function OnPlayerDiscoveryChange(pid, kind, level) end

---**Called by the server** - The player's game answered a restore - it applied it, or gave up.
---
---For every kind a `SetPlayerDiscovery` or `ForgetPlayerDiscovery` carried, once the player's game has answered. `ok` is `false` when
---the game could not do it - it cannot read that kind, it does not know this version of the game, the order could never be applied. The
---record kept what the mode set either way; the callback is for a mode that wants to know (a log line, a retry after the next spawn).
---@param pid number the player
---@param kind string `"places"`, `"reading"`, `"ui"` or `"fog"`
---@param ok boolean `true` when the game applied it, `false` when it gave up
function OnPlayerDiscoveryRestore(pid, kind, ok) end

---Chooses which kinds of discovery the players' games report to the server.
---
---Call it when the mode starts. Nothing is tracked until it is called: no message is sent and no game does any work. Setting it
---tells every player in the world and a player whose game joins gets it after their spawn. A reload of the game mode starts from
---nothing again - the new mode sets its own.
---@param kinds boolean|string|table|nil `true` (every kind), a kind's name, or a list of names - `nil`, `false` or `{}` track nothing
---@return boolean `false` when a word is no kind (nothing changes)
function SetDiscoveryTracking(kinds) end

---The kinds of discovery the server asks every player's game for.
---@return table a list of kind names, empty when nothing is tracked
function GetDiscoveryTracking() end

---Gives one player a set of tracked kinds of their own, over the server-wide one.
---
---The kinds are taken as in `SetDiscoveryTracking`: `{}` or `false` make this player track nothing, whatever the server-wide set
---says; `nil` is the exception - it gives the player's own set up, and they follow the server-wide set again. A reload of the game
---mode (`ReloadGameMode`) clears every player's own set too: they follow the new mode's server-wide set until it calls this
---again.
---@param pid number the player
---@param kinds boolean|string|table|nil as `SetDiscoveryTracking`; `nil` follows the server-wide set again
---@return boolean `false` when there is no such player or a word is no kind
function SetPlayerDiscoveryTracking(pid, kinds) end

---The kinds the player's game is told to report.
---
---The player's own set, else the server-wide one.
---@param pid number the player
---@return table|nil a list of kind names; `nil` when there is no such player
function GetPlayerDiscoveryTracking(pid) end

---The record of what the player discovered, ready to save.
---
---A table with the `level` it is of, a block for every kind the server holds - `places`, `reading`, `ui`, `fog` - and `capable`, the
---list of kinds the player's game can read and write (empty until its first report). A kind with nothing reported or set - or one forgotten
---(`ForgetPlayerDiscovery`) - is absent, so test for it: `if record.places then`. A block is `{ format, data, bytes, updated }`: `data` is the base64 text to save, `format`
---the version of its layout (1 today; save it with the data), `bytes` the size of what the text holds and `updated` when the
---record of that kind last changed, in seconds since 1970. The reading block is global: it is there whatever the level.
---
---A player who exists always has a record, empty if nothing was reported or set yet; read it again after the player's game has
---reported (`OnPlayerDiscoveryChange`, `IsPlayerDiscoveryKnown`) and not before.
---@param pid number the player
---@param level? string|nil the level to read (the server's level when left out); reading answers whatever the level
---@return table|nil the record; `nil` when there is no such player
function GetPlayerDiscovery(pid, level) end

---Puts a saved record back - the player's game takes what it was not holding.
---
---The record is a table as `GetPlayerDiscovery` returns it: the kinds it has are set, the kinds it lacks are left alone. It is
---taken at once and sent to the player's game, which **adds** it to what it holds (the default): the game ends up with the saved
---discoveries and anything the player found since they joined. A restore made before the player is in the world waits for their spawn,
---in the order it was made.
---
---With `replace` the record becomes exactly the one given and the player's game forgets the kinds present first - for a mode that
---lets one game play several characters one after the other. The map pin and the legend always replace what the game shows.
---
---A block of another level than the server's is kept in the record and not sent. A block the server cannot read - a format it does
---not know, text that is no block of that kind, or one over 48,000 bytes (64,000 characters of text) - is skipped, logged and the
---call returns `false`; the others are applied. No
---`OnPlayerDiscoveryChange` follows a set of the mode's own; `OnPlayerDiscoveryRestore` follows when the game has answered.
---@param pid number the player
---@param record table `{ level = , places = { format = , data = }, reading = { ... }, ui = { ... }, fog = { ... } }` - the keys of `GetPlayerDiscovery`
---@param replace? boolean `true` makes the record exactly this one (the game forgets the kinds first); the default adds
---@return boolean `false` for a player who is not there or when a block was skipped
function SetPlayerDiscovery(pid, record, replace) end

---The player has found nothing again - the record emptied and the game told to forget.
---
---For a mode that lets one game play more than one character: call it at each switch, then restore the new character's record. The
---kinds are as `SetDiscoveryTracking` takes them, except that leaving them out (or `nil`) means every kind. The player's game
---forgets them the moment the order arrives: the places found go back to unknown, the books unread, the pin and the legend's switches
---go, and the map clouds over again where `[ui] map_fog` keeps the fog. The place the player stands in is found again as soon as they
---walk in or out of it.
---@param pid number the player
---@param kinds? boolean|string|table|nil the kinds to forget (all of them when left out)
---@return boolean `false` for a player who is not there or when a word is no kind (nothing is forgotten then)
function ForgetPlayerDiscovery(pid, kinds) end

---Whether the record of a kind is the player's game's own.
---
---`true` once a whole report of the kind has arrived or the mode set it. A record that is still empty because the game has not reported
---yet is no record: a mode that saves on a timer waits for this before it writes, so it never saves a fresh record over a character's
---saved one. For a list of kinds it is `true` when every one is known.
---@param pid number the player
---@param kinds boolean|string|table the kind, or a list of them
---@return boolean
function IsPlayerDiscoveryKnown(pid, kinds) end

-- ======== Interface =============================================================
-- The pieces of a player's screen that KCD:MP draws - the chat, the scoreboard, the name plates over heads, the party frames,
-- the notices, the emote wheel and the rest - are **components**, and a mode decides how each one looks for each player.
-- There are two things to change about a component, for one player or for everyone:
-- 
-- - **who draws it** - the *drawer*: `"native"` is KCD:MP's own piece and the default; `"hidden"` draws nothing and its keys
--   stop working (a hidden scoreboard still takes Tab), while what the piece does behind the scenes carries on (a hidden chat still collects its lines, a
--   hidden scoreboard still knows who is on the server). Only `chat`, `scoreboard`, `notices`, `party`, `emotes`, `hudtext`,
--   `sleep`, `nameplates` and `compass` can be hidden;
-- - **how it is laid out** - the *options* of a component: the chat's corner, width and number of lines, whether the
--   scoreboard is held or toggled with Tab, where the party frames sit, the colour of the name plates, and a few more.
-- 
-- The components are `chat`, `scoreboard`, `notices`, `party`, `death`, `dialog`, `emotes`, `loading`, `hudtext`, `shop`,
-- `voice`, `sleep`, `nameplates`, `compass` and `hud`. Change the interface lists what each one
-- is, what `hidden` does to it, and every option with its range and default.
-- 
-- What a player sees is **their own setting** if the mode made one for them, else the setting made **for everyone**, else the
-- default. The setters answer `true`, or `false` and the reason in words a person can read; a call with any bad word in it
-- changes nothing at all, not even the good keys next to it. Several calls in one tick reach the player as one change, and a
-- call that changes nothing sends nothing.
-- 
-- A reload of the mode puts every component back to native with the default options, so a mode sets its
-- interface where it is made again: for everyone in `OnGameModeInit` (the settings then hold for whoever joins later), for
-- one player in `OnPlayerConnect`. A player who leaves and comes back starts again from the settings made for everyone.

---Says who draws a component of one player's screen - `"native"` or `"hidden"`.
---
---`"native"` is KCD:MP's own piece, `"hidden"` draws nothing and its keys stop working (a hidden scoreboard still takes
---Tab); the words are read in any case. The component's own logic keeps running behind a hidden drawer - hide the `chat` and its lines are still kept, hide
---the `scoreboard` and the roster is still known - and choosing `"native"` again shows it as it was. What `hidden` does to
---each component is in Change the interface.
---
---For **one player**, `"native"` also overrides a `"hidden"` made for everyone with `SetInterfaceForAll`. There is no
---"as everyone has it" for a drawer: say `"native"` or `"hidden"`.
---
---The `party` drawer is the party frames: `"hidden"` is `ShowPartyFrames` with `false`, `"native"` with `true`, and the two
---calls read each other - `GetPlayerInterface` too.
---
---The `chat`, the `scoreboard`, the `hudtext` (the mode's HUD texts and its GameText), the `sleep` fade, the `notices`, the
---`death` screen, the `party` frames, the `voice` indicator, the `emotes` wheel, the `shop` (a mode's list panel) and the
---`dialog`s (a mode's dialogue page, the game's own questions) have two more drawers, both drawn by the game's web layer:
---`"default"` - KCD:MP's own web version of the component, which the interface's theme styles (`[theme]` in its `ui.toml`) -
---and **the name of a frame** of the mode's interface (`[frames.<name>]` in its `ui.toml`), which then draws the component
---itself: it gets the component's lines, roster, texts or notices and its keys, and calls its actions (the component's
---contract: `chat@1`, `scoreboard@1`, `hudtext@1`, `sleep@1`, `notices@1`, `death@1`, `party@1`, `voice@1`, `emotes@1`,
---`shop@1`, `dialog@1`). A frame draws
---one component at a time. The `party`'s web drawer comes with its frames shown: `"hidden"` (or `ShowPartyFrames` with
---`false`) still switches them off, and showing them again brings the web drawer back. A player whose game cannot draw the web drawer - the web layer is off or failed, the page is not
---ready yet, its renderer stopped - gets the native piece meanwhile, and the web drawer the moment it can draw again;
---`GetPlayerInterface`'s second word says which one draws. The interface's own `[components.<name>]` drawer and options
---are what a player has when the mode set nothing for them or for everyone.
---
---The `loading` screen has a web version too (`loading@1`), but its drawer is the interface's `ui.toml` alone -
---`[components.loading] drawer` is `"default"` or a frame's name, and without the section a frame called `loading` draws it:
---it shows while the level loads, before anything the mode sends reaches the player's game, so this call refuses it.
---
---When it cannot be done the second value says why: `"not connected"`, `"unknown component 'x'"`,
---`"the shop cannot be hidden"` (a component that has no hidden drawer: `death`, `dialog`, `loading`, `shop`, `voice`,
---`hud`) or, for a word that is not a drawer of that component, what is wrong with it. The web drawers' reasons:
---`"the compass has no web version yet"` (a component without one), `"the loading screen's drawer is set in the interface's
---ui.toml ([components.loading])"`, `"no interface is loaded"` (a frame's name while the mode has no interface), `"no such
---frame in the interface"`, `"the frame chat already draws the scoreboard"`.
---@param pid number the player
---@param component string `"chat"`, `"scoreboard"`, `"notices"`, `"party"`, `"emotes"`, `"hudtext"`, `"sleep"`, `"nameplates"`, `"compass"` - or one of the six that only draw natively
---@param drawer string `"native"` or `"hidden"` - or, for the components with a web version (the `chat`, the `scoreboard`, the `hudtext`, the `sleep` fade, the `notices`, the `death` screen, the `party` frames, the `voice` indicator, the `emotes` wheel, the `shop` and the `dialog`s), `"default"` or the name of a frame of the interface
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"the shop cannot be hidden"`, `"unknown component 'x'"`, `"not connected"` ...)
---@return string reason
function SetPlayerInterface(pid, component, drawer) end

---Who draws a component of a player's screen - what was asked for and what draws it.
---
---Two words: what the mode asked for and what actually draws the component. With the `"native"` and `"hidden"` drawers they
---are always the same word. What the mode asked for is the player's own setting, else the one made for everyone, else
---`"native"`; for the `party` it is the party frames' switch (`ShowPartyFrames`, `[party] frames`). `nil` and the reason -
---`"not connected"` or `"unknown component 'x'"` - for a player who is not connected or a component that does not exist.
---
---With a web drawer (`"default"` or a frame's name, for the components that have one) the second word is what the
---player's game says draws it now: the same word while the web layer draws it, `"native"` while it cannot (the web layer is
---off or failed, the page is not ready yet) - and `"native"` until the game has said anything. Before the interface's own
---`[components.<name>]` drawer, what was asked for is the mode's setting for the player, else for everyone.
---@param pid number the player
---@param component string the component's name, as in `SetPlayerInterface`
---@return string|nil requested the two words `requested, effective` (`"native"` or `"hidden"`); `nil` and the reason when the player or the component does not exist
---@return string effective
function GetPlayerInterface(pid, component) end

---`SetPlayerInterface` for everyone - and for whoever joins later.
---
---Every connected player gets the drawer, and so does everyone who joins until the mode is reloaded. It **replaces**
---what the mode set for any one player for that component. For the `party` it is the party frames on or off for everyone,
---and it changes what `[party] frames` says for the players who join later as well.
---
---The reasons are the ones of `SetPlayerInterface`: `"unknown component 'x'"`, `"the shop cannot be hidden"`, and for a
---word that is not a drawer of that component, what is wrong with it.
---@param component string the component's name, as in `SetPlayerInterface`
---@param drawer string `"native"` or `"hidden"` - or, for the components with a web version (the `chat`, the `scoreboard`, the `hudtext`, the `sleep` fade, the `notices`, the `death` screen, the `party` frames, the `voice` indicator, the `emotes` wheel, the `shop` and the `dialog`s), `"default"` or the name of a frame of the interface
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetInterfaceForAll(component, drawer) end

---How a component is laid out for one player - the chat's corner and lines, the scoreboard's mode, and so on.
---
---`options` is a table of `key = value`; numbers, booleans and texts are all written as text for the server, so `lines = 12`,
---`show_stamina = false` and `anchor = "top-right"` are what they look like. The value `"default"` (or an empty text) takes
---a key back to what everyone else has - the setting made for everyone, else the option's own default - and a key that is
---not in the table is left as it is. A number may have a decimal point (it is kept to three places); a colour is a **text**
---of six hex digits, `"F6E890"` or `"#F6E890"` - never a number.
---
---Sizes and margins are **pixels on a screen 1080 pixels tall**: on a taller or shorter screen the piece grows or shrinks
---with the height, and a wider screen only gives it more room across. `anchor` picks the corner or edge the piece is
---attached to and the margins count from the edges it touches; `top` and `bottom` are centred across, `left` and `right`
---centred down, `center` both, and a centred direction has no margin.
---
---| Component | Key | Value | Default |
---|---|---|---|---|
---| `chat` | `anchor` | `top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`, `bottom`, `bottom-right` | `bottom-left` |
---| `chat` | `margin_x` | 0 to 960 | `12` |
---| `chat` | `margin_y` | 0 to 540 | `64` |
---| `chat` | `width` | 300 to 1200 | `560` |
---| `chat` | `lines` | a whole number, 4 to 20 | `10` |
---| `chat` | `backing_alpha` | 0 to 100: the dark frame behind the lines while the box is closed | `45` |
---| `chat` | `backing_alpha_open` | 0 to 100: the frame while the box is open or the chat is scrolled back | `85` |
---| `chat` | `font_scale` | 0.6 to 1.6, times the usual size | `1` |
---| `scoreboard` | `mode` | `hold` (shown while Tab is held), `toggle` (Tab opens it, Tab or Esc closes it) | `hold` |
---| `scoreboard` | `title` | text, at most 64 characters | empty: `KCD:MP  -  <server name>` |
---| `party` | `anchor` | `top-left`, `left`, `bottom-left`, `top-right`, `right`, `bottom-right` | `top-left` |
---| `party` | `margin_x` | 0 to 960 | `24` |
---| `party` | `margin_y` | 0 to 1000 | `173` |
---| `party` | `show_stamina` | `true`, `false`: the stamina bars of the members | `true` |
---| `nameplates` | `color` | six hex digits: the name's colour when the mode gave the player none (`SetPlayerColor`) | `F6E890` |
---| `nameplates` | `font_scale` | 0.5 to 2 | `1` |
---| `nameplates` | `bar_width` | 40 to 240: the health bar | `120` |
---| `nameplates` | `text` | `name`, `id`, `name_id`: what a plate says when the mode gave the player no label - their name, their player id, or `Henry (3)` | `name` |
---| `nameplates` | `peek_key` | the name of a keyboard key (`lalt`, `lctrl`, `n`, `f4` ...): the names show only while it is held; empty = they always show | empty |
---| `nameplates` | `peek_scope` | `all`, `players`: whose names wait for the `peek_key` - every plate's, or the players' alone (the NPC actors' labels always show) | `all` |
---| `nameplates` | `npc_range` | a whole number, 0 to 255: the metres an NPC actor's name shows up to (it fades over the last third); `0` = as far as the players' names | `0` |
---| `compass` | `span` | 30 to 180: the degrees of the horizon the compass strip covers | `90` |
---| `dialog` | `side` | `left`, `right`: where a dialogue page's choices (`ShowPlayerDialogue`) stand - the right is where the game's own conversations put them | `left` |
---| `dialog` | `bars` | `off`, `dialog` (while a dialogue page is open), `on` (from now until set back): the game's own black cinema bars, with the subtitles moved into the lower one | `off` |
---| `hud` | `compass`, `stats`, `subtitles`, `hints`, `cursor`, `buffs`, `info_text`, `game_log`, `common_event`, `fancy_event`, `tutorial_message` | `1` shows the game's own HUD piece of that name, `0` hides it (`true`, `false`, `on`, `off`, `yes` and `no` are read as the same); `SetPlayerHudVisible` says what each piece is | `1` |
---
---The other components have no options. The call is all or nothing: one bad key or value and nothing changes. The second
---value says what was wrong, in words - `"unknown component 'x'"`, `"unknown option 'x' for the chat"`, `"lines must be a whole
---number from 4 to 20"`, `"width must be a number from 300 to 1200"`, `"anchor must be one of top-left, top, ..."`,
---`"show_stamina must be true or false"`, `"color must be a colour of six hex digits, like F6E890"`, `"title must be at most 64
---characters"`, `"peek_key must be the name of a keyboard key: ..."`, or `"not connected"`. The scoreboard's `title` replaces the
---`KCD:MP  -  <server name>` part of its title line; the number of players and the page stay after it.
---
---The name plates' `text` and `peek_key` are for a server whose players do not know each other: with `peek_key = "lalt"` the
---names show only while Left Alt is held (the health bars, a chat bubble and a vendor's prompt follow their own rules), and
---`text = "id"` makes a plate say the player's id until the mode gives that player a label - or, for one player's screen
---alone, a name they were told (`SetPlayerNameplateFor`). `peek_scope = "players"` keeps the key for the players' names:
---the labels of the mode's NPC actors - a shopkeeper, a guard, a quest giver (`SetActorNameplate`) - stay readable. The key
---is watched, never taken from the game; when it is also the cursor key (Left Alt unless the player chose another), holding it
---does not bring the pointer up.
---@param pid number the player
---@param component string `"chat"`, `"scoreboard"`, `"party"`, `"nameplates"`, `"hud"` or `"compass"`
---@param options table `{ key = value }` - numbers, booleans and texts; `"default"` takes a key back to its default
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"lines must be a whole number from 4 to 20"` ...)
---@return string reason
function SetPlayerInterfaceOptions(pid, component, options) end

---`SetPlayerInterfaceOptions` for everyone - and for whoever joins later.
---
---The keys given become the setting for every connected player and for everyone who joins until the mode is reloaded; they
---**replace** what the mode set for any one player under those keys, and leave the player's other keys alone. The keys, the
---values and their ranges are the ones of `SetPlayerInterfaceOptions`; `"default"` for a key takes it back to the option's
---own default. The call is all or nothing, and the reasons are the same words.
---@param component string `"chat"`, `"scoreboard"`, `"party"`, `"nameplates"`, `"hud"` or `"compass"`
---@param options table `{ key = value }` - numbers, booleans and texts; `"default"` takes a key back to its default
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetInterfaceOptionsForAll(component, options) end

---Adds columns to the scoreboard - kills, score, a rank - whose cells are the players' state values.
---
---`columns` is a list of tables, at most **8**, each a column:
---
---| key | what it is |
---|---|---|
---| `key` | the player state key whose value the column shows in each player's row (1 to 48 characters) - required; two columns cannot show the same key |
---| `label` | the heading, 32 characters at most |
---| `width` | the column's width on a screen 1080 pixels tall, 0 to 2000; `0` or left out lets the board decide |
---| `align` | `"left"` (the default), `"center"` or `"right"` |
---| `format` | how a cell reads its value: `""` (as it is, the default), `"number"`, `"time"` or `"percent"` |
---| `color` | `0xRRGGBBAA` for the cells; left out is the board's own colour |
---| `visible` | `"all"` (the default) or `"admin"`: who is sent the column |
---
---The cells are the values the mode keeps with `SetPlayerState` under each key: change the state and the cell changes.
---**What `"admin"` hides is the column, never the data**: every player's game already holds every player's state, so an
---admin-only column is drawn for admins alone but its values are in every game's copy of the state - keep nothing secret
---there.
---
---Without a player the columns are the ones **everyone** sees, and whoever joins later; they replace any list made for a
---single player. With a player that list is theirs alone and replaces the shared one for them. `nil` takes the columns
---back: for everyone it leaves the scoreboard with none, for a player it returns them to the shared ones. Each player's
---game is sent the columns they may see when they join, when the columns change and when their admin flag does
---(`SetPlayerAdmin`); a reload of the mode empties them: set them in `OnGameModeInit`.
---
---KCD:MP's own scoreboard keeps its three columns - the number, the name and the ping; the columns set here are drawn by a
---scoreboard built as a web page.
---
---The answer is `true`, or `false` and the reason, which names the column: `"too many columns (8 at most)"`, `"column 2:
---the key is a player state key (1-48 characters)"`, `"column 2: two columns show the key 'kills'"`, `"column 2: the label
---is over 32 characters"`, `"column 2: the width is 0-2000"`, `"column 2: align is left, center or right"`, `"column 2:
---format is empty, number, time or percent"`, `"column 2: visible is all or admin"` or `"no such player"`. A call with any
---bad column changes nothing.
---@param columns table|nil a list of `{ key, label, width, align, format, color, visible }` - at most 8; `nil` takes the columns back
---@param pid? number|nil the player whose own list this is; `nil` for everyone
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetScoreboardColumns(columns, pid) end

-- ======== Pickpocketing =========================================================
-- The game's own pickpocketing between players: the "Rob" prompt on a body (hold **E**), the charge and the tile game of
-- single player, played on the thief's screen - over what the server offers from the victim's pockets, and what the game takes
-- is moved by the server. The mode decides whether it exists at all, who may rob and be robbed, and what a caught thief or a
-- robbed player gets: the consequences are the mode's (`OnPlayerPickpocketEnd`).
-- 
-- **It is off until a mode switches it on** (`SetPickpocketing`); then every player's body shows the prompt to every other
-- player, until the mode says otherwise for a player (`SetPlayerPickpocketable` takes a player's pockets out of it,
-- `SetPlayerCanPickpocket` takes the right to rob from a player). An NPC actor shows the prompt when the mode gave it pockets
-- (`SetActorPocket`).
-- 
-- **How a robbery goes.** The thief's game asks. The server checks that the thief and the victim stand in the world, in view of one
-- another, in one virtual world, on foot, within the rules' range (and behind the victim, if the rules say so, and with no wall or closed door between them when
-- `[validation] line_of_sight` is on and the server has the level's collision geometry), that neither is busy - riding, in a cart,
-- flying, in a dice match, at a shop, in a dialogue, searching a body, knocked out, carried or carrying, in a fall or a pull-down, in a
-- fight - that nobody else is robbing the same victim, that the same
-- thief did not rob the same victim in the last `cooldown` seconds, and finally asks the mode (`OnPlayerPickpocketStart`). A
-- refusal reaches the asker alone, with a line in his chat (each line at most once in fifteen seconds).
-- 
-- Then the server makes the **offer**: what the victim carries - not what they wear or hold in a hand - up to `max_items` stacks (never more than 11 -
-- the game's wheel has no more places), shuffled, at most `max_stack` of one class; quick-slot containers, item aliases, NPC tools
-- and key rings are never in a pocket, and the rules' `deny` keeps out anything else by class, name or catalogue category. With
-- `money` the victim's purse joins the same pool as one entry (a share of it, up to a cap), so `max_items` counts it too and a full
-- bag can leave it off the wheel. The thief's game plays the minigame over exactly that;
-- the game's own roll can catch him in the charge, and the tile game can be failed. When it ends it says which of the offered
-- stacks it took. The server refuses a claim that names a stack the offer did not hold, one twice, more than was offered, one that
-- comes sooner than `min_seconds` after the grant, or one after ninety seconds - nothing moves then. Otherwise each stack goes to
-- the mode (`OnPlayerPickpocket`: `false` leaves it), is cut to what the victim still holds, and moves: the victim's game gives
-- it up the way a searched body's does, the thief gets it from the server - so the inventory audit explains both, and neither is a
-- violation. A thief the game caught takes nothing. `OnPlayerPickpocketEnd` hears every ending.
-- 
-- **A session ends** when the thief's game says so (it took something, nothing, was caught, or broke off), and by the server's own
-- word when either player dies, leaves, respawns, is teleported (`SetPlayerPos`), mounted, put in a cart, flies, is knocked out
-- or carried, goes to another virtual world, walks more than a metre past the range, when a fight begins with either, when ninety
-- seconds pass without a word from the thief's game, or when the mode says so (`CancelPickpocket`, `SetPickpocketing` off,
-- `SetPlayerPickpocketable` or `SetPlayerCanPickpocket` taking the right away, `SetActorPocket` taking the pockets away). The
-- thief's game then ends its minigame at once; the mode hears `"cancelled"` with the reason. An NPC actor that dies or is removed
-- ends the session before its body goes. A woman's character robs, and is robbed, as a man's does. A player's game that cannot play
-- the minigame (an older or unsupported build) cannot rob: the server grants it nothing.
-- 
-- The rules are the mode's, not the server's: there is nothing about pickpocketing in `server.toml`. The shipped modes keep them in
-- a table at the top of their file, for the owner to change.
-- 
-- **Reserved state keys.** The prompt is shown through state keys the server writes: the world state `pocket` (`"1"` while
-- `SetPickpocketing` is on), a player's `pocket` (`"0"` while `SetPlayerPickpocketable` took them out) and `steal` (`"0"` while
-- `SetPlayerCanPickpocket` took the right away), and an NPC actor's `pocket` (`"1"` while it has pockets). Do not set `pocket` or
-- `steal` with `SetGlobalState`, `SetPlayerState` or `SetEntityState` yourself. A mode reload (`ReloadGameMode`) takes all of
-- it down with the old mode: pickpocketing is off with the default rules, everyone robbable and able to rob, the actors' pockets gone
-- and a session that runs ended without a word to the mode; the new mode's `OnGameModeInit` sets what it wants.

---**Called by the server** - A player reaches for another's pockets with the game's "Rob" - return `false` to refuse.
---
---Only while pickpocketing is on (`SetPickpocketing`). The server has checked the reach, the world, who is busy, the cooldown and
---that the victim can be robbed and has something to take; the mode has the last word. Returning `false` stops it - the thief is
---told he cannot rob them - anything else lets the minigame start. The mode does its own bookkeeping here (a cooldown of its own,
---a guard who watches); a later refusal of the server's own does not call this again.
---
---Exactly one of `victim` and `actor` is a real id: `victim` is the player id of the player robbed, `actor` the entity id of an
---NPC actor with pockets; the other is `-1`.
---
---Return value: `false` refuses; nothing, `nil` or `true` lets it start
---@param pid number the thief
---@param victim number the player whose pockets they reach for; `-1` for an actor
---@param actor number the NPC actor whose pockets they reach for; `-1` for a player
function OnPlayerPickpocketStart(pid, victim, actor) end

---**Called by the server** - The thief's game took a stack - return `false` to leave it.
---
---After the minigame, before anything moves: the server has held the claim to the offer and cut each stack to what the victim still
---holds - `amount` is what would move. Returning `false` vetoes that stack alone: it stays where it is, and the others go on. Not
---called for a claim the server refused, nor for a thief the game caught (nothing moves for him).
---
---`class` is the item class; the purse is the Groschen's class
---(`5ef63059-322e-4e1b-abe8-926e100c770e`) with the amount in **tenths** of a Groschen, as everywhere in the item functions.
---
---Return value: `false` leaves the stack; nothing, `nil` or `true` lets it move
---@param pid number the thief
---@param victim number the player robbed; `-1` for an actor
---@param actor number the NPC actor robbed; `-1` for a player
---@param class string the item class that would move
---@param amount number how many of it
function OnPlayerPickpocket(pid, victim, actor, class, amount) end

---**Called by the server** - A pickpocket session is over - what came of it.
---
---`outcome` is `"took"` (stacks moved - `taken` of them), `"nothing"` (the minigame ended with nothing taken, or all of it was
---vetoed or gone), `"caught"` (the game's own roll caught the thief in the charge, or he failed the tile game - **nothing moves; the
---consequence is the mode's**: tell the victim, start a fight with `StartFight`, call the guards) or `"cancelled"` (the session
---was broken off; nothing taken).
---
---`reason` says why. For the outcomes the game decides it is the game's own: `"succeeded"`, `"detected"` (the victim noticed -
---what a caught thief usually says), `"seen"` (someone saw), `"lost"` (the thief walked off or looked away: the game's own break
---without a crime - the game can end a `"caught"` with it, so read the reason before you punish), `"interrupted"`, `"nothing stolen"` or `"unknown"`. For `"cancelled"` it is `"broken off"` (the thief's game),
---`"thief died"`, `"victim died"`, `"thief left"`, `"victim left"`, `"respawned"`, `"moved"` (the server moved one of them),
---`"moved away"` (past the range and a metre), `"mounted"`, `"cart"`, `"flying"`, `"knocked out"`, `"carried"`, `"carrying"` (one of the two started carrying someone),
---`"busy"`, `"fight"`,
---`"timeout"` (ninety seconds), `"victim gone"` (an NPC actor removed), `"world"` (another virtual world), `"too fast"` or
---`"bad claim"` (a claim the server refused), or the word the mode gave `CancelPickpocket` (`"mode"` when it gave none).
---
---A player who leaves the server is still one here: the session ends before `OnPlayerDisconnect`. A mode reload ends sessions
---without a word to the mode. `victim` and `actor` are as in `OnPlayerPickpocketStart`.
---@param pid number the thief
---@param victim number the player robbed; `-1` for an actor
---@param actor number the NPC actor robbed; `-1` for a player
---@param outcome string `"took"`, `"nothing"`, `"caught"` or `"cancelled"`
---@param reason string why it ended
---@param taken number how many stacks moved
function OnPlayerPickpocketEnd(pid, victim, actor, outcome, reason, taken) end

---Switches pickpocketing between players on or off, with its rules.
---
---On, the game's "Rob" prompt shows on the bodies of players who are robbable and on NPC actors with pockets, and a thief's ask is
---checked and answered (see the group's description). **Off by default.** Switching it off ends the sessions that run (the mode
---hears `"cancelled"`, reason `"mode"`).
---
---`rules` is a table, every key optional: `range` (metres the thief may stand from the body, `3`, from `0.5` to `6`; the game's own reach
---is about 2.4), `cooldown` (seconds before the same thief may rob the same player - or the same NPC actor - again, counted from
---the start, `30`; `0` = none, at most `3600`),
---`max_items` (stacks the pockets offer, `8`, never more than `11`), `max_stack` (the most of one class the pockets offer, `5`,
---at most `9999`; a class that does not stack shows one tile per item), `behind_only` (the thief must stand within 70 degrees of
---straight behind the victim, `false`: the game's own roll already punishes the front), `min_seconds` (the shortest session that
---may take anything, `2.5`, at most `60`), `money` (a player's purse is in the pockets, as one entry, `false`), `money_share` (the
---share of the purse that entry holds, `0.1`, from `0` to `1`), `money_cap` (the most it holds, in Groschen, `100`, at most
---`6553.5`), `actors` (an NPC actor with pockets can be robbed, `true`), `deny` (a list of item classes, item names or catalogue
---categories that are never offered: `{"Food", "dagger"}`; it keeps at most 64 entries and drops empty and repeated ones). A
---number that is not usable is the default. Without `rules` the earlier ones stay; a table without a key puts that key back to
---its default.
---
---A mode reload (`ReloadGameMode`) switches pickpocketing off again with the default rules (see the group's description). The
---world state key `pocket` is the server's - this call writes it.
---@param enabled boolean `true` shows the prompt and answers asks; `false` (the default) takes it away and ends running sessions
---@param rules? table `{range, cooldown, max_items, max_stack, behind_only, min_seconds, money, money_share, money_cap, actors, deny}`
function SetPickpocketing(enabled, rules) end

---Whether pickpocketing is on, and its rules.
---@return boolean `enabled`, and the rules table - `{range, cooldown, max_items, max_stack, behind_only, min_seconds, money, money_share, money_cap, actors, deny}` (`deny` a list), the defaults until `SetPickpocketing` gave others
---@return table
function GetPickpocketing() end

---Takes a player's pockets out of pickpocketing, or puts them back.
---
---With `false` the "Rob" prompt does not show on this player's body and every ask for it is refused; a session on them ends.
---Everybody is robbable by default. It lasts the player's session, through respawns, until a mode reload. The player's state key
---`pocket` is the server's (see the group's description) - this call writes it. `false` when `pid` is not a player.
---@param pid number the player whose pockets are meant
---@param enabled? boolean `false` takes their pockets out of it, `true` (the default) puts them back
---@return boolean `false` when there is no such player
function SetPlayerPickpocketable(pid, enabled) end

---Whether the player's pockets may be picked.
---@param pid number the player
---@return boolean `true` unless `SetPlayerPickpocketable` took them out; `false` for an id that is no player (whether pickpocketing is on at all is `GetPickpocketing`'s)
function IsPlayerPickpocketable(pid) end

---Takes the right to rob from a player, or gives it back.
---
---With `false` the "Rob" prompt does not show to this player and every ask of theirs is refused; a session of theirs ends. Everybody
---may rob by default. It lasts the player's session, through respawns, until a mode reload. The player's state key `steal` is the
---server's (see the group's description) - this call writes it. `false` when `pid` is not a player.
---@param pid number the player
---@param enabled? boolean `false` takes the right away, `true` (the default) gives it back
---@return boolean `false` when there is no such player
function SetPlayerCanPickpocket(pid, enabled) end

---Whether the player may rob others.
---@param pid number the player
---@return boolean `true` unless `SetPlayerCanPickpocket` took the right away; `false` for an id that is no player
function CanPlayerPickpocket(pid) end

---Gives an NPC actor pockets a thief may take from.
---
---`items` is a list of `{class = ..., amount = ..., health = ...}` (`class` an item class, name or id; `health` 0 to 100, `100`
---when absent) and `money` Groschen:
---the "Rob" prompt shows on the actor while pickpocketing is on (with the rules' `actors = false` it still shows, and the server
---refuses every ask) and the offer is made from them, with
---the rules' `max_items` and `max_stack`; the money is offered as one entry, whole up to the rules' `money_cap`. Every take shrinks
---the pockets; the mode refills them. `nil` takes the pockets away (no prompt on the actor; a session on it ends); an empty list
---is an actor with empty pockets - the thief is told there is nothing to take. An item class that is not in the item catalogue is
---left out. An entry with an `id` is one of the mode's **tagged items** (`GivePlayerTaggedItem`: a letter the courier carries) -
---offered on its own, and the thief gets it with its tag; a player's tagged items are offered the same way. The actor's state
---key `pocket` is the server's (see the group's description) - this call writes it. `false` when `actorId` is not an NPC actor.
---@param actorId number the NPC actor
---@param items table the stacks in its pockets - `{{class, amount, health}, ...}`; `nil` takes the pockets away
---@param money? number Groschen in its purse
---@return boolean `false` when there is no such actor
function SetActorPocket(actorId, items, money) end

---What an NPC actor's pockets hold now.
---@param actorId number the NPC actor
---@return table the stacks - `{{class, amount, health}, ...}` (a tagged item also `id, name, text`) - and the money in Groschen; `nil` when the actor has no pockets
---@return number
function GetActorPocket(actorId) end

---Ends the pickpocket session a player is in - nothing is taken.
---
---`pid` is either party - the thief or the one robbed (a player who is both is cancelled as the thief first). The thief's game ends
---its minigame at once; `OnPlayerPickpocketEnd` follows with `"cancelled"` and `reason` (`"mode"` when none is given or it is
---empty; the text is trimmed and cut to 48 characters). `false` when the player is in no session.
---@param pid number the thief, or the player robbed
---@param reason? string what the mode's callback hears, at most 48 characters; `"mode"` by default or when empty
---@return boolean `false` when there was no session to end
function CancelPickpocket(pid, reason) end

---Whom a player robs now.
---@param pid number the thief
---@return string the kind - `"player"` or `"actor"` - and the id (a player's id, or the entity id); `nil` when they rob nobody
---@return number
function GetPickpocketTarget(pid) end

-- ======== Web interface =========================================================
-- A server can give its players a **web interface**: pages of HTML, CSS and JavaScript - a menu, a shop window, a login screen,
-- a new chat - that the players' games draw over the game. The pages are the files of the mode's interface folder, and its
-- `ui.toml` names each **frame** (one page, drawn in a layer of its own) and says what the frame may do. A player's game
-- downloads the folder when they join. The server configuration says where the folder
-- is and how big it may be; the pages' own side is documented with the web interface SDK, and the
-- guide Make a web interface puts a first frame on the screen from start to finish.
-- 
-- A mode drives its frames from here:
-- 
-- - **Whether the player has the web layer** - a player's game may run without it (an older game, a player who switched server
--   interfaces off, a layer that failed to start): `IsPlayerWebReady` and `OnPlayerWebStatus`.
-- - **What is on their screen** - `ShowPlayerWebFrame`, `HidePlayerWebFrame`, `DestroyPlayerWebFrame` and
--   `SetPlayerWebFocus` for the frames, `IsPlayerWebFrameReady` and `OnPlayerWebReady` for the moment a page listens, and
--   `SetPlayerCursor` for the player's own cursor.
-- - **What passes between the mode and a page** - `SendPlayerWebMessage` to one frame; the events of `SendClientEvent` to
--   every page whose `events_in` lets it receive the name; a page's `emitServer`, which arrives in `OnClientEvent` with the
--   frame's name as its `source`; and `JsonEncode` and `JsonDecode` for the JSON on this side.
-- - **The loading screen** - `SetPlayerLoadingHandover` gives the interface's loading page the mode's data while the level
--   loads, and `ClosePlayerLoadingScreen` ends a loading screen that the interface asked to keep up until the mode says so.
-- - **Keys** - the keys a mode declares with `RegisterKeyBinding` reach the pages as well as `OnPlayerKeyBinding`: a page's
--   `KcdMp.onKeyBinding` hears the press and the release.
-- 
-- The server keeps no picture of a player's screen. A call answers `true` when the request was **handed to the player's game**,
-- not when it was done: the frame's `focus` setting, the player's own switches and a page that failed can still turn it down
-- afterwards. A call that cannot even be handed over answers `false` and the reason in words, the same few everywhere:
-- `"no such player"`, `"no web interface"` (this server has none), `"the player has no web layer"` (their game runs none, or it
-- failed) and `"no such frame"` (the name is not a frame of the interface in force). What comes back from a player's game - its
-- state, a page's report, a page's event - is that game's word: check it as you would any other input from a player.
-- 
-- A reload of the mode leaves the players' frames where they are: the pages stay on screen with their state
-- and the new mode hears `OnPlayerWebStatus` and, for each frame that is ready, `OnPlayerWebReady` again.

---**Called by the server** - A player's web layer changed state - or the state it had when the player joined.
---
---`status` is one of four words: `"off"` (the player's game runs no web layer: an older game, or the player turned server
---interfaces off), `"starting"`, `"ready"` and `"failed"`, and then `reason` says why in a short text from the player's
---game (empty for the other three). Show frames from `"ready"` on (a request made while the layer is `"starting"` is
---accepted and waits for it); a `"failed"` or `"off"` player keeps the standard interface and needs a mode that has
---something else for them - see `RegisterUiFallback`.
---
---The callback also runs **once right after `OnPlayerConnect`** with the state the player's game reported as it joined -
---not for a player whose game reported none. A layer that flips between states faster than twelve times and then once
---every two seconds is not announced every time (the server log says so); `IsPlayerWebReady` always has the newest state.
---@param pid number the player
---@param status string `"off"`, `"starting"`, `"ready"` or `"failed"`
---@param reason string why the layer failed, as a short text from the player's game; `""` for the other states
function OnPlayerWebStatus(pid, status, reason) end

---**Called by the server** - A frame of a player's web interface has loaded its page and is listening.
---
---The page has called `KcdMp.ready()` - the page's script does it by itself once the document has loaded, unless the page
---asked to do it by hand. From now on it receives what the mode sends it without any waiting; what was sent earlier
---was kept for it and has just been handed over. The callback runs **again each time the frame's page loads anew** (a
---frame made again, an interface that changed and was re-read), each time a hidden frame that was ready is shown again
---with `ShowPlayerWebFrame` (its page is the same one, and so is everything it kept), and after a
---reload once for every frame that is ready. Hiding a frame and showing it again from inside this
---callback would run it again, so a mode that does that loops - the server holds such calls back to a few a second.
---A frame that says it is ready more often than that is ready at once (`IsPlayerWebFrameReady` says so), and its call
---comes as soon as the server allows: a few hundred frames shown within a moment may wait a little, never lost.
---
---A player's game says this for itself: a modified game may say it for a frame that is not ready or never say it. Use it
---to send a page its first data, not to prove anything about the player.
---@param pid number the player
---@param frame string the frame's name, as `ui.toml` gives it
function OnPlayerWebReady(pid, frame) end

---**Called by the server** - A page of a player's web interface raised a script error.
---
---Only when the server asks for them with `[client] ui_report_errors = true` (see
---the server configuration); without it an error stays in the player's own log.
---At most five errors a minute per player reach the mode, and each one is also a line in the server log. `message` is
---cut to 1024 characters and `source` to 256 and both are cleaned of control characters; `source` is the page's file
---as its own frame knows it (`panel/panel.js`), `line` the line in it, `0` when the page did not say.
---
---The text is what a player's game sent: show it to an admin, never to other players, and never act on it.
---@param pid number the player
---@param frame string the frame's name
---@param message string what went wrong, as the page's script reports it
---@param source string the file the error came from, `""` when unknown
---@param line number the line in it, `0` when unknown
function OnPlayerWebError(pid, frame, message, source, line) end

---Whether a player's game runs the web layer and it is ready.
---
---`true` only in the state `"ready"` (see `OnPlayerWebStatus`); `false` for `"off"`, `"starting"` and `"failed"` and for a
---player who is not connected. It is the question to ask before a mode counts on a frame: a player without the web layer
---needs the same thing said in the chat or by a screen of a client script.
---@param pid number the player
---@return boolean `true` when the player's web layer is ready
function IsPlayerWebReady(pid) end

---Whether a frame of a player's web interface has loaded its page and is listening.
---
---`true` from the moment the frame's page said it was ready (`OnPlayerWebReady`) until the page is gone - the frame was
---removed, the interface no longer has it, or the player's web layer stopped. A frame that is only hidden is still ready.
---`false` for a frame that was never shown, one whose page is still loading, an unknown frame name and a player who is not
---connected.
---@param pid number the player
---@param frame string the frame's name
---@return boolean `true` when the page is listening
function IsPlayerWebFrameReady(pid, frame) end

---Shows a frame of the web interface on a player's screen.
---
---The frame is made if it is not there yet (its page loads, then `OnPlayerWebReady` follows); a frame that was hidden
---with `HidePlayerWebFrame` is drawn again **as it was** - the same page, no reload.
---
---A request that arrives before the player's game has the interface (its files are still being downloaded) waits for it,
---up to half a minute, and is done in the order it was made. Showing a frame does not give it the keyboard or the mouse:
---that is `SetPlayerWebFocus`.
---
---The answer is `true` when the request was handed to the player's game; `false` and the reason when it could not be:
---`"no such player"`, `"no web interface"`, `"the player has no web layer"` or `"no such frame"`.
---@param pid number the player
---@param frame string the frame's name, as `ui.toml` gives it
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"no such frame"`, `"the player has no web layer"` ...)
---@return string reason
function ShowPlayerWebFrame(pid, frame) end

---Takes a frame of the web interface off a player's screen without closing it.
---
---The frame stays alive: its page keeps running and keeps its state, messages and events still reach it, and
---`ShowPlayerWebFrame` draws the same page again at once. A hidden frame gives up the keyboard and the mouse it held and
---cannot take them until it is shown.
---
---The answer is `true` when the request was handed to the player's game; `false` and the reason when it could not be:
---`"no such player"`, `"no web interface"`, `"the player has no web layer"` or `"no such frame"`.
---@param pid number the player
---@param frame string the frame's name
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function HidePlayerWebFrame(pid, frame) end

---Closes a frame of the web interface on a player's screen and frees the memory its page used.
---
---A frame that is hidden with `HidePlayerWebFrame` stays alive - its page keeps running and keeps everything it loaded,
---which is what makes showing it again instant. A frame closed with this call is gone: its page ends, the memory it used is
---freed, it gives up the keyboard and the mouse, and `IsPlayerWebFrameReady` says `false` for it. `ShowPlayerWebFrame`
---makes it again, its page loaded from the start (and `OnPlayerWebReady` follows once it listens). Close the screens a
---player opens once - a character creator, a login, a long list - and hide the ones they open again and again.
---
---Closing a frame that is not open does nothing and still answers `true`. A frame that draws one of the game's interface
---pieces for the player (its chat, its scoreboard ... - `SetPlayerInterface`) is made again at once by the game.
---
---The answer is `true` when the request was handed to the player's game; `false` and the reason when it could not be:
---`"no such player"`, `"no web interface"`, `"the player has no web layer"` or `"no such frame"`.
---@param pid number the player
---@param frame string the frame's name
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function DestroyPlayerWebFrame(pid, frame) end

---Gives a frame the keyboard and the mouse cursor, or takes them back.
---
---A frame that has the **cursor** gets the mouse: the player can click in its page. A frame that has the **keyboard** gets
---the keys: typed letters go to the page's text fields and the game does not see them. `keepInput` lets a frame hold the
---keyboard without shutting the game's out - the game still gets the player's keys while no text field of the page has
---the focus, so a player can walk with a panel open; it does nothing without `keyboard`. With neither `keyboard` nor
---`cursor` the frame **gives its focus up**.
---
---The frame's `focus` setting in `ui.toml` decides what a request gets, so a server cannot grab a player's keyboard behind
---their back: `"never"` refuses every request; `"input"` (the default) grants the cursor at once and the keyboard only
---within five seconds of the player's own click or key press in that frame; `"open"` grants the cursor at any time and the
---keyboard **at once together with it** - a menu the server opens gets the keys straight away, Esc included (a keyboard
---asked for without the cursor still waits for the player's first click in the frame). A frame that is hidden takes no
---focus. The answer is `true` when the request was handed to the player's game - whether the frame got the focus is decided
---there.
---
---The answer is `false` and the reason when the request could not be handed over: `"no such player"`,
---`"no web interface"`, `"the player has no web layer"` or `"no such frame"`.
---@param pid number the player
---@param frame string the frame's name
---@param keyboard boolean `true` to give the frame the keyboard
---@param cursor boolean `true` to give the frame the mouse cursor
---@param keepInput? boolean `true` to let the game keep the player's keys while the frame has the keyboard
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetPlayerWebFocus(pid, frame, keyboard, cursor, keepInput) end

---Brings the player's cursor up in the world, or takes it away.
---
---The player's own cursor - the one their cursor key (left Alt held for a second, unless they chose another key in the
---launcher) brings up: the game's pointer over the world while they can still walk, its clicks going to the web interface
---under it and to a client script's OnCursorClick. This is the same switch
---the key turns over and a client script's SetCursorShown sets, for a mode
---that has no client script of its own.
---It is not a web call: the server needs no web interface and the player no web layer.
---
---A frame of the web interface that wants the clicks for itself takes the cursor with `SetPlayerWebFocus` instead - that
---one also keeps the mouse from the game's look while the frame has it.
---
---A request made while the player is not in the world yet - the loading screen of their spawn - is kept until they are, for
---a minute at most. One of the game's own menus, a load and the end of the session take the cursor away again, and the
---player's key still turns it over: a mode that wants it up again asks again. The answer is `true` when the request was
---handed to the player's game, `false` and `"no such player"` otherwise.
---@param pid number the player
---@param shown? boolean `true` (or nothing) brings the cursor up, `false` takes it away
---@return boolean ok `true`, or `false, reason` - `"no such player"`
---@return string reason
function SetPlayerCursor(pid, shown) end

---Sends one page a message - a table, a text, a number or a boolean.
---
---The page's `KcdMp.onMessage` handler receives **exactly the value** that was sent: a table arrives as an object or an
---array, a text as a text. Messages and events reach a page in the order they were sent; one for a page that is not ready
---yet is kept for it (up to 256 messages or 1 MB per frame - past that the oldest are dropped) and handed over once
---`OnPlayerWebReady` has run. A hidden frame receives its messages as well. Use `SendClientEvent` for what should
---reach every page that listens for a name rather than one frame.
---
---`data` is written as JSON by `JsonEncode`, under the same rules. A message is at most **60000 bytes** of JSON. The
---answer is `true` when it was handed to the player's game; `false` and the reason otherwise: `"no such player"`,
---`"no web interface"`, `"the player has no web layer"`, `"no such frame"`, `"no data"` (the value is `nil`),
---`"too big"`, `"reserved key"` (a table with a `__kcdmp` key at the top: that key is how the game itself talks to a page)
---or what `JsonEncode` says about a value it cannot write.
---@param pid number the player
---@param frame string the frame's name
---@param data table|string|number|boolean the value the page receives
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"too big"`, `"no such frame"` ...)
---@return string reason
function SendPlayerWebMessage(pid, frame, data) end

---A value as JSON text.
---
---The rules, the same on the server and in a client script:
---
---- a table whose keys are exactly `1` to `n` (`n` at least 1) is an **array**; an **empty table is `[]`**; any other table
---  is an **object**, its number keys written as texts and its keys in order - a key that is neither a text nor a number
---  is an error;
---- `nil` is left out of a table, and `JsonEncode(nil)` is `null`;
---- an integer is written as an integer, **but one beyond 2^53** - more than a page's numbers can hold exactly - is
---  written as a text of its digits; any other number as the shortest text that reads back the same; `NaN` and the
---  infinities are an error;
---- texts stay UTF-8, with `"`, `\` and the control characters escaped and `/` left alone;
---- a table nested more than 32 deep, one that holds itself, and a function or any other value that is not data
---  are errors.
---
---An error is not raised: the function returns `nil` and the reason.
---@param value any a table, a text, a number, a boolean or `nil` (written as `null`)
---@return string|nil the JSON text, or `nil` and the reason (`"NaN and infinity have no JSON form"`, `"a function cannot be encoded"` ...)
---@return string
function JsonEncode(value) end

---JSON text as a value.
---
---The reverse of `JsonEncode`, under the same rules: an object becomes a table with text keys, an array a table with the
---keys `1` to `n`, a JSON `null` inside them leaves the place empty (in an array the other values keep their positions:
---`[1,null,3]` has `t[1]` and `t[3]`), and an integer beyond 2^53 becomes a text of its digits. The text may be at most
---1 MB and 32 levels deep.
---
---A `null` on its own gives `nil`, so a `nil` result alone does not say the text was wrong - look at the second value.
---Text that is not valid JSON, or is too deep or too big, gives `nil` and the reason. Nothing in the text can run
---anything: what comes back is data.
---@param text string one JSON value
---@return any the value - or `nil` and the reason when the text could not be read
---@return string|nil
function JsonDecode(text) end

---Gives a screen the mode has twice - a web frame and a client script's own - one name to be sent events by.
---
---A mode that wants a login screen for everybody has two: the web frame, for players whose game has the web layer, and a
---screen drawn by a client script for the rest. `RegisterUiFallback("login", "loginbox")` says that the screen's events
---are named after the frame - `login.open`, `login.error` - and that the client script's twin listens for the same names
---under the prefix `loginbox`. From then on `SendClientEvent` and `SendClientEventToAll` send `"login.open"` to a player
---whose web layer is starting or ready and whose interface has a frame `login`, and `"loginbox.open"` to everyone else. The
---names of the events that come back are not changed: the page's arrive as `login.*` with the frame as their `source`, the
---twin's as whatever it sends, with the source `"lua"`.
---
---The choice is made for each event, at the moment it is sent, so a player whose web layer fails while the screen is open
---is sent the twin's events with no twin open: close the screen and open it again in `OnPlayerWebStatus` when the
---status is `"failed"`.
---
---The prefix may end in a dot, which is ignored. A reload of the mode empties the list of registered
---screens, so a mode registers them where it is made again, in `OnGameModeInit`. The answer is `true`, or `false` and
---the reason when the frame name is not lower-case letters, digits and `-`, or the prefix is empty.
---@param frame string the frame's name, as `ui.toml` gives it
---@param luaEventPrefix string the prefix of the events the client script's twin listens for
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function RegisterUiFallback(frame, luaEventPrefix) end

---Gives a player's loading page data of the mode's while the level loads - a table, a text, a number or a boolean.
---
---The loading screen is the first thing a player sees, long before the mode can send anything through a page: the level is
---still loading and the player's game is busy with it. This is the one call that reaches the game **during** the load - it is
---sent at once, not at the end of the tick - so a loading page can greet the player by name, show the server's rules or
---tell what the round is, and the player's game keeps the data for the interface's loading page until the session ends. Call
---it in `OnPlayerConnect`; a reload runs that again for every player, so the data is sent again.
---
---`data` is written as JSON by `JsonEncode`, under the same rules, and is at most **16384 bytes** of JSON. The answer is
---`true` when it was handed to the player's game; `false` and the reason otherwise: `"no such player"`, `"no data"` (the
---value is `nil`), `"too big"`, `"reserved key"` (a table with a `__kcdmp` key at the top) or what `JsonEncode` says about
---a value it cannot write. What comes back from the player's game is never part of this: the handover goes one way.
---@param pid number the player
---@param data table|string|number|boolean the value the loading page receives
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"too big"`, `"no data"` ...)
---@return string reason
function SetPlayerLoadingHandover(pid, data) end

---Ends a player's loading screen - one that the interface asked to keep up until the mode says so.
---
---Normally the loading screen ends by itself when the player has spawned. An interface can ask for more in its `ui.toml`:
---`manual_shutdown = true` under `[components.loading]` keeps the screen over the game **past the spawn** until this call,
---until the player's client script calls its own `CloseLoadingScreen` or the loading page calls `loading.done`, or - the
---limit - 240 seconds after the world is ready. That is the time for the mode to load a character, or to let a page finish, before the player sees the world. A
---close that comes before the player has spawned waits for the spawn. (`cursor = true` under the same heading asks for the
---mouse cursor on the loading screen, for a page that has something to click.)
---
---Without `manual_shutdown` the spawn ends the screen and this call changes nothing. The screen shows once for a run of the
---game: a player who leaves and joins again without closing the game sees no loading screen the second time. The answer
---is `true` when the request was handed to the player's game; `false` and `"no such player"` when it could not be.
---@param pid number the player
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it (`"no such player"`)
---@return string reason
function ClosePlayerLoadingScreen(pid) end

-- ======== Web surfaces ==========================================================
-- A **web surface** is a page of the mode's web interface drawn **in the world** - a notice board, a shop sign, a screen on a
-- wall - instead of over the game. Its page is declared in the interface's `ui.toml` under `[surfaces.<name>]` (its pixels, how
-- many pictures a second it paints, how near a player must be); the mode places surfaces that show it with `CreateWebSurface`.
-- Every player near a surface sees the page on a board, lit and shadowed by the world like the game's own signs - and each
-- player's game draws **its own copy** of the page: what one copy shows is what the mode sent that player.
-- 
-- ```toml
-- [surfaces.board]
-- page = "board/index.html"
-- width = 768        # pixels, 64-1024 (512 unless it says)
-- height = 512
-- fps = 2            # pictures a second at most, 1-30 (10)
-- range = 30         # metres from the player, 5-100 (30)
-- events_out = ["board.read"]   # the events its page may send ("board.*" unless it says)
-- ```
-- 
-- - **Placing** - `CreateWebSurface` puts one at a point, facing a way, at a size in metres, tilted, glowing, see-through and
--   with a use prompt as its options say; `SetWebSurfacePos`, `SetWebSurfaceSize`, `SetWebSurfaceGlow` and
--   `SetWebSurfaceTransparent` change it, `DestroyEntity`
--   removes it, `GetWebSurfaces` and `GetWebSurfacePage` list them. A surface is an entity of `ENTITY_SURFACE`: it is in
--   `GetEntities` and `SetEntityPrompt` gives it a prompt.
-- - **Feeding the pages** - a player's copy loads when they come near it and is closed when they go away (or when closer
--   surfaces take its place: a game draws the 8 nearest live). `OnPlayerWebSurfaceReady` runs each time a copy has loaded:
--   send it what it should show with `SendPlayerWebSurfaceMessage`; `SendWebSurfaceMessage` sends every copy there is now.
-- - **Hearing them** - a page's `KcdMp.emitServer` arrives in `OnPlayerWebSurfaceEvent`; the use key on a surface's prompt in
--   `OnPlayerUseWebSurface` (and on that player's copy, in its `KcdMp.onSurfaceUse`).
-- 
-- Nobody clicks or types on a surface page. A player whose game runs no web layer sees no surfaces at all. The page side is
-- documented with the web interface SDK ("Pages on surfaces in the world"), and the server folder's
-- `sdk/web/examples/notice-board/` is a working example.

---**Called by the server** - A player's copy of a surface's page has loaded and is listening.
---
---The player came near the surface (within its page's `range`) and their game loaded the page - or loaded it again: a copy
---is closed when the player goes away, when closer surfaces take its place or when the interface changes, and starts afresh
---each time. Send it what it should show: `SendPlayerWebSurfaceMessage` reaches that copy alone.
---
---A player's game says this for itself: a modified game may say it when nothing loaded. Use it to send a page its data, not
---to prove anything about the player.
---@param pid number the player
---@param id number the surface's entity id
function OnPlayerWebSurfaceReady(pid, id) end

---**Called by the server** - A player's copy of a surface's page sent the mode an event.
---
---The page called `KcdMp.emitServer(name, value)`. `name` is one its surface allows in `ui.toml` (`events_out`, the surface's
---own `<name>.*` unless it lists others); `payload` is the value as text - a text as it was sent, anything else as JSON
---(`JsonDecode` reads it back). Events share the player's budget with the client scripts' and the frames' (30 a second):
---a page that sends more loses the rest.
---
---This is the player's game talking: check it like any other input from a player.
---@param pid number the player
---@param id number the surface's entity id
---@param name string the event's name
---@param payload string the value as text
function OnPlayerWebSurfaceEvent(pid, id, name, payload) end

---**Called by the server** - A player pressed the use key on a surface's prompt.
---
---A surface with a prompt (`CreateWebSurface`'s `prompt` option, or `SetEntityPrompt`) shows it in the game's use hint
---when a player looks at it from close by (3.5 metres from its edge); the use key then calls this - and the page's
---`KcdMp.onSurfaceUse` on that player's copy, which can show the player something at once.
---@param pid number the player
---@param id number the surface's entity id
function OnPlayerUseWebSurface(pid, id) end

---Places a web surface - a page of the web interface drawn on a board in the world.
---
---`name` is a surface page of the interface's `ui.toml` (`[surfaces.<name>]`). `x`, `y`, `z` are the board's **middle**;
---`yaw` is the way its face looks, in degrees like a prop's (0 faces +Y) - a board in front of a player who looks at yaw `a`
---faces them at `a + 180`. `width` and `height` are its size in metres (0.1 to 20 each); the page is drawn on the whole
---board, so give it the page's shape (a page of 768 x 512 pixels on a board of 1.5 x 1 m) or the page is stretched.
---
---`options` (all optional):
---
---- `pitch` - degrees about its side-to-side line: positive leans its top away from the one who reads it (a lectern's page)
---- `roll` - degrees about the line through its face (a crooked sign)
---- `glow` - 0 to 1: how much it shines by itself (1 = as bright as the page is drawn, day or night: a screen); 0 = lit by
---  the world alone
---- `transparent` - `true` (or `"blend"`) lets the world show through the page's see-through parts: letters painted on a
---  wall, a sign of its own shape. The page decides what is see-through (`background: transparent` in its CSS, an image's
---  clear parts, a colour with alpha). `"cutout"` is hard-edged instead - a pixel shows when it is at least half opaque,
---  else not at all - and casts a shadow of its own outline. Left out, the board is solid: the page on white. A soft board
---  is lit by the sun and the lamps but not by the light bounced into shade, so on a wall in deep shade its paint reads
---  darker than the wall around it: give it a little `glow`, or make it `"cutout"`
---- `prompt` - the use hint shown when a player looks at it from close by ("Read the notices"); the use key then calls
---  `OnPlayerUseWebSurface`
---- `world` - the virtual world it stands in
---
---The answer is the surface's entity id, or `nil`: the interface declares no such surface page, the size is out of bounds,
---there are 256 surfaces already or the world is full. A server without a web interface has no surfaces.
---@param name string the surface page's name in `ui.toml`
---@param x number the board's middle, metres
---@param y number
---@param z number
---@param yaw number the way its face looks, degrees
---@param width number metres, 0.1-20
---@param height number metres, 0.1-20
---@param options? {pitch?: number, roll?: number, glow?: number, transparent?: boolean|string, prompt?: string, world?: number} the tilt, the glow, see-through or not, the use prompt, the world
function CreateWebSurface(name, x, y, z, yaw, width, height, options) end

---Moves and turns a web surface.
---
---The board's new middle, the way its face looks and its tilt, as `CreateWebSurface` takes them; a pitch or a roll left
---out is 0. The pages on it are not loaded again.
---@param id number the surface
---@param x number the board's middle, metres
---@param y number
---@param z number
---@param yaw number the way its face looks, degrees
---@param pitch? number degrees
---@param roll? number degrees
---@return true , or `false` when `id` is no surface
function SetWebSurfacePos(id, x, y, z, yaw, pitch, roll) end

---Makes a web surface's board bigger or smaller.
---
---Its width and height in metres (0.1 to 20 each). The page keeps its pixels: a bigger board shows the same page bigger.
---@param id number the surface
---@param width number metres
---@param height number metres
---@return true , or `false` when `id` is no surface or a size is out of bounds
function SetWebSurfaceSize(id, width, height) end

---How much a web surface shines by itself.
---
---0 to 1: 0 lets the world's light alone light it (a board on a wall goes dark at night), 1 makes it as bright as its page
---is drawn, day or night (a screen, a lit sign).
---@param id number the surface
---@param glow number 0-1
---@return true , or `false` when `id` is no surface
function SetWebSurfaceGlow(id, glow) end

---Whether the world shows through a web surface's see-through parts.
---
---`true` or `"blend"`: soft - every pixel as see-through as the page draws it (antialiased letters, shadows, a half-clear
---panel); lit by the sun and the lamps but not by the light bounced into shade, so in deep shade it reads darker than the
---wall around it (a little `glow` evens it out). `"cutout"`: hard-edged - a pixel shows when it is at least half opaque,
---else not at all; crisp, lit like the wall, and its shadow has the page's outline - a soft drop shadow in the page
---becomes a hard copy of the letters. `false`: a solid board, the page on white (the default). The page itself decides which of its
---parts are see-through - a page with a background of its own stays solid either way. It changes on every screen at once;
---a player whose game is older than this sees a solid board.
---@param id number the surface
---@param transparent boolean|string `true` / `"blend"`, `"cutout"` or `false`
---@return true , or `false` when `id` is no surface
function SetWebSurfaceTransparent(id, transparent) end

---Every web surface in the world.
function GetWebSurfaces() end

---Which surface page of the interface a web surface shows.
---@param id number the surface
function GetWebSurfacePage(id) end

---Sends every copy of a surface's page a message - a table, a text, a number or a boolean.
---
---Every player who has the surface now (it is near them and their game runs a web layer) gets the message; their copy's
---`KcdMp.onMessage` receives exactly the value sent. A copy still loading keeps it until it is ready; a player whose copy is
---closed gets nothing - their next `OnPlayerWebSurfaceReady` is when to send it again. `data` is written as JSON by
---`JsonEncode`, 60000 bytes at most. The answer is `true`, or `false` and the reason: `"no such surface"`, `"no data"`,
---`"too big"`, `"reserved key"` (a `__kcdmp` key at the top) or what `JsonEncode` says.
---@param id number the surface
---@param data table|string|number|boolean the value the pages receive
---@return boolean ok `true`, or `false, reason`
---@return string reason
function SendWebSurfaceMessage(id, data) end

---Sends one player's copy of a surface's page a message.
---
---As `SendWebSurfaceMessage`, for one player. The reasons for `false` add `"no such player"`, `"the player has no web
---layer"` and `"the player does not have the surface ..."` (too far, or another world).
---@param pid number the player
---@param id number the surface
---@param data table|string|number|boolean the value the page receives
---@return boolean ok `true`, or `false, reason`
---@return string reason
function SendPlayerWebSurfaceMessage(pid, id, data) end

-- ======== Key bindings ==========================================================
-- A mode that wants a key of its own - "open the map", "whistle for the horse", "raise a hand" - does not know which keys a
-- player has free. It **declares** a key binding instead: a name, a line saying what it is for and the key it starts on. Every
-- player's game is told the list when they join (and again when it changes), and the mode hears the presses:
-- 
-- - **The server** - `OnPlayerKeyBinding`, with the player, the binding's name and whether the key went down or came up.
-- - **The player's game** - a client script's `OnKeyBinding`, and the pages of the web interface through `KcdMp.onKeyBinding`,
--   each with the same name and the same press.
-- 
-- A key that is bound **belongs to the mode**: the game does not see it while it is bound. Some keys can never be bound - F9,
-- F12, Esc, Tab, Enter, the Windows keys, G and T (the emote wheel), the keys that walk, jump, crouch and sprint, the player's
-- push-to-talk key, the key that switches to third person (F3 unless the player chose another), the voice level key (left Ctrl unless
-- the player chose another) and the two keys that scroll the chat - and a binding is silent while the chat box or the F9 window is open,
-- one of the game's own menus is up, or a page or a client script holds the keyboard.
-- 
-- A player can bind another key for any of the mode's bindings - the game keeps the choice for each server. A default key
-- that is one of the keys above leaves the binding without a key until the player picks one. There is no menu for picking yet:
-- a player uses the console command `KcdMp_bind` in the F9 window, when the server has opened it, so a mode chooses its defaults
-- as the keys most players will use.
-- 
-- A press is heard at most 20 times a second from one player; more is dropped and never counts against them. A release is never
-- dropped: the mode hears one for every press it heard, so it never holds a key down for good. The server does not tell a mode
-- which keys a player holds now: a mode that needs that keeps its own record.

---**Called by the server** - A player pressed or let go of a key the mode declared.
---
---`name` is always one the mode declared with `RegisterKeyBinding` - a press of any other name is dropped by the server -
---and it comes whichever physical key the player has bound to it. `pressed` is `true` when the key went down and `false`
---when it came up. A held key is reported down once and up once (its repeats are not sent), and the game lets go of every
---key it holds when its window loses the focus. A modified game or a reload of the mode between the press and the release
---can still break that pairing, so a mode that must not act twice, or must not leave something on, keeps its own record of
---who is holding what.
---
---The press is the player's game's word: a modified game may send presses of a registered name that no key made. Use a
---binding to ask for something the player may do anyway, and check the rest as you would any input from a player.
---@param pid number the player
---@param name string the binding's name, as the mode declared it
---@param pressed boolean `true` when the key went down, `false` when it came up
function OnPlayerKeyBinding(pid, name, pressed) end

---Declares a key the mode wants - a name, what it is for and the key it starts on.
---
---Every player's game is told the list of bindings when they join and whenever it changes, so a binding declared later
---reaches the players who are already in. The player's own choice of key for a binding, when they made one, wins over
---`defaultKey`; the game keeps it for the server.
---
---The **name** is 1 to 32 of `a-z 0-9 _ . : -` (capitals are lowered): the name `OnPlayerKeyBinding` answers to, and
---the one a player gives `KcdMp_bind`; dots make readable groups (`"arena.ready"`). `description` is one line, at most 96
---characters, that the player's list of bindings shows. `defaultKey` is the game's own name for a key - `"insert"`, `"end"`,
---`"y"` - or `""` for none until the player binds one; `f9`, `f12`, `escape`, `lwin` and `rwin` are refused. A default that
---the game keeps for itself (see above) is accepted, and leaves the binding without a key until the player picks one, so
---pick keys the game leaves alone.
---
---At most 32 bindings; declaring a name again changes its description and default key. A reload of the mode empties the
---list: declare the bindings in `OnGameModeInit`.
---
---The answer is `true`, or `false` and the reason: `"a binding name is 1-32 of a-z, 0-9 and _ . : -"`, `"the description is
---over 96 characters"`, `"the default key is the engine's name for a key (f2, insert, y ...)"`, `"f9 is reserved"` (or
---whichever it was) or `"too many key bindings (32 at most)"`.
---@param name string the binding's name - 1 to 32 of `a-z 0-9 _ . : -`
---@param description string one line on what the key is for, 96 characters at most
---@param defaultKey string the key it starts on, the game's name for it (`"insert"`); `""` for none
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function RegisterKeyBinding(name, description, defaultKey) end

-- ======== Quests ================================================================
-- A mode's quests appear in the game's own **journal**: in its Main, Side and Task lists, with the description and a line for
-- each objective in its diary. The HUD announces them the game's way ("Side quest started", an objective done, "Quest
-- completed"), and an objective's marker shows as a lettered quest marker on the compass and the world map. Every player
-- sees their own journal: the mode defines a quest once and then moves each player's progress on its own.
-- 
-- A **definition** is a table: a `key` (the mode's own name for the quest, below), a `name`, a `description` (the diary's
-- text), a `kind` (`"main"`, `"side"` or `"task"`) and up to 16 `objectives`. An objective is its text alone, or a table with
-- the `text`, the diary's line for each state (`log`
-- while it is active, `updatedLog`, `doneLog`, `failedLog`), an optional `marker` and `active = true` for the ones a player
-- starts with (none marked: the first). A marker is a point `{x =, y =, z =}` (metres), a world entity `{entity = id}` or a
-- player's body `{player = pid}`; a marker on an entity or a player follows them as they move. A marker shows while its
-- objective is active or updated and the player tracks the quest in the journal.
-- 
-- A player's **progress** is a quest state - `"active"`, `"done"` or `"failed"` - and a state for each objective: `"hidden"`
-- (not in the journal yet), `"active"`, `"updated"`, `"done"` or `"failed"`. Objectives are numbered from 1 in the order of
-- the definition. Every function that changes a player's progress takes `silent` last: `true` changes the journal without the
-- HUD's banner.
-- 
-- A player holds at most **8 main, 32 side and 16 task quests** at once; a finished quest counts until it is removed. A player
-- whose game cannot show quests (an older version of the game client) still has them on the server; `CanPlayerShowQuests`
-- tells.
-- 
-- **Saving a player's quests.** The server forgets a player's quests when they leave, and a quest's id only lasts until the
-- server restarts (the ids follow the order the mode makes its quests in). So give every quest a mode keeps a **key** - a
-- name of your own such as `"abbots_errand"`: 1-64 letters, digits and `_ . : -`, one quest's at a time. Save each quest of
-- `GetPlayerQuests` by its `key` (with its state and objectives) when the player leaves, and give them back at the next
-- login with `SetPlayerQuest`, which is silent unless told otherwise. Every function here takes a quest's id **or its key**,
-- and `GetQuestByKey` turns a key into this run's id.

---Defines a quest - its name, description, kind and objectives.
---
---Nobody has the quest yet: give it to players with `StartPlayerQuest` or `SetPlayerQuest`. Refused for a definition
---without a name, a name over 96 characters, a description over 2000, more than 16 objectives, an objective text over 160
---characters, a diary line over 400, an unknown kind, a marker that is not one, or a `key` that is not 1-64 letters, digits
---and `_ . : -` or is another quest's already; the 1024th quest is the last.
---@param definition table `{key =, name =, description =, kind = "main" | "side" | "task", objectives = {...}}` (the intro above)
---@return number the quest's id; `nil` and the reason when refused
function CreateQuest(definition) end

---Gives a quest new texts, a new kind or other objectives.
---
---Every player who holds the quest sees the change at once, their progress kept; an objective added is hidden for them
---until set. A definition without a `key` keeps the quest's key. Refused like `CreateQuest`, and when a new kind would
---give a player more quests of it than they can hold.
---@param id number|string the quest's id or key
---@param definition table the whole new definition
function UpdateQuest(id, definition) end

---Removes a quest from every journal and forgets it.
---
---Its id and its key may be given to a quest made later.
---@param id number|string the quest's id or key
---@return boolean `false` when there is no such quest
function DestroyQuest(id) end

---The ids of every quest the mode made.
---@return table `{id, ...}`
function GetQuests() end

---The id of the quest with a key.
---
---A quest's id lasts until the server restarts; its key is the mode's own. A mode saves its players' quests by key and finds
---each one again with this - or hands the key itself to any quest function, which takes either.
---@param key string the quest's key, as given to `CreateQuest` (upper and lower case differ)
---@return number the quest's id; `nil` when no quest has the key
function GetQuestByKey(key) end

---A quest's definition.
---
---The same shape as `CreateQuest` takes, with its `key` (`nil` when it has none); every objective is a table with its `text`, `log`, `updatedLog`, `doneLog`, `failedLog`, `marker` and `active`.
---@param id number|string the quest's id or key
---@return table the definition; `nil` when there is no such quest
function GetQuestInfo(id) end

---Puts a quest into a player's journal.
---
---The quest is active, with the objectives the definition marks `active` shown (none marked: the first). The HUD announces
---it unless `silent`. Refused when the player holds the quest already or holds as many quests of its kind as they can.
---@param pid number the player
---@param id number|string the quest's id or key
---@param silent? boolean `true` = no HUD banner
function StartPlayerQuest(pid, id, silent) end

---Sets one objective's state for a player.
---
---`"active"` shows the objective (and its marker), `"updated"` keeps it open with the HUD's "updated" banner, `"done"` ticks
---it off, `"failed"` crosses it, `"hidden"` takes it out of the journal. Refused for a quest the player does not hold, an
---objective the quest does not have or an unknown state.
---@param pid number the player
---@param id number|string the quest's id or key
---@param objective number the objective's number, from 1
---@param state string `"hidden"`, `"active"`, `"updated"`, `"done"` or `"failed"`
---@param silent? boolean `true` = no HUD banner
function SetPlayerQuestObjective(pid, id, objective, state, silent) end

---Finishes a quest for a player.
---
---The HUD announces it unless `silent`; the quest moves to the journal's done quests and its objectives stay as they are.
---@param pid number the player
---@param id number|string the quest's id or key
---@param silent? boolean `true` = no HUD banner
function CompletePlayerQuest(pid, id, silent) end

---Fails a quest for a player.
---
---The HUD announces it unless `silent`; the quest moves to the journal's done quests.
---@param pid number the player
---@param id number|string the quest's id or key
---@param silent? boolean `true` = no HUD banner
function FailPlayerQuest(pid, id, silent) end

---Takes a quest out of a player's journal.
---
---The player may get it again later. Frees its place among the quests of its kind the player can hold.
---@param pid number the player
---@param id number|string the quest's id or key
---@return boolean `false` when the player does not hold it
function RemovePlayerQuest(pid, id) end

---Sets a player's whole record of a quest at once - a restore at a login.
---
---The player gets the quest when they do not hold it yet (the limits apply). Objectives left out of the list are hidden.
---Silent unless `silent` is `false`: a restore shows no banner.
---@param pid number the player
---@param id number|string the quest's id or key
---@param state string `"active"`, `"done"` or `"failed"`
---@param objectives table each objective's state in order, `{"done", "active", ...}`
---@param silent? boolean `false` = with the HUD's banners
function SetPlayerQuest(pid, id, state, objectives, silent) end

---A player's own marker for one objective.
---
---A point `{x =, y =, z =}`, an entity's id (or `{entity = id}`), `{player = pid}` for a player's body, `false` for no marker,
---`nil` for the definition's marker again. Other players keep theirs.
---@param pid number the player
---@param id number|string the quest's id or key
---@param objective number the objective's number, from 1
---@param target? table the marker (above)
function SetPlayerQuestMarker(pid, id, objective, target) end

---A quest as a player has it.
---@param pid number the player
---@param id number|string the quest's id or key
---@return table `{key =, state =, objectives = {state, ...}}`; `nil` when the player does not hold the quest
function GetPlayerQuest(pid, id) end

---Every quest a player holds, in the order they got them.
---@param pid number the player
---@return table `{{id =, key =, state =, objectives = {state, ...}}, ...}` (`key` is `nil` for a quest without one)
function GetPlayerQuests(pid) end

---Whether a player's game shows quests in its journal.
---
---An older version of the game client does not; the server keeps that player's quests all the same.
---@param pid number the player
---@return boolean
function CanPlayerShowQuests(pid) end

-- ======== The game's texts ======================================================
-- Every text the game shows from its own tables has a **key**: a place on the world map (`location_opatovice` is
-- "Opatowitz"), the fast travel's question (`ui_fasttravel_kut_opatovice_question`), a Codex entry's title
-- (`ui_codex_name_opatovice`) and its page (`ui_codex_cont_opatovice`), the map legend's lines, an item's name, a quest's
-- line. A mode gives a key **its own text** and every player sees that text wherever the game shows the key, while they are
-- on the server - nobody installs anything, and leaving the server gives the game its own texts back.
-- 
-- A text is for **every language** or for **one** - a code (`"en"`, `"de"`, `"cs"`, `"ru"`, `"zh-cn"`, `"zh-tw"` ...) or the
-- game's own name for it (`"english"`, `"german"`, `"chineses"`). A player sees their own text first (`SetPlayerTextOverride`),
-- then the one for their game's language (`GetPlayerLanguage`), then the one for every language, then the game's own.
-- 
-- A whole file goes in at once with `LoadTextOverrides`: a translation's own table - the game's `text_ui_*.xml` format, so the
-- rows of a localisation mod can be used as they are - or a small JSON file of key to text. Changes reach the players at once;
-- a screen that is open shows them the next time it opens (the world map names only the places the player has discovered, as the
-- game always does). The texts are the mode's: a reload clears them,
-- so set them in `OnGameModeInit`.
-- 
-- The keys are the game's: the world map's place names, its legend and the fast travel are listed in
-- the map texts and each Codex entry's two keys in the Codex entries. A text may use the game's own markup, as its texts do
-- (`<h>` for a highlighted word, `<paragraph>` in a Codex page). A text that starts with `@` names another key of the game's.

---Shows the mode's own text for one of the game's texts, for every language or one.
---
---`key` is the key without its `@`, in any case. The text replaces the game's own on every player's screen whose game runs
---in `language` - or every player's when it is left out (a language's own text wins over it). `nil` or `""` takes the
---override away: the game's own text again.
---
---Refused for a key that is not one (letters, digits, `_ - .`, at most 128), a language that is none, a text over 16 KB, or
---when the server holds 8 MB of texts already.
---@param key string the game's key (`"location_opatovice"`)
---@param text string|nil the text shown for it; `nil` or `""` = the game's own again
---@param language? string `"de"`, `"german"` ... - only for players whose game runs in it; left out = every language
---@return boolean `false` when refused
function SetTextOverride(key, text, language) end

---The mode's text for a key and a language, if it gave one.
---
---Only what `SetTextOverride` or `LoadTextOverrides` gave - never the game's own text.
---@param key string the game's key
---@param language? string a language; left out = the text for every language
---@return string the text; `nil` when the mode gave none
function GetTextOverride(key, language) end

---Takes away every text the mode gave, or every text of one language.
---@param language? string only this language's texts; left out = all of them
---@return number how many texts were taken away
function ClearTextOverrides(language) end

---Reads a file of texts - the game's own table format or a JSON object - for every language or one.
---
---`file` is a path in the game mode's folder (the folder its `.lua` file is in). Two formats:
---
---- the game's own localisation table, as a translation keeps it (`.xml`): every `<Row>`'s first `<Cell>` is the key and
---  its last `<Cell>` the text - the files of a localisation mod (`text_ui_quest.xml` ...) work as they are;
---- a JSON object of key to text (`.json`): `{"location_opatovice": "Kingsbridge"}`.
---
---Each text is set as `SetTextOverride` would; a key or text it refuses is counted in the server's log.
---@param file string the file, in the mode's folder
---@param language? string the language its texts are for; left out = every language
---@return number the texts taken; `nil` and the reason when the file cannot be read
function LoadTextOverrides(file, language) end

---One player's own text for a key - theirs alone, over the server's.
---
---For a text that differs from player to player: a place their character named, a Codex page written for them. It holds
---whatever their language and lasts their visit. `nil` or `""` takes it away (the server's text, or the game's, again).
---@param pid number the player
---@param key string the game's key
---@param text string|nil the text; `nil` or `""` = no text of their own
---@return boolean `false` for an unknown player, a bad key, a text over 16 KB or past their 256 KB
function SetPlayerTextOverride(pid, key, text) end

---The player's own text for a key, if the mode gave one.
---@param pid number the player
---@param key string the game's key
---@return string their own text; `nil` when none
function GetPlayerTextOverride(pid, key) end

---The language the player's game shows its texts in.
---
---A code - `"en"`, `"cs"`, `"de"`, `"fr"`, `"es"`, `"it"`, `"pl"`, `"ru"`, `"pt"`, `"tr"`, `"uk"`, `"ja"`, `"ko"`,
---`"zh-cn"`, `"zh-tw"`, `"vi"`. Known once their level has loaded: from `OnPlayerRequestSpawn` on, `nil` in
---`OnPlayerConnect`.
---@param pid number the player
---@return string the language's code; `nil` before it is known
function GetPlayerLanguage(pid) end

-- ======== The Codex =============================================================
-- The game's **Codex** - its book of people, places, crafts and history - shows the entries a character has unlocked. Each
-- entry is one of the game's perks: the Codex entries lists all of them with the perk's GUID and name, the
-- page it is on, and the keys of its title and its page.
-- 
-- A mode decides **which entries each player has**: `SetPlayerCodexEntry` unlocks one (with the game's "new Codex entry"
-- notice, or silently) or locks it again - a reveal in the middle of a roleplay scene. An unlocked entry is part of the
-- player's progress: `GetPlayerProgress` and `GetPlayerPerks` list it with their other perks, so a mode that saves those
-- saves the Codex too.
-- 
-- A mode also decides **what the game unlocks by itself**: the game gives every character sixteen entries at the start and
-- unlocks more as places are discovered or the story moves. `SetCodexEntryHidden` stops that for an entry - a player who
-- has it loses it, unless the mode gave it to them.
-- 
-- **Your own words in an entry**: its title and its page are texts of the game, worded with `SetTextOverride` - give an
-- entry you do not need a title and a page of your own and unlock it when the story calls for it.

---Unlocks a Codex entry for a player, or locks it again.
---
---`silent` unlocks it without the game's "new Codex entry" notice. A player who is not in the world yet gets it when they
---spawn. An entry `SetCodexEntryHidden` hides is unlocked all the same - the hiding stops the game, not the mode.
---@param pid number the player
---@param entry string the entry's perk - its GUID or the game's perk name (the Codex entries)
---@param unlocked? boolean `true` (the default) unlocks it, `false` locks it again
---@param silent? boolean `true` = no "new Codex entry" notice
---@return boolean `false` for an unknown player or an entry name the server's tables do not know
function SetPlayerCodexEntry(pid, entry, unlocked, silent) end

---Whether a player has a Codex entry unlocked.
---
---As their game last reported it, or as the mode set it since.
---@param pid number the player
---@param entry string the entry's perk GUID or name
---@return boolean
function HasPlayerCodexEntry(pid, entry) end

---Stops the game from unlocking a Codex entry by itself - or lets it again.
---
---A hidden entry is never unlocked by the game itself: not at a character's start, not by a discovered place, not by a
---story event. A player who has it loses it at once (or when they join), unless the mode gave it to them with
---`SetPlayerCodexEntry` - which still unlocks it. The list is the mode's: a reload clears it, so set
---it in `OnGameModeInit`. At most 1024 entries.
---@param entry string the entry's perk GUID or name
---@param hidden? boolean `true` (the default) hides it, `false` lets the game unlock it again
---@return boolean `false` for an entry name the server's tables do not know
function SetCodexEntryHidden(entry, hidden) end

---Whether the mode hides a Codex entry from the game.
---@param entry string the entry's perk GUID or name
---@return boolean
function IsCodexEntryHidden(entry) end

---Every Codex entry the mode hides from the game.
---@return table `{guid, ...}`
function GetHiddenCodexEntries() end

-- ======== The game's screens ====================================================
-- The game's own player screens - the **inventory**, the **character** screen, the world **map**, the **Codex** and the
-- **journal** - are one screen with tabs, each opened by its own key. A mode opens one of them on a player's screen
-- (`OpenPlayerScreen`), closes them (`ClosePlayerScreens` - the loot and trade screens with them), and refuses some to a
-- player for a while (`SetPlayerScreenBlocked`): no inventory for a player in shackles, no map in a blindfold. A refused
-- screen does not open by the player's key or its tab, and closes when it is open.
-- 
-- `OnPlayerScreenChange` says which of them a player opened, switched to or closed. The screens are named `"inventory"`,
-- `"character"`, `"map"`, `"codex"` and `"journal"`; `"other"` is another of the game's screens of that kind (crafting, a
-- horse's saddlebags). The refusals last the player's visit and a reload clears them.

---**Called by the server** - A player opened one of the game's player screens, switched to another or closed them.
---
---Their own key or tab, the mode's `OpenPlayerScreen` or `ClosePlayerScreens`, the screen's own close. A screen the
---mode refuses them never opens, so it never comes here. The answer is not read.
---@param pid number the player
---@param screen string|nil `"inventory"`, `"character"`, `"map"`, `"codex"`, `"journal"` or `"other"`; `nil` = closed
---@param previous string|nil the one before (`nil` = none was open)
function OnPlayerScreenChange(pid, screen, previous) end

---Opens one of the game's player screens on a player's screen.
---
---Switches to it when one of them is open already. The game itself may still say no - while another screen of its own is
---up (a dialogue, a minigame, the Esc menu) nothing opens.
---@param pid number the player
---@param screen string `"inventory"`, `"character"`, `"map"`, `"codex"` or `"journal"`
---@return boolean `false` before the player is in the world, for another name, a screen refused to them, or a game that cannot
function OpenPlayerScreen(pid, screen) end

---Closes the game's player screens on a player's screen - and the loot and trade screens.
---@param pid number the player
---@return boolean `false` before the player is in the world or for a game that cannot
function ClosePlayerScreens(pid) end

---Refuses one of the game's player screens to a player - or allows it again.
---
---Their key and the screens' tab do not open a refused screen, and one open now closes. Set before the player's level has
---loaded (in `OnPlayerConnect`) it holds from their first step. For their visit; a reload clears it.
---@param pid number the player
---@param screen string `"inventory"`, `"character"`, `"map"`, `"codex"` or `"journal"`
---@param blocked? boolean `true` (the default) refuses it, `false` allows it again
---@return boolean `false` for an unknown player or another name
function SetPlayerScreenBlocked(pid, screen, blocked) end

---Whether a screen is refused to a player.
---@param pid number the player
---@param screen string the screen's name
---@return boolean
function IsPlayerScreenBlocked(pid, screen) end

---Which of the game's player screens a player has open.
---
---As their game last reported it (`OnPlayerScreenChange`).
---@param pid number the player
---@return string `"inventory"`, `"character"`, `"map"`, `"codex"`, `"journal"` or `"other"`; `nil` = none
function GetPlayerScreen(pid) end

-- ======== Constants =============================================================

-- Colors
---amber - the server's own lines and the freeroam modes'
COLOR_SERVER = 0xFFD070FF
COLOR_WHITE = 0xFFFFFFFF
COLOR_RED = 0xFF4040FF
COLOR_GREEN = 0x40FF40FF
COLOR_YELLOW = 0xFFFF40FF
---the game's own text gold - the name plates, the HUD
COLOR_GOLD = 0xF6E890FF
---the role-play lavender - `/me` and `/do` lines, the `/ame` bubble
COLOR_PURPLE = 0xC2A2DAFF

-- Body parts
---`head`
BODY_PART_HEAD = 1
---`torso`
BODY_PART_TORSO = 2
---`arm_left`
BODY_PART_ARM_LEFT = 3
---`arm_right`
BODY_PART_ARM_RIGHT = 4
---`leg_left`
BODY_PART_LEG_LEFT = 5
---`leg_right`
BODY_PART_LEG_RIGHT = 6

-- GameText styles
---big, in the middle of the screen
GAMETEXT_CENTRE = 0
---under the top edge
GAMETEXT_TOP = 1
---the lower third, like a subtitle
GAMETEXT_LOWER = 2

-- Objective banner kinds
---a new objective
OBJECTIVE_NEW = 0
---an objective completed
OBJECTIVE_DONE = 1
---an objective failed
OBJECTIVE_FAILED = 2

-- Compass marker kinds
---the quest objective symbol
MARKER_QUEST = 0
---the point-of-interest symbol
MARKER_POINT = 1

-- HUD alignment
HUD_ALIGN_LEFT = 0
HUD_ALIGN_CENTRE = 1
HUD_ALIGN_RIGHT = 2

-- HUD pieces
---the compass strip
HUD_COMPASS = "compass"
---the health and stamina bars - one piece, they hide together
HUD_STATS = "stats"
---the subtitles
HUD_SUBTITLES = "subtitles"
---the action hints
HUD_HINTS = "hints"
---the crosshair dot and the item card
HUD_CURSOR = "cursor"
---the icons of the buffs
HUD_BUFFS = "buffs"
---the info line under the compass (`ShowInfoText`)
HUD_INFO_TEXT = "info_text"
---the game's log toast (`ShowGameLog`)
HUD_GAME_LOG = "game_log"
---one of the game's two event banners (`ShowNotification`, `ShowObjectiveEvent`)
HUD_COMMON_EVENT = "common_event"
---the other event banner
HUD_FANCY_EVENT = "fancy_event"
---the tutorial box (`ShowTutorial`), the party's invitation and the death box
HUD_TUTORIAL_MESSAGE = "tutorial_message"

-- Teams
---no team - what `SetPlayerTeam` takes to remove a player from theirs and `GetPlayerTeam` answers without one
NO_TEAM = -1

-- Stances
---on their feet - standing, walking, running, swimming
STANCE_STANDING = 0
---crouching (sneaking)
STANCE_CROUCHING = 1
---in a horse's saddle
STANCE_MOUNTED = 2
---seated in a cart
STANCE_SEATED = 3

-- Entity kinds
---a player's body - never an entity id a mode holds; players are pids
ENTITY_PLAYER = 0
---a horse (`CreateHorse`)
ENTITY_HORSE = 1
---a pickup lying in the world (`CreatePickup`, a player's drop)
ENTITY_ITEM = 2
---an NPC actor (`CreateActor`)
ENTITY_NPC = 3
---a static mesh (`CreateProp`)
ENTITY_PROP = 4
---a player's dog (`CreateDog`)
ENTITY_DOG = 5
---a horse-drawn cart (`CreateCart`, a route's)
ENTITY_CART = 6
---an animal - a wolf, a boar, a deer ... (`CreateAnimal`)
ENTITY_ANIMAL = 7
---a carry item - a sack, a basket, a bucket carried in the hands (`CreateCarryItem`)
ENTITY_CARRY = 8
---a siege engine - a trebuchet, a cannon, a siege ladder or a pile of stones (`CreateSiegeEngine`)
ENTITY_SIEGE = 9
---an interaction point - an invisible spot with your use prompt (`CreateInteraction`)
ENTITY_INTERACTION = 10
---a web surface - a page of your web interface drawn on a board in the world (`CreateWebSurface`)
ENTITY_SURFACE = 11

-- Shop screens
---the game's own trade screen - the player's side and the vendor's, a basket, "Close deal" (the default)
SHOP_SCREEN_TRADE = 0
---the shop panel - a list with a Buy tab and a Sell tab, driven with the keys
SHOP_SCREEN_PANEL = 1

-- Dog modes
---waits where it is
DOG_STAY = 0
---at its master's heel (what a new dog does)
DOG_FOLLOW = 1
---roams near its master
DOG_FREE = 2
---the game's aggressive mode
DOG_AGGRESSIVE = 3
---the game's search mode
DOG_SEARCH = 4
---the game's hunt mode
DOG_HUNT = 5
---the game's guard mode
DOG_GUARD = 6
---the game's ambush mode
DOG_AMBUSH = 7

-- Rider throws
---a head hit on a low branch or a beam
THROW_HEAD_HIT = 1
---the horse threw them
THROW_HORSE = 2
---the rider's game threw them and the server could not tell why
THROW_OTHER = 3
---the mode's own order (`ThrowPlayerFromHorse`)
THROW_MODE = 4

-- The database
---a NULL parameter value
DB_NULL = "\0null\0"

-- Discovery kinds
---the named places and points of interest found, per level
DISCOVERY_PLACES = "places"
---the books read, global
DISCOVERY_READING = "reading"
---the map pin and the legend's switched-off categories, per level
DISCOVERY_UI = "ui"
---the parts of the world map uncovered (the fog of war, with `[ui] map_fog` on), per level
DISCOVERY_FOG = "fog"

-- Poses
---the pose aliases, alias -> clip
---@type table<string, string>
ACTOR_ANIM = {
    sit = "behavior_sitting_variation01_loop",   -- loops
    wave = "greetings_wave_big_over|once",   -- once
    bow = "greetings_bow|once",   -- once
    nod = "greetings_head_nod_over|once",   -- once
    pray = "pray_stand_long",   -- loops
    chop = "woodchopping_loop_01",   -- loops
    sweep = "sweeping_floor_idle_loop",   -- loops
    smith = "armorsmith_loop",   -- loops
}
