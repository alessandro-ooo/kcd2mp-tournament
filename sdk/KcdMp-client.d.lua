---@meta

-- KCD:MP (KCD Multiplayer) - the client script API (a player's game), Lua 5.4.
-- Definitions for the Lua language server (LuaLS - the VS Code "Lua" extension and its kin): completion, hover
-- documentation and diagnostics while writing a script. Generated from the reference - do not edit.
-- https://docs.kcd-mp.com

-- ======== Script events =========================================================
-- Named events with a string payload, both ways between the game mode and the client script: the mode's `SendClientEvent`
-- lands in the script's `OnServerEvent`; `SendServerEvent` goes up into the mode's `OnClientEvent`. The payload is
-- whatever string the two halves agree on - a number, a comma list, JSON.

---**Called by the server** - The game mode sent an event to this player's game.
---
---Every event the mode's `SendClientEvent` or `SendClientEventToAll` addressed to this player arrives here, with its name
---and the string it carried. An error inside is logged (`[KcdMp] OnServerEvent: ...`), never fatal.
---@param name string the event's name, as the mode sends it
---@param payload string the string the mode sent (`""` when it sent none)
function OnServerEvent(name, payload) end

---Sends an event to the game mode's OnClientEvent.
---
---The server accepts at most 30 events a second from one client; more is dropped. An event whose name is over 64 bytes
---or whose payload is over 4096 bytes (UTF-8) is not sent at all - never cut - and the refusal is written to the
---client's log, so split a big payload yourself. The payload travels as the string given (`""` without one) - the mode
---trusts it no further than any other input.
---
---The events of the server's web interface pages count against the same budget: the player's script events and their
---pages' events together are at most 30 events and 64 KB (name and payload) a second. What is over it is dropped, and
---a script that sends in bursts should spread them over a few frames. Use `JsonEncode` to send a table.
---@param name string the event's name
---@param payload? string the string to send
function SendServerEvent(name, payload) end

-- ======== State bags ============================================================
-- The game mode's **state bags** as every client sees them: string keys and values the mode set with `SetGlobalState`,
-- `SetPlayerState` and `SetEntityState`. The global and the players' bags arrive whole when the client joins and every change
-- arrives at once; an entity's bag comes with the entity when it enters view and goes when it leaves. Values are strings
-- (`"3"`, `"true"`); a removed key reads `nil`. `OnStateChange` tells a script about changes.

---**Called by the server** - A key of a state bag changed.
---
---`scope` is `"global"`, `"player"` or `"entity"`; `id` the pid or entity id (`0` for the global bag); `value` the new
---string, `nil` when the key was removed. An error inside is logged, never fatal.
---@param scope string `"global"`, `"player"` or `"entity"`
---@param id number the pid or the entity id; `0` for the global bag
---@param key string the key
---@param value string|nil the new value; `nil` = removed
function OnStateChange(scope, id, key, value) end

---One key of the world's bag.
---@param key string the key
---@return string|nil
function GetGlobalState(key) end

---The world's bag as a table.
---
---The live table - read it, do not keep it: a later change lands in the same table.
---@return table `{key = value}`
function GetGlobalStates() end

---One key of a player's bag.
---
---Every player's bag is here from their join on; `pid` `nil` is your own. Gone with the player's session.
---@param pid? number the player; `nil` = yourself
---@param key string the key
---@return string|nil
function GetPlayerState(pid, key) end

---A player's bag as a table.
---@param pid? number the player; `nil` = yourself
---@return table `{key = value}`, empty when the player has no bag
function GetPlayerStates(pid) end

---One key of an entity's bag, while the entity is in view.
---@param id number the entity's id, as the mode's `SetEntityState` names it
---@param key string the key
---@return string|nil
function GetEntityState(id, key) end

---An entity's bag as a table.
---@param id number the entity's id
---@return table `{key = value}`, empty when the entity has no bag or is out of view
function GetEntityStates(id) end

-- ======== The player, the level and the frame ===================================
-- Who this player is and where, the level, the frame hook a script draws from, and a few readings of the world. Everything
-- else a client script does - drawing, sounds, reading the player entity - is the game's own Lua, described in the
-- guide.

---**Called by the server** - Every frame - where a script draws.
---
---The game's drawing functions (`System.DrawLabel`, `System.DrawLine` ...) show what they draw for one frame only, so a
---mark that should stay is drawn again every frame from here; a timer would blink. The argument is the frame's length in
---seconds. An error inside is logged (`[KcdMp] OnFrame: ... (disabled)`) and the callback is switched off, so a broken
---script cannot fill the log sixty times a second. Keep the work small: it runs on the game's thread, every frame. The
---elements of `CreateUiText` and its family need no redrawing - they stay until removed.
---@param dt number the frame time in seconds
function OnFrame(dt) end

---This client's own player id.
---
---Set when the server welcomes the client; `nil` before. The pid the mode sees this player as - the key into the players'
---state bags and the party's members.
---@return number the pid; `nil` before the welcome
function GetPlayerId() end

---This client's own player name.
---@return string `nil` before the welcome
function GetPlayerName() end

---Where this player stands.
---@return number|nil x `x, y, z` - in metres; `nil` before the player exists
---@return number|nil y
---@return number|nil z
function GetPlayerPos() end

---What the player carries, with each item's condition.
---
---The player's own items as their game holds them right now: one entry per item or stack, with the item class (a GUID of the
---game's tables), the count and the **condition** in percent as the game's inventory shows it (0 = broken, 100 = new or fully
---repaired). The purse is among them as the game's
---money item. The list is a copy to read - giving and taking items is the server's (the game mode's `GivePlayerItem`,
---`SetPlayerInventory`), and the server knows the same conditions (its `GetPlayerInventory`).
---@return table a list of `{class = string, amount = number, health = number}`; empty before the player exists
function GetInventory() end

---The name of the level the game runs.
---@return string `klaster`, `trosecko`, `kutnohorsko`; `nil` when unknown
function GetLevelName() end

---What the player looks at - the point, the thing and its surface.
---
---The first solid thing on the line from the camera through the middle of the screen (where the crosshair would be, in first
---and in third person alike), at most `range` metres away (100 by default, 1000 at most); the player's own body and the horse
---they ride are looked through. `nil` when nothing solid is that close (the sky, open water).
---
---The table: `x`, `y`, `z` the point hit (metres), `distance` from the camera, `normal` (`{x, y, z}`, which way the surface
---faces there), `surface` the game's surface type (`"mat_wood"`, `"mat_rock"`, `"mat_grass"`, `"mat_vegetation"` ...),
---`vegetation` (`true` for a tree, a bush or leaves), and `kind`:
---- `"player"` - another player's body: `player` is their pid, `id` their body's entity id, `name` their name
---- `"entity"` - one of the server's entities (an actor, an animal, a horse, a prop, a pickup, a cart ...): `id` is the id the
---  game mode knows it by, `name` its name
---- `"object"` - a thing of the level with a script (a door, a chest, a bed ...): `name` is its level name - for a door or a
---  chest the key the game mode's door and container functions take (a name the level gives several chests may need the point
---  too: the mode's `GetNearestContainer`) - and `class` its class (`"AnimDoor"`, `"Stash"` ...)
---- `"vegetation"` - a tree or a bush of the level
---- `"static"` - a building, a wall, a rock: the level's solid scenery
---- `"terrain"` - the ground
---
---A tree, a bush or a piece of scenery also comes with `mesh` - the model it is drawn with, lower case
---(`"objects/natural/vegetation/trees/normal_trees/quercus_robur/quercus_a.cgf"`: the folder is the species, which tells an oak
---from a pine) - and its box: `bbox` (`{min = {x, y, z}, max = {x, y, z}}`) and `center` (`{x, y, z}`, the middle of that box).
---The mesh and the centre are the same on every player's game, so together they name one tree for the whole server, and they
---are what the game mode's RemoveLevelObject takes to take that tree away -
---with `"vegetation"` when `kind` is `"vegetation"` and `"brush"` when it is `"static"` (the level places many of its small
---stones as vegetation, so tell a stone from a tree by its mesh). They are `nil` when the game cannot tell which piece of the
---level was hit (some walls and rocks). The look only meets what is solid: a young tree, a bush or a stone players walk
---through is looked through, and the answer is what lies behind it.
---
---It is this player's own look, measured on their screen; send it with `SendServerEvent` when the mode should act on it.
---Cheap enough to call when a key is pressed, not meant for every frame.
---@param range? number how far to look, in metres (100 by default)
---@return table|nil `{x, y, z, distance, normal, surface, vegetation, kind, player, id, name, class, mesh, bbox, center}`; `nil` when nothing is hit
function GetLookTarget(range) end

---Puts this player's view at a point, looking at another - the client side of the game mode's camera.
---
---The view moves to x y z and looks at lx ly lz, gliding there from where it is over `ms` milliseconds (`0` = a cut, at most
---60000; the glide eases in and out), with the field of view `fov`. The player's body stays where it is, its head shown, and their
---keys still move it. It is the same camera the game mode moves with its `SetPlayerCamera`: the last call - this one or the mode's -
---wins. The view holds until `ResetCamera`.
---@param x number metres - where the camera stands
---@param y number metres
---@param z number metres
---@param lx number metres - the point it looks at
---@param ly number metres
---@param lz number metres
---@param ms? number the glide from where the view is, milliseconds (`0` = a cut)
---@param fov? number the field of view in degrees, 10-120 (`nil` = the player's own)
---@return boolean `false` for a point that looks nowhere (it is the camera's own) or before the world is up
function SetCamera(x, y, z, lx, ly, lz, ms, fov) end

---Gives the player their own view back.
---@param ms? number the glide back to their eyes, milliseconds (`0` = a cut)
---@return boolean `false` before the world is up
function ResetCamera(ms) end

---Whether a camera of the script's or the game mode's holds the view.
---@return boolean
function IsCameraSet() end

---How many entities of a class the level holds.
---@param cls string an entity class name (`"NPC"`, `"Horse"`, `"AnimDoor"`, `"Stash"` ...)
---@return number `0` when none or the class is unknown
function CountEntities(cls) end

---The entity classes of the level with the most instances.
---@param top number how many classes to list
---@return number total `total, list` - the number of entities and a string `"Class n, Class n, ..."` of the `top` most common
---@return string list
function GetEntityCensus(top) end

---Whether the labels over the other players hide behind walls.
---
---`true` by default: a label is hidden when something stands between the player's eyes and the body. `false` shows every
---label through everything - a debugging aid, and a choice a mode may make for its players.
---@param hidden boolean `true` hides a label behind geometry, `false` shows it through
function SetLabelOcclusion(hidden) end

-- ======== The party =============================================================
-- The party this player is in, as the server keeps it - the members with their labels and the others' vitals at any
-- distance - for a script that draws its own frames or reacts to the group. The server draws the standard frames unless the
-- mode hides them per player (`ShowPartyFrames` on the server); a script that draws its own reads `GetParty` and defines
-- `OnPartyChange`. The invitation box and its keys (Y / N, `KcdMp_party_keys` changes them) are the client's own.

---**Called by the server** - The party changed - membership, leader, name, labels, the frames switch, or a vitals update.
---
---Called after every party message and every vitals update (at most twice a second). The argument is what `GetParty`
---returns; an empty party (`id` 0) means the player left or the party ended. An error inside is logged
---(`[KcdMp] OnPartyChange: ...`).
---@param party table the party, as `GetParty` gives it
function OnPartyChange(party) end

---The party as the server last sent it.
---
---`id` is 0 in no party. `members` come in join order, your own player among them; each has the pid, the name, the
---mode's `label`, and the vitals of the last update - `health`, `maxHealth`, `stamina`, `maxStamina`, `injuries` (bits
---as the game's body parts 1-6), `dead`, `bleeding`, `loading` (not in the world), `x`, `y`, `z` when the server sent a
---position - with `vitals` false until the first update arrived (your own entry never has them: the game's HUD does).
---`frames` says whether the server's frames are shown to this player. Read it live; a copy goes stale within half a second.
---@return table `{id = number, leader = pid, name = string, frames = boolean, members = {{pid, name, label, health, maxHealth, stamina, maxStamina, injuries, dead, bleeding, loading, vitals, x, y, z}, ...}}`
function GetParty() end

-- ======== The game's HUD ========================================================
-- The game's own toasts from a client script: the info line under the compass, the short notification at the top, a game-log
-- line, the quest-style objective banner and the tutorial box - the same slots the server's
-- ShowInfoText family reaches from the game mode, here without a round trip
-- and without the pid. They show nothing while the HUD is down (a level load, the main menu).

---A line in the game's info slot under the compass.
---@param text string the line
---@param ms? number milliseconds (`3000`)
---@param priority? number `0` .. `255`, a higher one is shown first (`0`)
---@param background? boolean a dark backing behind the line (`false`)
function ShowInfoText(text, ms, priority, background) end

---Takes the info line down.
function HideInfoText() end

---The short notification at the top of the screen.
---@param text string the line, kept short
function ShowNotification(text) end

---A line in the game's log toast.
---@param text string the line
---@param kind? number the game's log type (`0`)
---@param level? number the game's log level (`0`)
function ShowGameLog(text, kind, level) end

---The quest-style banner - a title with a line under it.
---@param title string the banner's title
---@param text string the line under it
---@param kind? number `OBJECTIVE_NEW`, `OBJECTIVE_DONE` or `OBJECTIVE_FAILED` (`OBJECTIVE_NEW`)
function ShowObjectiveEvent(title, text, kind) end

---A tutorial box with a text that stays a while.
---@param id string a name of your own for the box, to hide it later
---@param text string the text (a newline starts a new line)
---@param ms? number milliseconds (`8000`)
function ShowTutorial(id, text, ms) end

---Takes a tutorial box down by its name.
---@param id string the box's name
function HideTutorial(id) end

---Empties the HUD's notification queue.
function ClearNotificationQueue() end

-- ======== The game's UI for a script ============================================
-- A script composes into the game's own HUD: empty clips to hang things under, lines of text in the game's typeface and
-- filled rectangles, in a space **1080 rows high** whose width follows the screen's shape (`GetScreenSize` says it; a 16:9
-- screen is 1920 wide) - so a panel lands in the same place at every resolution. Every element has a **name** of your own
-- (a word of letters, digits and `_`); a name used again replaces the old element, a parent's removal takes its children with it,
-- a reload of the scripts and the end of the session take everything down. The elements survive a level change by themselves:
-- they are records the game redraws whenever its HUD comes back. Colors are `0xRRGGBB` here, with the alpha apart as
-- `0` .. `100` (`SetUiAlpha`, the rectangle's own argument): the game's Lua keeps its numbers as 32-bit floats, and a
-- server-style `0xRRGGBBAA` loses its last byte on the way. For the game's own toasts see `ShowInfoText` and its family.

---**Called by the server** - A key was pressed or released.
---
---The keys come as the engine names them (`f`, `enter`, `space`, `lalt`, `f5` ...) with `true` on the press and `false`
---on the release; the game keeps them - a script watches, it never takes a key from the game, unless it took the whole
---keyboard with `SetKeyboardCapture`. The keys are forwarded only while a script defines this callback (or has the
---keyboard). A press always gets its release, even when something else takes the key in between (the cursor key held,
---a server page that took the keyboard) or the game window loses the focus. Nothing typed into a server page or the chat
---box comes here. The mouse buttons are `OnMouseButton`'s; `IsKeyDown` asks whether a key is held right now.
---@param key string the key's engine name
---@param pressed boolean `true` on the press, `false` on the release
function OnKey(key, pressed) end

---**Called by the server** - A character was typed while the script has the keyboard.
---
---For a text field of the script's own - a name, a password: the character as the player's keyboard layout makes it (a
---German keyboard's Z is a `Z` here, while `OnKey` names the key at that place `y`), with Shift and the layout's accents
---applied, as UTF-8. It comes only while the script holds the keyboard (`SetKeyboardCapture`), next to the key's own
---`OnKey`; Enter, Backspace, Esc and Tab come as keys alone.
---@param text string the character typed (UTF-8)
function OnTextInput(text) end

---**Called by the server** - The player's cursor came up or went away.
---
---The player brings up their cursor with the cursor key (left Alt unless they picked another in the launcher): holding it for
---a second switches it on or off. `SetCursorShown` switches it too. While it is up the
---game's own pointer is on screen, the view holds still and the keys still walk. It goes away by itself when one of the
---game's own menus opens, at a load and when the session ends - and this runs then too. `IsCursorShown` says the same at
---any moment.
---@param shown boolean `true` when the cursor came up, `false` when it went away
function OnCursorChange(shown) end

---**Called by the server** - A mouse button was pressed while the player's cursor is up.
---
---Every press of the left, right or middle button while the cursor is up, with the pointer's place in the UI space
---(`GetScreenSize`: 1080 rows high, the width following the screen's shape) - the same space `CreateUiRect` and
---`CreateUiText` place things in, so a script can tell which of its own elements was clicked. The click is only
---observed: it also reaches what is on screen under the pointer - unless the script holds the mouse (`SetMouseCapture`).
---`OnMouseButton` hears the releases too.
---@param button string `"left"`, `"right"` or `"middle"`
---@param x number the pointer's place across, in the UI space
---@param y number the pointer's place down, in the UI space (0 at the top, 1080 at the bottom)
function OnCursorClick(button, x, y) end

---**Called by the server** - A mouse button went down or came up while the player's cursor is up.
---
---Every press (`pressed` is `true`) and release (`false`) of the left, right or middle button while the cursor is up, with
---the pointer's place in the UI space (`GetScreenSize`: 1080 rows high) - what a menu needs for a drag, a slider or a
---button that acts on the release. A press this heard always gets its release: if the cursor goes away with the button
---still down (one of the game's own menus, the cursor key), the release comes right before `OnCursorChange`. A release
---whose press came before the cursor was up is not reported.
---
---The button is only observed - it also reaches what is on screen under the pointer - unless the script holds the mouse
---with `SetMouseCapture`: then it is the script's alone.
---@param button string `"left"`, `"right"` or `"middle"`
---@param pressed boolean `true` when the button went down, `false` when it came up
---@param x number the pointer's place across, in the UI space
---@param y number the pointer's place down, in the UI space (0 at the top, 1080 at the bottom)
function OnMouseButton(button, pressed, x, y) end

---**Called by the server** - The player's cursor moved.
---
---The pointer's new place in the UI space (`GetScreenSize`: 1080 rows high), at most once a frame while the cursor is
---up - the first place as the cursor comes up, then every move. For hover effects and drags in a menu of the script's own;
---`GetCursorPosition` reads the same place at any moment.
---@param x number the pointer's place across, in the UI space
---@param y number the pointer's place down, in the UI space (0 at the top, 1080 at the bottom)
function OnMouseMove(x, y) end

---**Called by the server** - The mouse wheel turned while the player's cursor is up.
---
---One call a notch: `1` when the wheel turned away from the player (up), `-1` towards them (down), with the pointer's place
---in the UI space - for a list or a text that scrolls. The wheel is only observed - it also scrolls a page of the server's
---interface under the pointer - unless the script holds the mouse with `SetMouseCapture`. While the cursor is down the
---wheel is the game's and nothing is reported.
---@param delta number `1` a notch up, `-1` a notch down
---@param x number the pointer's place across, in the UI space
---@param y number the pointer's place down, in the UI space
function OnMouseWheel(delta, x, y) end

---**Called by the server** - The mouse moved while the cursor is down - the moves the game turns the view with.
---
---Once a frame at most, the frame's sum of the mouse's raw moves: `dx` > 0 to the right, `dy` > 0 towards you. It comes
---while the player looks around with the mouse (the cursor down; while it is up `OnMouseMove` tells the pointer's place),
---also while a camera of the script's or the game mode's holds the view - a script's own camera can follow the mouse. The
---game still turns the view with the moves unless the script holds the look (`SetMouseLookCapture`). Nothing comes while
---the emote wheel, the chat box or the F9 window has the mouse. A callback that raises an error is switched off.
---@param dx number the moves to the right (negative to the left)
---@param dy number the moves towards you (negative away from you)
function OnMouseLook(dx, dy) end

---**Called by the server** - A key the game mode declared was pressed or released.
---
---The game mode declares keys of its own with its `RegisterKeyBinding` - "open the map", "whistle for the horse" - and each
---player's game binds them to a key: the mode's default, or one the player chose. This callback runs when that key goes down
---(`pressed` is `true`) and when it comes up (`false`), with the binding's **name** as the mode declared it, whichever
---physical key it is on. The server hears the same press in its `OnPlayerKeyBinding`, and the pages of the web interface
---in `KcdMp.onKeyBinding`.
---
---A bound key **belongs to the mode**: the game does not get it while it is bound. `OnKey` hears a bound key like any
---other. Nothing is heard while the chat box or the F9 window is open, one of the game's own menus is up, a page holds the
---keyboard or `SetKeyboardCapture` took it; a key that went down as a binding always gets its release, even if one of
---those came up in between, and so does the game's window losing the focus. A held key's repeat is one press.
---
---Keys the game keeps for itself can never be bound: F9, F12, Esc, Tab, Enter, the Windows keys, G and T, the walk, jump,
---crouch and sprint keys, the push-to-talk key, the third-person key, the cursor key and the keys that scroll the chat.
---@param name string the binding's name, as the mode declared it (`a-z 0-9 _ . : -`, 32 characters at most)
---@param pressed boolean `true` when the key went down, `false` when it came up
function OnKeyBinding(name, pressed) end

---The size of the space the elements live in.
---
---The height is always `1080`; the width follows the screen's shape (`1920` on a 16:9 screen, `2560` on 21:9). Read it
---when placing something against the right or the bottom edge - the answer changes with the window, so a script that
---keeps a panel at an edge reads it again when it redraws. It is right from a script's first lines, before any element
---exists.
---@return number w `w, h` - the width and the height
---@return number h
function GetScreenSize() end

---Where a world point lands in the elements' space.
---
---The same space `CreateUiText` and `SetUiPos` place things in (1080 rows high, `GetScreenSize` wide), so a label
---put at the answer sits over the point. A point beside the screen gives a place outside it (below `0` or beyond the
---width or the height); `nil` means behind the camera. The camera is the one of the frame just drawn: a label that
---follows a point in `OnFrame` trails a fast turn by a frame.
---@param x number metres
---@param y number metres
---@param z number metres
---@return number|nil sx `sx, sy` - the point's place, or `nil` when it is behind the camera
---@return number|nil sy
function WorldToScreen(x, y, z) end

---An empty clip to hang other elements under.
---
---A panel: put texts and rectangles under it with their `parent`, then move, fade or hide the whole with one call
---(`SetUiPos`, `SetUiAlpha`, `HideUiElement`). A child's `x` and `y` are inside its parent.
---@param name string the clip's name
---@param parent? string another clip's name; none = the screen
---@return string the name
function CreateUiClip(name, parent) end

---A line of text in the game's typeface.
---
---The same face and gold the game's name plates use. `scale` `1` is the plate's 26-pixel size (`0.6` a small line);
---`align` says which edge sits at `x` - `UI_ALIGN_LEFT`, `UI_ALIGN_CENTRE` or `UI_ALIGN_RIGHT`. The line does not
---wrap; `SetUiWrap` makes it a block that does.
---@param name string the element's name
---@param x number where the aligned edge sits
---@param y number the top of the line
---@param text string the line
---@param color? number `0xRRGGBB` (`COLOR_GOLD`)
---@param scale? number `1` = 26 pixels (`1`)
---@param align? number `UI_ALIGN_LEFT`, `UI_ALIGN_CENTRE` or `UI_ALIGN_RIGHT` (`UI_ALIGN_LEFT`)
---@param parent? string a clip's name
---@return string the name
function CreateUiText(name, x, y, text, color, scale, align, parent) end

---A filled rectangle.
---@param name string the element's name
---@param x number the left edge
---@param y number the top edge
---@param w number the width
---@param h number the height
---@param color? number `0xRRGGBB` (black)
---@param alpha? number `0` .. `100` (`100`)
---@param parent? string a clip's name
---@return string the name
function CreateUiRect(name, x, y, w, h, color, alpha, parent) end

---Changes a text element's line.
---@param name string the element
---@param text string the new line
function SetUiText(name, text) end

---Moves an element.
---@param name string the element
---@param x number the new x (inside the parent)
---@param y number the new y
function SetUiPos(name, x, y) end

---Resizes a rectangle.
---@param name string the rectangle
---@param w number the width
---@param h number the height
function SetUiSize(name, w, h) end

---Recolors a text or a rectangle; the alpha stays (`SetUiAlpha`).
---@param name string the element
---@param color number `0xRRGGBB`
function SetUiColor(name, color) end

---Fades an element - a clip with everything under it.
---@param name string the element
---@param alpha number `0` (invisible) .. `100` (opaque)
function SetUiAlpha(name, alpha) end

---Scales a text or a clip.
---@param name string the element
---@param scale number `1` = the element's own size
function SetUiScale(name, scale) end

---Changes which edge of a text sits at its x.
---@param name string the text
---@param align number `UI_ALIGN_LEFT`, `UI_ALIGN_CENTRE` or `UI_ALIGN_RIGHT`
function SetUiAlign(name, align) end

---Makes a text a block that wraps at a width.
---
---The text breaks between words into lines no wider than `width` (a word wider than that is cut), each line aligned at
---the text's `x` the way `SetUiAlign` says, the block growing down from its `y`. A `"\n"` in the text starts a new line
---with or without a width. At most 32 lines; the block moves, fades and hides as one.
---@param name string the text
---@param width number the block's width, in the elements' space at the text's scale; `0` = one line again
function SetUiWrap(name, width) end

---Shows a hidden element.
---@param name string the element
function ShowUiElement(name) end

---Hides an element, keeping it.
---@param name string the element
function HideUiElement(name) end

---Takes an element down, with everything under it.
---@param name string the element
function DestroyUiElement(name) end

---Takes every element of the script down.
function ClearUi() end

---Takes the keyboard for a menu of the script's own - or gives it back.
---
---While it is on, every key goes to `OnKey` and the game takes no input: the player neither walks nor turns the view,
---Esc does not open the game's menu (it is the script's, to close its own with), Enter does not open the chat nor its
---scroll keys move it, the emote wheel and the scoreboard wait. F9 stays the overlay's. The keyboard comes back with `false`, when the server replaces
---the scripts, and when the session ends - so a script that forgets cannot keep a player from their keys for good; a
---script whose `OnKey` fails gives it back at once. The player can take it back too: Esc pressed three times within two
---seconds ends the capture whatever the script does (the third press does not reach `OnKey`), so keep a way to close
---your own menu on the first Esc. Keys held down at the moment it is taken are let go first.
---@param on boolean `true` takes the keyboard, `false` gives it back
function SetKeyboardCapture(on) end

---Whether the script has the keyboard.
---@return boolean
function IsKeyboardCaptured() end

---Whether a key is held down right now.
---
---The keys as `OnKey` names them (`w`, `lshift`, `lalt`, `space` ...). It follows the keys pressed since the script first
---asked (or defined `OnKey`): a key already held at that moment reads `false` until it is pressed again. Like `OnKey`,
---it never sees what is typed into a server page or the chat box, and every key reads `false` while the game window is not
---in front.
---@param key string the key's engine name
---@return boolean `true` while the key is held
function IsKeyDown(key) end

---Leaves the server and closes the game - a menu's Exit.
---
---Works only in answer to a key: called from `OnKey` while the script holds the keyboard (`SetKeyboardCapture`), for a
---key the player pressed. Anywhere else - a timer, an event from the server, a script that has not taken the keyboard - it
---does nothing, so a script can offer the player a way out but never close their game on its own. The server sees an
---ordinary disconnect.
function QuitGame() end

---Whether the player's cursor is up.
---
---`true` while the player's cursor is on screen - brought up with the cursor key or `SetCursorShown`. `OnCursorChange`
---tells the moment it changes.
---@return boolean `true` while the cursor is up
function IsCursorShown() end

---Brings the player's cursor up, or takes it away.
---
---For a menu of the script's own that wants the mouse: the same switch the cursor key's one-second hold turns over, so the player can
---still take the cursor away with the key. It works while the player is in the world; one of the game's own menus, a load
---and the end of the session take the cursor away whatever the script set. `true` says the request was made -
---`IsCursorShown` and `OnCursorChange` say what came of it.
---@param on boolean `true` (or nothing) brings the cursor up, `false` takes it away
---@return boolean `true` when the request was made
function SetCursorShown(on) end

---Where the player's cursor points, in the UI space.
---
---The pointer's place in the UI space (`GetScreenSize`: 1080 rows high, the width following the screen's shape) while
---the cursor is up, the place `OnMouseMove` last told; `nil` while the cursor is down. For a hover check in
---`OnFrame` without keeping the place yourself.
---@return number|nil x `x, y` - the place in the UI space, or `nil` while the cursor is down
---@return number|nil y
function GetCursorPosition() end

---Takes the mouse for a menu of the script's own, or gives it back.
---
---What `SetKeyboardCapture` does for the keyboard, for the mouse. While the script holds it:
---
---- the cursor is up, and stays up - the cursor key and `SetCursorShown(false)` do not take it away. One of the game's own
---  menus and a load still hide it meanwhile, and it comes back after them.
---- the buttons and the wheel are the script's alone: `OnMouseButton`, `OnCursorClick` and `OnMouseWheel` hear them,
---  and neither the game nor a page of the server's interface under the pointer gets them.
---
---The script gives it back with `SetMouseCapture(false)`. A reload of the scripts and the end of the session give it back too.
---So that a player is never left without a mouse, a click the script does not hear gives it back as well. That is a click
---when the script defines neither `OnMouseButton` nor `OnCursorClick`, or when the one it defines fails.
---It can be taken whenever the session runs, even before the player is in the world (the cursor comes up once they are).
---`true` says the request was made; `IsMouseCaptured` says whether the script holds the mouse.
---@param on boolean `true` (or nothing) takes the mouse, `false` gives it back
---@return boolean `true` when the request was made
function SetMouseCapture(on) end

---Whether the script holds the mouse.
---
---`true` from `SetMouseCapture``(true)` until the mouse is given back: by the script, a reload of the scripts, the end
---of the session, or a click nothing of the script heard.
---@return boolean `true` while the script holds the mouse
function IsMouseCaptured() end

---Takes the mouse's look for the script - the view no longer follows the mouse - or gives it back.
---
---While the script holds the look, the mouse's moves reach `OnMouseLook` alone: the player's view and body stay where they
---are, the keys still walk. Made for a camera of the script's own that the mouse turns (`SetCamera`): an orbit around a
---character, a cinematic shot. The buttons, the wheel and the cursor key are not taken.
---
---Given back by `SetMouseLookCapture(false)`, a reload of the scripts and the end of the session.
---@param on? boolean `true` (the default) takes the look, `false` gives it back
---@return boolean `true` when asked
function SetMouseLookCapture(on) end

---Whether the script holds the mouse's look.
---@return boolean `true` from `SetMouseLookCapture``(true)` until it is given back
function IsMouseLookCaptured() end

---How far the game's photo mode camera may fly from the player.
---
---The game's photo mode keeps its free camera within a few metres of the player; this lets it fly farther for wider shots,
---or keeps it closer. In metres, 1 to 10000; `nil` puts the game's own distance back. A reload of the scripts and the end
---of the session put it back too.
---@param metres number|nil the farthest the photo mode camera may go from the player; `nil` = the game's own
---@return boolean `false` for a value that is not a number
function SetPhotoModeMaxDistance(metres) end

---How far the game's photo mode camera may fly from the player, in metres.
---@return number the distance now (the game's own until `SetPhotoModeMaxDistance` changes it); `nil` before the game has said
function GetPhotoModeMaxDistance() end

---Ends the loading screen when the game mode keeps it up.
---
---A server's interface can keep the loading screen over the game **past the spawn** (`manual_shutdown` in its `ui.toml`'s
---`[components.loading]`): the screen then stays until the mode's `ClosePlayerLoadingScreen`, this call, the loading page's
---`loading.done`, or 240 seconds after the world is ready. A script that has a reason to hold it - a menu of its own that is still being built - closes it here
---when it is ready. A close that comes before the player has spawned waits for the spawn.
---
---Without that setting the spawn ends the screen and the call changes nothing, and the screen shows once for a run of the
---game, so it changes nothing later either. `true` says the request was **made**; there is no answer to read beyond that -
---whether the screen was still up is not reported.
---@return boolean `true` when the request was made
function CloseLoadingScreen() end

-- ======== Looks and the character creator =======================================
-- A look is a table `{body = the skin, head = the face, hair = the hair and its color, beard = the beard}`, each part named as
-- the game names it (`m_body_tan_02`, `m_head_004`, `m_hair_005_blonde`, `m_beard_03`); a part left out is the one the body's
-- soul gives it. `gender = "female"` makes it a woman's body, with a woman's parts (`f_head_013`, `f_hair_004_blonde`,
-- `f_body_pale_01`; no beard). The **server owns the look everyone sees** - the mode's `SetPlayerLook`; a script can only
-- show a look on this screen and ask for it:
-- 
-- - `ShowLookPreview` puts a body in front of the player, dressed as they are, wearing the look - a character creator's or a
--   barber's mirror that nobody else sees; call it again with every change the player makes, `HideLookPreview` when done;
-- - `RequestLookChange` asks the server for the look; the mode's `OnPlayerLookChange` decides, and the look comes back
--   through `OnLookChange` when the mode took it;
-- - `GetPlayerLook` is the player's look as the server last said.
-- 
-- The parts to offer come from the mode - its `GetLookParts` lists the game's, and a script event carries the mode's choice
-- to its client half. `SetKeyboardCapture` gives a menu the keyboard. The
-- character creator guide builds a whole screen; the shipped BasicRP mode has one.
-- 
-- The player's own body loads with the level: when the mode makes the player a woman (or a man again) while they play, the
-- game asks them once whether to restart and join again on the new body, and remembers it for the next join to the server.
-- A script cannot swap the player's own model while they play: the game refuses the change (a call of `SetActorModel` or
-- `LoadCharacter` on the player) and notes the script's line in the client log.

---**Called by the server** - The player's own look changed - the server's word.
---
---The mode gave the player a look (`SetPlayerLook`), took the one the script asked for (`RequestLookChange`), or took
---it off; the table is what `GetPlayerLook` returns from now on. A creator closes itself here: the look it asked for
---is the player's.
---@param look table `{body, head, hair, beard, gender}` - the parts the mode set (a part the soul decides is absent); `gender` is `"female"` on a woman's look
function OnLookChange(look) end

---The player's own look, as the server last said.
---
---`{}` until the mode gives the player a look - the parts of the soul are not in it. A creator starts from here.
---@return table `{body, head, hair, beard, gender}`
function GetPlayerLook() end

---A body in front of the player wearing a look - on this screen alone.
---
---The first call puts a body where the player looks, `distance` metres ahead on their own floor, facing them and dressed
---in what they wear, with the look's parts on it, and turns the player's view level onto it (whether they looked at the
---sky or at their feet); nobody else sees it. Every later call changes it in place: the look
---(written only when it changed), the distance along the same line, the turn, the height - what `options` leaves out
---keeps the last call's. A creator holds the keyboard meanwhile (`SetKeyboardCapture`: the player neither walks nor
---turns away from the body); a player moved far from it (a teleport) finds it in front of them again at the next call.
---The body goes with `HideLookPreview`, a reload of the scripts, and the end of the session.
---
---`options`: `distance` - metres in front (`1.6` by default: the head and the chest; `0.9` is the face, `2.5` the whole
---body), `turn` - degrees the body is turned from facing the player (`180` shows the back), `height` - metres up or down.
---
---A look with `gender = "female"` shows a woman's body (a change between the two makes the body anew where it
---stands); what the player wears is put on her too - a woman's dress stands in for a man's clothes and armour on her
---body, his hoods and helmets are left off (her own hair and face show), his boots show as they are and his scabbards
---without their waist belt.
---@param look table|string `{body, head, hair, beard, gender}`, or its one-line form; `{}` shows the body as its soul makes it
---@param options? table `{distance = 1.6, turn = 0, height = 0}`
---@return boolean `false` when there is no player yet or no body could be made
function ShowLookPreview(look, options) end

---Takes the preview body away.
---@return boolean `true`
function HideLookPreview() end

---Asks the server for a look.
---
---The look goes to the mode's `OnPlayerLookChange` after the server's own checks (every part one of its kind, all of
---them a man's or all a woman's - `gender = "female"` asks for a woman's body). When the mode takes it, it is the
---player's on every screen and `OnLookChange` tells the script; when it does not, nothing comes back but what the mode
---says itself (a part the server does not know is told under the compass). One ask a second at most: a faster one is
---not sent. A look of the other body than the player's own asks them to restart the game once it is taken.
---@param look table|string `{body, head, hair, beard, gender}`, or its one-line form
---@return boolean `false` when it came too soon after the last and was not sent
function RequestLookChange(look) end

---A look as one line.
---
---`"body=m_body_tan_02;head=m_head_004;hair=m_hair_005_blonde;beard=m_beard_03"` - the parts left out missing, a woman's
---starting with `gender=female;` - the form the mode's `LookToString` makes and its database keeps; a script event may
---carry it either way.
---@param look table|string a look
---@return string the one-line form
function LookToString(look) end

---A look's one line back into its table.
---@param text string `kind=name` pairs separated by `;` (`gender=female` for a woman's)
---@return table `{body, head, hair, beard, gender}`
function LookFromString(text) end

-- ======== Web interface =========================================================
-- The server's **web interface** is a set of pages - HTML, CSS and JavaScript the server sends with its client scripts -
-- that the game draws over the screen; each page is a **frame** named in the interface's `ui.toml`. A client script is the
-- page's neighbour inside the player's game: it shows and hides the frames, sends them messages, hears what they ask for and
-- answers, and takes the keyboard and the mouse cursor for them. The other half of the conversation is the page's
-- own JavaScript (`KcdMp.onMessage`, `KcdMp.post`; the web interface SDK), and the guide
-- Make a web interface shows the whole of it.
-- 
-- - **Messages to a page** - `SendWebMessage`; the page's `KcdMp.onMessage` receives exactly the value.
-- - **A page asks the script** - the page's `KcdMp.post(name, data)` arrives in `OnWebEvent` and the value the callback
--   returns is the page's answer.
-- - **Frames and focus** - `ShowWebFrame`, `HideWebFrame`, `DestroyWebFrame`, `SetWebFrameZ`, `SetWebFocus`,
--   `SetWebFocusKeepInput`, and `IsWebFocused` to see where the focus is.
-- - **State** - `IsWebAvailable`, `IsWebFrameReady` and `OnWebFrameReady`.
-- - **JSON** - `JsonEncode` and `JsonDecode`, which work in every game.
-- 
-- Every one of these exists in every player's game: with no web layer (an older game, a player who switched server
-- interfaces off, a server without an interface) a function does nothing and answers `false` and the reason - `"no web layer"`,
-- `"no web interface"` (the server has none) or `"no such frame"` - and the `Is` functions answer `false`, so a script written
-- for the web interface also runs without it. An answer of `true` means the request was **handed over**; the game decides
-- after that (a frame's `focus` setting, the player's own switches), and `IsWebFocused` says what came of it. Frames are the
-- server's interface's own: a script can only name frames of the interface that is in force.

---**Called by the server** - A page of the web interface asked the script something - the value returned is the page's answer.
---
---The page's `KcdMp.post(name, data)` lands here with the frame that called, the name and the data - the JSON the page sent,
---read as a table, text, number or boolean by the rules of `JsonDecode` (`nil` when it sent none). Whatever the callback
---returns - a table, a text, a number, a boolean or nothing - goes back to the page as JSON, and that is what the
---page's promise resolves to.
---
---The page's call fails instead when the script has no `OnWebEvent` (the page sees `no handler`), when the callback raises
---an error (`handler failed`; the error text is logged, never sent to the page), when the answer cannot be written as JSON or
---is over 64 KB, or when no answer comes within about ten seconds. Answer at once: the page waits for the reply, so send
---anything slow later as a message with `SendWebMessage`.
---
---Take the page's data as you would take input from a player: check what is there before using it.
---
---Return value: the page's answer: a table, a text, a number, a boolean or nothing
---@param frame string the frame whose page called
---@param name string what the page called it
---@param data any what the page sent, as a Lua value
function OnWebEvent(frame, name, data) end

---**Called by the server** - A frame's page has loaded and is listening.
---
---The page has called `KcdMp.ready()` (its script does it once the document has loaded, unless the page asked to do it by
---hand); from now on a message sent to it reaches it without any waiting. The callback runs **again each time the frame's
---page loads anew**. A script that starts after a frame became ready is told about it once its files have run - for
---each frame that is ready - so the first thing a script does about a frame can always be done here.
---@param frame string the frame's name
function OnWebFrameReady(frame) end

---Sends a frame's page a message - a table, a text, a number or a boolean.
---
---The page's `KcdMp.onMessage` handler receives **exactly the value** sent: a table arrives as an object or an array, a text
---as a text. The message is written as JSON by `JsonEncode`, under its rules, and is at most **64 KB** of it. A page that is
---not ready yet is sent it when it is (up to 256 messages or 1 MB are kept per frame; past that the oldest are dropped);
---messages arrive in the order they were sent. A table with a `__kcdmp` key at the top is refused: that key is how the game
---itself talks to a page.
---
---Returns `true` when the message was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"`, `"no such frame"`, `"no data"` (the value is `nil`), `"reserved key"`, `"too big"` or what
---`JsonEncode` says about a value it cannot write.
---@param frame string the frame's name
---@param data table|string|number|boolean the value the page receives
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SendWebMessage(frame, data) end

---Shows a frame of the web interface.
---
---The frame is made if it is not there yet (its page loads and `OnWebFrameReady` follows); a frame hidden with
---`HideWebFrame` is drawn again **as it was**, the same page with no reload. Showing a frame does not give it the keyboard
---or the mouse: that is `SetWebFocus`.
---
---Returns `true` when the request was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"` or `"no such frame"`.
---@param frame string the frame's name, as the interface's `ui.toml` gives it
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function ShowWebFrame(frame) end

---Takes a frame of the web interface off the screen without closing it.
---
---The frame stays alive: its page keeps running and keeps its state, messages still reach it, and `ShowWebFrame` draws
---the same page again at once. A hidden frame gives up the keyboard and the mouse it held.
---
---Returns `true` when the request was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"` or `"no such frame"`.
---@param frame string the frame's name
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function HideWebFrame(frame) end

---Closes a frame of the web interface and frees the memory its page used.
---
---A frame hidden with `HideWebFrame` stays alive - its page keeps running and keeps everything it loaded. A frame closed
---with this call is gone: its page ends, the memory it used is freed and it gives up the keyboard and the mouse.
---`ShowWebFrame` makes it again, its page loaded from the start (`OnWebFrameReady` follows once it listens). Close the
---screens the player opens once and hide the ones they open again and again. Closing a frame that is not open does nothing.
---
---Returns `true` when the request was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"` or `"no such frame"`.
---@param frame string the frame's name
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function DestroyWebFrame(frame) end

---Sets which frame is drawn above which.
---
---A frame with a higher `z` is drawn over one with a lower; the interface's `ui.toml` gives every frame its starting `z`.
---The value is a whole number from `0` to `999` (a fraction is rounded). When the frame is made again its own `z` from
---`ui.toml` applies once more.
---
---Returns `true` when the request was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"`, `"no such frame"` or `"z is a number from 0 to 999"`.
---@param frame string the frame's name
---@param z number `0` to `999`
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetWebFrameZ(frame, z) end

---Gives a frame the keyboard and the mouse cursor, or takes them back.
---
---A frame that has the **cursor** gets the mouse: the player can click in its page. A frame that has the **keyboard** gets
---the keys: typed letters go to the page's text fields and the game does not see them. With neither `keyboard` nor `cursor`
---the frame **gives its focus up**. `SetWebFocusKeepInput` lets the game keep the player's keys meanwhile.
---
---The frame's `focus` setting in `ui.toml` decides what a request gets - a script cannot take the player's keyboard behind
---their back: `"never"` refuses every request; `"input"` (the default) grants the cursor at once and the keyboard only
---within five seconds of the player's own click or key press in that frame, **or when the call is made inside
---`OnKey`**, the player's own key press; `"open"` grants the cursor at any time and the keyboard at once together with it
---(a keyboard asked for without the cursor waits for the player's first click in the frame). A frame that is hidden takes no
---focus.
---
---Returns `true` when the request was handed over - **not** that the frame got the focus: ask `IsWebFocused` a moment
---later. `false` and the reason when it could not be handed over: `"no web layer"`, `"no web interface"` or
---`"no such frame"`.
---@param frame string the frame's name
---@param keyboard boolean `true` to give the frame the keyboard
---@param cursor boolean `true` to give the frame the mouse cursor
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetWebFocus(frame, keyboard, cursor) end

---Lets the game keep the player's keys while a frame has the keyboard.
---
---A frame that holds the keyboard normally takes every key. With `keep` on, the game still gets the player's keys while
---no text field of the page has the focus - a player can walk with a panel open - and the page takes the keys back the
---moment the player clicks into a text field. It does nothing while the frame does not hold the keyboard (`SetWebFocus`).
---
---Returns `true` when the request was handed over, `false` and the reason when it could not be: `"no web layer"`,
---`"no web interface"` or `"no such frame"`.
---@param frame string the frame's name
---@param keep boolean `true` to let the game keep the player's keys
---@return boolean ok `true`, or `false, reason` - the reason as a person reads it
---@return string reason
function SetWebFocusKeepInput(frame, keep) end

---Whether a frame - or any frame - of the web interface has the keyboard or the mouse cursor.
---
---With a frame name: `true` when that frame holds the keyboard, the cursor or both. Without one: `true` when any frame
---does. It says what came of a `SetWebFocus`, which only hands the request over. `false` when there is no web layer.
---@param frame? string the frame's name; leave it out to ask about every frame
---@return boolean `true` when the frame (or any frame) has the keyboard or the cursor
function IsWebFocused(frame) end

---Whether a frame's page has loaded and is listening.
---
---`true` from the moment `OnWebFrameReady` runs for the frame until its page is gone. A frame that is only hidden is still
---ready. `false` for a frame that was never shown, one still loading, an unknown name, and when there is no web layer.
---@param frame string the frame's name
---@return boolean `true` when the page is listening
function IsWebFrameReady(frame) end

---Whether this game runs the web layer with the server's interface in force.
---
---`true` when the player's web layer runs and the server has an interface it has sent, so its frames can be shown.
---`false` in every other case - with no web layer, while the interface is still arriving - and a script that has a
---second way to show a screen (a Lua one) uses it then.
---@return boolean `true` when the frames can be shown
function IsWebAvailable() end

---A value as JSON text.
---
---The rules, the same on the server as in a client script - a value written by one is read back by the other:
---
---- a table whose keys are exactly `1` to `n` (`n` at least 1) is an **array**; an **empty table is `[]`**; any other table
---  is an **object**, its number keys written as texts and its keys in order - a key that is neither a text nor a number
---  is an error;
---- `nil` is left out of a table, and `JsonEncode(nil)` is `null`;
---- a number is written as the shortest text that reads back the same, an integer without a decimal point; `NaN` and the
---  infinities are an error;
---- texts stay UTF-8 (a text that is not valid UTF-8 is an error), with `"`, `\` and the control characters escaped and
---  `/` left alone;
---- a table nested more than 32 deep, one that holds itself, and a function or any other value that is not data are
---  errors; the text is at most 1 MB.
---
---An error is not raised: the function returns `nil` and the reason. It works in every game, with or without the web layer.
---@param value any a table, a text, a number, a boolean or `nil` (written as `null`)
---@return string|nil the JSON text, or `nil` and the reason
---@return string
function JsonEncode(value) end

---JSON text as a value.
---
---The reverse of `JsonEncode`: an object becomes a table with text keys, an array a table with the keys `1` to `n`,
---and a JSON `null` inside them leaves the place empty (in an array the other values keep their positions). **The game's
---Lua keeps its numbers as 32-bit floats**, so an integer beyond 16777216 (2^24) - an id, a large sum - cannot be held
---exactly and comes back as a text of its digits; convert it with `tonumber` only if you know it is small enough, or keep it
---as the text it is.
---
---A `null` on its own gives `nil`, so a `nil` result alone does not say the text was wrong - look at the second value. Text
---that is not valid JSON, is more than 32 levels deep or is over 1 MB gives `nil` and the reason. Nothing in the text can
---run anything: what comes back is data. It works in every game, with or without the web layer.
---@param text string one JSON value
---@return any the value - or `nil` and the reason when the text could not be read
---@return string|nil
function JsonDecode(text) end

-- ======== The game's screens ====================================================
-- The game's own player screens - the inventory, the character screen, the world map, the Codex and the journal - opened and
-- closed from a script: `OpenScreen` with `"inventory"`, `"character"`, `"map"`, `"codex"` or `"journal"`, `CloseScreens`,
-- and `GetOpenScreen` / `OnScreenChange` for the one open. A screen the server refuses the player stays shut. A mode that
-- opens and refuses the screens itself does it from the server (its `OpenPlayerScreen`, `SetPlayerScreenBlocked`).

---**Called by the server** - One of the game's player screens opened, the player switched to another, or they closed.
---
---The player's own key or tab, `OpenScreen`, `CloseScreens` or the server's word. `"other"` is another of the game's
---screens of that kind (crafting, a horse's saddlebags).
---@param screen string|nil `"inventory"`, `"character"`, `"map"`, `"codex"`, `"journal"` or `"other"`; `nil` = closed
---@param previous string|nil the one before (`nil` = none was open)
function OnScreenChange(screen, previous) end

---Opens one of the game's player screens.
---
---Switches to it when one of them is open already. Nothing opens while another screen of the game's own is up (a
---dialogue, a minigame, the Esc menu), or for a screen the server refuses the player. `true` says the request was made -
---`OnScreenChange` says what came of it.
---@param screen string `"inventory"`, `"character"`, `"map"`, `"codex"` or `"journal"`
function OpenScreen(screen) end

---Closes the game's player screens - and the loot and trade screens.
---@return boolean `true`
function CloseScreens() end

---Which of the game's player screens is open.
---@return string `"inventory"`, `"character"`, `"map"`, `"codex"`, `"journal"` or `"other"`; `nil` = none
function GetOpenScreen() end

-- ======== Constants =============================================================

-- Colors
---amber - the server's own lines
COLOR_SERVER = 0xFFD070
COLOR_WHITE = 0xFFFFFF
COLOR_RED = 0xFF4040
COLOR_GREEN = 0x40FF40
COLOR_YELLOW = 0xFFFF40
---the game's own text gold - the name plates, the HUD; the default of `CreateUiText`
COLOR_GOLD = 0xF6E890

-- UI alignments
UI_ALIGN_LEFT = 0
UI_ALIGN_CENTRE = 1
UI_ALIGN_RIGHT = 2

-- Objective kinds
---a new objective
OBJECTIVE_NEW = 0
---one completed
OBJECTIVE_DONE = 1
---one failed
OBJECTIVE_FAILED = 2
