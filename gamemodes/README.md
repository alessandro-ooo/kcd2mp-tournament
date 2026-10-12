# Game modes

The server runs one game mode: the rules of the world - who spawns where, what a chat command does, what a hit
counts for, when a round ends. `[gamemode] script` in `server.toml` (or `--gamemode`) names it.

**A Lua script** is one file in this folder:

```toml
[gamemode]
script = "gamemodes/freeroam.lua"        # the flagship: everyone in one world around the spawn, global chat
# script = "gamemodes/duel_arena.lua"    # /duel queues you; two at a time fight in the arena, nobody else can be hurt
# script = "gamemodes/marker/marker.lua" # the example with a client half: a checkpoint run drawn by a script in each player's game
# script = "gamemodes/plots.lua"         # the building example: admins mark plots, a player claims one and builds on it in the in-game map editor (needs [world] map)
# script = "gamemodes/basicrp.lua"       # the start of a role-play mode: a password box to register and log in on your own database ([gamemode.database]), a player put back where they left with what they carried and wore and their horse (saved the moment it changes, one table row per stack), a character creator for a new character (and /look), a window to build a cart of one's own (/createcart, /despawncart), a town of NPCs with faces of their own (three shops, an innkeeper, a stable master, guards) and web pages (a welcome with the rules at the join, the stable, a menu, notices); everyone who joins is an admin (EVERYONE_ADMIN in the script)
```

Freeroam, BasicRP and the duel arena keep their rules in tables near the top of the script. One is `CAMERA`, the third-person view: freeroam and BasicRP let
every player switch to it with their third-person key (`third_person = "allow"`, F3 unless the player changed it), the duel arena keeps
everyone in first person (`"off"`), and `"force"` would put everyone in third person.

**A mode with a client half** - Lua that runs in the players' games (a mark in the world, a bit of UI, a sound) - lives in a
folder of its own with the client files in `client/` next to it, as `marker/` does:

```
gamemodes/marker/marker.lua        the server half
gamemodes/marker/client/*.lua      sent to every joining player, run in their game in a sandbox, in name order
```

A single-file mode keeps its client half in a folder named after it - `freeroam.lua` + `freeroam/client/hud.lua`, the world
clock at the top right drawn in the game's own typeface with the client API's UI functions, and `basicrp.lua` +
`basicrp/client/`: `account.lua`, the password box a player registers and logs in with, and `creator.lua`, the character
creator - a menu of faces, hair, beards and skins with a preview body only the player sees
(https://docs.kcd-mp.com/guides/character-creator/). Files of one client half share their callbacks: each hands on the events
and keys that are not its own to what the file before it defined, as those two do. `basicrp/ui/` is BasicRP's web interface -
the welcome at the join (the rules and a word to type, with the keyboard and the mouse, before the password box; `WELCOME` in
the script), the stable master's offer, the notices and the menu (https://docs.kcd-mp.com/guides/web-interface/).

The server sends the folder at every join and again at `/reload`; the players do nothing. `[client] scripts` names another
folder; `[client] console` opens the players' F9 window (a development setting). What a client script may use, and what the
sandbox keeps from it: https://docs.kcd-mp.com/lua/client/getting-started/

**A C# plugin** gets a folder of its own here with everything `dotnet publish` produced - the DLL, its `.deps.json` and the
packages it uses (a database driver, for instance). The setting names the DLL:

```toml
[gamemode]
script = "gamemodes/arena/Arena.dll"   # "gamemodes/arena/Arena.dll:MyModes.ArenaMode" when the assembly holds several modes
```

It is built against `sdk/KcdMp.Api.dll` next to this folder (the `.xml` beside it gives your IDE the descriptions).

`""` runs the built-in freeroam. `/reload` in the chat (admins) loads the mode again without a restart; `watch = true`
does it by itself whenever a Lua script changes on disk.

**Your editor knows the API.** `sdk/KcdMp.d.lua` describes every function, callback and constant of the game mode API for
the Lua language server - completion, the documentation on hover, and a warning for a misspelt name or a wrong argument
(`sdk/KcdMp-client.d.lua` does the same for a client script). In VS Code install the "Lua" extension (sumneko / LuaLS) and
open this folder: the `.luarc.json` here already points it at `../sdk`. For a mode in a folder of its own, put a `.luarc.json`
like it next to the script - `{ "runtime.version": "Lua 5.4", "workspace.library": ["../../sdk"] }` - or copy the `.d.lua`
file into the folder. A coding assistant working in the folder reads the same file.

The scripting reference - every callback and function, with examples: https://docs.kcd-mp.com
