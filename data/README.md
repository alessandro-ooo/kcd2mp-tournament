# The server's data

What the server keeps and reads here. Four of them come from your own copy of the game: they are
made once with the tools in `tools/` (Windows - the machine the game is installed on) and, for a server
that runs on Linux, copied into this folder there.

| Path | What it is | Where it comes from |
|---|---|---|
| `server.db` | the server's own database: each level's doors, gates, chests and taken items as they stand, and the bans. Made on the first start; nothing to configure. The server remembers no player - accounts are a game mode's own, on the database `[gamemode.database]` names | the server writes it (an older server's `world.json` / `bans.json` found here are imported once and renamed `.imported.json`) |
| `combat/items.json` | the game's weapon and armour numbers, its item, soul, buff, consumable and mesh lists, and its loot tables with every chest's and table slot's place in each level - damage from the game's tables, `/give shortswordBroad` by name, potions and buffs on the server, props by mesh name, chests filled the way the game fills them | `tools/KcdMp.ExportTables.exe` |
| `heightmaps/<level>.hmap` | the level's terrain heights - the movement check and `GetTerrainHeight` | `tools/KcdMp.ExportHeightmap.exe` (starts the game once per level, about a minute each; all three levels by default) |
| `navmesh/<level>.knav` | the level's navigation mesh, the game's own - the NPC actors walk around walls on it, `FindPath` / `IsReachable` / `GetNavmeshHeight` in a game mode | `tools/KcdMp.ExportNavmesh.exe` (reads the level's files, no game run, a second per level; all three levels by default) |
| `collision/<level>.kcol` | the level's collision geometry, the game's own walls, roofs, floors and trees - line of sight on hits (`[validation] line_of_sight`), the floor under a player as the ground, `RayCast` / `IsLineOfSight` / `GetGroundZ` in a game mode | `tools/KcdMp.ExportCollision.exe` (starts the game once per level, some minutes each; all three levels by default) |
| `maps/<level>/` | the server's map of the level: the objects admins placed on it in the game (`/map`) and the game mode made with `CreateMapObject`, and the parts of the level they took out - `map.json`, `objects.json`, `removals.json` (one record a line), a `journal.jsonl` of the last edits and `.bak` copies. Every player's game downloads it at the join and keeps it for the next | the server writes it from the first edit on (`[world] map` in `server.toml` says where). Copy the folder to give another server of the same level the same map; edit the files by hand only while the server is stopped |

Without `combat/items.json` the server runs with the numbers the clients report and knows items, souls and
buffs by their GUIDs only; without a heightmap the terrain check is off for that level; without a navmesh the
actors walk straight lines and `FindPath` answers nothing; without the collision geometry rays answer nothing
and no line of sight is checked. The server says which it found in its first log lines.

The tools find the game through Steam, or ask for its folder in a dialog. Double-click them, or run them
from a terminal with `--help` for the options (`--game <folder>`, `--level all`, ...).
