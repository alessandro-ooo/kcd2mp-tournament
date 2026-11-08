# KCD2MP Tournament

> **Discontinued:** This gamemode is no longer actively maintained. Contributions are welcome via forks, and I’m always available to review them.

A KCD:MP gamemode for challenging nearby players to configurable duels. The server-side logic is Lua; the in-game duel dialogs and timer are a React/TypeScript web interface.

## Project layout

| Path | Purpose |
|---|---|
| `gamemodes/kcd2mp-tournament/gamemode.lua` | Gamemode lifecycle callbacks and player join/spawn/death handling |
| `gamemodes/kcd2mp-tournament/commands.lua` | Chat commands and disconnect cleanup |
| `gamemodes/kcd2mp-tournament/data.lua` | In-memory player and duel state |
| `gamemodes/kcd2mp-tournament/utils/` | Player, duel, UI and validation helpers |
| `gamemodes/kcd2mp-tournament/frontend/src/` | Duel settings, invite and timer interface |
| `sdk/KcdMp.d.lua`, `sdk/KcdMp-client.d.lua` | Lua server and client API declarations |
| `sdk/KcdMp-web.d.ts` | TypeScript declarations for the in-game web API |
| `KcdMp.Api.xml` | C# API documentation for IDEs |

## First startup

1. Install Node.js and pnpm if they are not already installed.
2. Open a terminal at the frontend project directory:

   ```powershell
   cd gamemodes\kcd2mp-tournament\frontend
   pnpm install
   pnpm build
   ```

   `pnpm install` downloads the React, TypeScript, Vite and other frontend dependencies. `pnpm build` type-checks and bundles the UI into `gamemodes/kcd2mp-tournament/ui/bin/`.

3. The web UI is a React application, not a collection of separate pages served directly from the source folder. `frontend/index.html` is the single HTML entry point: it provides the `root` element, then loads `src/main.tsx`. React mounts `App` there; `App` listens for server events and switches between the duel settings, invite and timer components. Vite compiles those components and their styles/scripts into `ui/bin/index.html` and bundled asset files. The game loads that built `index.html` as the `frontend` frame, as configured in `ui/ui.toml`.
4. Ensure the root `server.toml` selects both the Lua gamemode and its UI directory:

   ```toml
   [gamemode]
   script = "gamemodes/kcd2mp-tournament/gamemode.lua"
   ui = "gamemodes/kcd2mp-tournament/ui"
   ```

   These paths are already set this way in this repository's `server.toml`. The gamemode is Lua, so there is no separate gamemode compilation step: the server loads the Lua files directly. Start or restart the KCD:MP server after building the UI and setting the configuration. When changing frontend code, run `pnpm build` again; when changing Lua, restart the server to load the updated script.

## Server-side functions

### Gamemode callbacks — `gamemode.lua`

| Function | Description |
|---|---|
| `OnGameModeInit()` | Logs the tournament gamemode startup. |
| `OnPlayerConnect(pid)` | Creates player state and sends the welcome and duel instructions. |
| `OnPlayerSpawn(pid)` | Starts the next duel round if the player is in a duel. |
| `OnPlayerDeath(pid, attacker)` | Resolves the current round in favor of the attacker. |

### Commands and disconnects — `commands.lua`

| Function | Description |
|---|---|
| `OnPlayerCommandText(pid, cmd, args)` | Handles `/duel` to open the duel settings interface. |
| `OnPlayerDisconnect(pid)` | Removes an active duel and notifies the connected opponent. |

### Duel helpers — `utils/duel.lua`

| Function | Description |
|---|---|
| `duel.validateSettings(settings)` | Checks the duel payload and validates time (1–3600 seconds), rounds (1–4), option types and selected player. Returns the settings or `false` and an error message. |
| `duel.isShieldItem(info)` | Identifies an item as a shield from its category or name. |
| `duel.isPlayerInDuel(pid)` | Returns the player's duel, or `false`. |
| `duel.findByPlayer(pid)` | Returns the player's duel, or `nil`. |
| `duel.add(playerOne, playerTwo, numberOfRounds, time, useOwnWeapons, isRanked, weaponId, shieldId)` | Creates and stores a duel in the `pending` state. |
| `duel.remove(duelToRemove)` | Restores player control and removes the duel from memory; returns whether it was found. |
| `duel.changeStatus(duelData, newStatus)` | Updates a duel's status. |
| `duel.getData(pid)` | Builds a player and nearby-player summary for a UI; currently uses the default 100 ELO value. |
| `duel.giveEquipment(pid, weaponId, shieldId)` | Gives the selected weapon and shield, if provided. |
| `duel.initiate(duelData)` | Starts a duel, opens the timer interface and begins the first round. |
| `duel.beginRound(duelData)` | Advances the round, positions and heals the players, equips them, and starts the fight after a countdown. |
| `duel.processRound(duelData, winner, loser)` | Validates and records a round result, sends result events, schedules a tied round or removes a completed duel. A tie is represented by `-1, -1`. |

### Player helpers — `utils/players.lua`

| Function | Description |
|---|---|
| `player.add(pid)` | Creates player state if missing; initializes ELO to 100 and wins/losses to zero. |
| `player.get(pid)` | Looks up a player record by server player ID. |
| `player.getRequestingUI(pid)` | Gets the UI route waiting to be opened for a player. |
| `player.setRequestingUI(pid, uiName)` | Sets the UI route to open when the web frame is ready. |

### UI and validation helpers — `utils/ui.lua`, `utils/utils.lua`

| Function | Description |
|---|---|
| `ui.show(pid, keyboard, cursor, keepInput)` | Shows and focuses the `frontend` web frame; reports server errors to the player. |
| `ui.hide(pid)` | Hides the `frontend` web frame. |
| `OnPlayerWebReady(pid, frame)` | Opens the player's pending route when the `frontend` frame finishes loading. |
| `OnClientEvent(pid, name, payload, source)` | Handles frontend requests for nearby players, duel invites, accept/decline actions and round ties. |
| `utils.isIntegerInRange(value, min, max)` | Returns whether a value is an integer within inclusive bounds. |

The shared state in `data.lua` contains `players` and `duels` arrays. A player record tracks their ID, name, requested UI and duel stats; a duel record tracks its participants, status, round results and settings.

## Web interface

`frontend/src/App.tsx` contains `App`, which listens for the `panel.frontend` route event and displays one of three pages:

| Component | Purpose |
|---|---|
| `App` | Maps server-requested routes to the duel pages. |
| `DuelSettingsPage` | Requests player and nearby-player data, then displays the settings form. |
| `DuelInvitePage` | Requests pending invite details; `onInviteButtonClick(action)` emits the accept or decline event. |
| `DuelTimerPage` | Displays the round countdown and result; emits a tie event when its countdown reaches zero. |

The shared `DuelSettingsForm` collects round duration, round count, equipment options and an opponent, then sends the invite. `DuelInviteForm` displays the invitation and invokes its accept/decline callbacks.

Reusable UI components are `DialogBody` (dialog layout), `DialogElo` (ELO comparison), `DialogPlayers` (nearby-player selection), `H1` (heading), and the `Button`, `Checkbox`, `Number` and `Select` form controls. The `cn(...inputs)` helper combines conditional CSS classes and merges Tailwind classes. `main.tsx` mounts the React app.

## Frontend/server events

Events use the `frontend` web frame. `OnClientEvent` ignores events from other sources.

| Event | Direction | Purpose |
|---|---|---|
| `panel.frontend` | Server → web | Navigate to the route in `{ router }`: `duelsettings`, `duelinvite` or `dueltimer`. |
| `panel.frontend.duel.fetch` | Web → server | Request the player's and nearby players' names and ELO. |
| `panel.frontend.duel.fetch.sendresponse` | Server → web | Return the nearby-player list and player summary. |
| `panel.frontend.duel.sendinvite` | Web → server | Submit duel settings and the selected opponent. |
| `panel.frontend.invite.fetch` | Web → server | Request the pending invite. |
| `panel.frontend.invite.fetch.sendresponse` | Server → web | Return opponent and duel settings. |
| `panel.frontend.invite.accept` / `panel.frontend.invite.decline` | Web → server | Accept or reject the pending invite. |
| `panel.frontend.timer.send` | Server → web | Start or reset the timer using the duel duration. |
| `panel.frontend.duel.round.result` | Server → web | Display the round or match result. |
| `panel.frontend.duel.result.tie` | Web → server | Resolve the current round as a tie when the timer expires. |

Event names are also collected in `ui.EMITS_NAMES` in `utils/ui.lua`; UI routes are in `ui.UI_LIST`.

## Current implementation notes

Player and duel state is in memory and resets when the gamemode reloads. New players start at ELO 100, but ELO updates and ranked-duel scoring are not implemented. The settings form currently hides the ranked option; weapon and shield selection is available when the player is not using the own-weapons option.

The repository's SDK declarations cover the larger KCD:MP APIs; they are references for the host API rather than functions implemented by this gamemode. For the complete scripting API, see [sdk/KcdMp.d.lua](./sdk/KcdMp.d.lua), [sdk/KcdMp-client.d.lua](./sdk/KcdMp-client.d.lua), [sdk/KcdMp-web.d.ts](./sdk/KcdMp-web.d.ts), and [KcdMp.Api.xml](./KcdMp.Api.xml).