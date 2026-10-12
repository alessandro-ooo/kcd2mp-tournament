-- Example: an inventory window drawn by a web page, with the game's own item pictures.
--
-- The Home key (a key binding the mode declares - a player can bind another) or /inv opens the window: the mode sends the page
-- what the player carries (GetPlayerInventory, with GetItemInfo's names, weights and prices), shows the frame and gives it the
-- mouse. The page draws each item with its picture (KcdMp.itemIcon - every player's game makes the pictures from its own files).
-- While the window is open the mode sends the list again whenever it changes; the page's Close button sends "inventory.close".
--
-- Run it with [gamemode] script = "sdk/web/examples/inventory/inventory.lua", or copy this folder into gamemodes/.

SetGameModeText("inventory example")

local open = {}   -- pid -> true while the window is up

local function send(pid)
  local items = {}
  for _, stack in ipairs(GetPlayerInventory(pid)) do
    local info = GetItemInfo(stack.class) or {}
    items[#items + 1] = {
      class = stack.class,                         -- the item class's GUID: KcdMp.itemIcon takes it, or the name
      name = info.name or "",
      display = (info.display or "") ~= "" and info.display or (info.name or stack.class),
      category = info.category or "",
      amount = stack.amount,
      health = stack.health,
      worn = stack.worn == true,
      weight = info.weight or 0,
      price = info.price or 0,                     -- tenths of a Groschen
    }
  end
  SendPlayerWebMessage(pid, "inventory", { items = items, money = GetPlayerMoney(pid) })
end

local function show(pid)
  open[pid] = true
  send(pid)
  ShowPlayerWebFrame(pid, "inventory")
  SetPlayerWebFocus(pid, "inventory", false, true)   -- the mouse, not the keyboard: the player can still walk
end

local function hide(pid)
  open[pid] = nil
  HidePlayerWebFrame(pid, "inventory")   -- (hiding gives the mouse back)
end

local function toggle(pid)
  if open[pid] then hide(pid) else show(pid) end
end

function OnGameModeInit()
  RegisterKeyBinding("inventory.toggle", "Open or close the inventory window", "home")
  RegisterCommand("inv", function(pid) toggle(pid) end, { help = "Open or close the inventory window" })
end

function OnPlayerKeyBinding(pid, name, pressed)
  if name == "inventory.toggle" and pressed then
    toggle(pid)
  end
end

function OnPlayerInventoryChange(pid)
  if open[pid] then send(pid) end
end

-- what the page sends: check it like any input from a player
function OnClientEvent(pid, name, payload, source)
  if source == "inventory" and name == "inventory.close" then
    hide(pid)
  end
end

-- something to look at in an empty bag (an example server only)
local stocked = {}
function OnPlayerSpawn(pid)
  if not stocked[pid] then
    stocked[pid] = true
    for _, item in ipairs({ "longSwordDuel", "bread", "apple", "herb_chamomile", "arrow_hunting" }) do
      GivePlayerItem(pid, item, item == "arrow_hunting" and 20 or 1)
    end
    SendClientMessage(pid, COLOR_SERVER, "Press Home (or type /inv) to open the inventory window - a web page of this server.")
  end
end

function OnPlayerDisconnect(pid, reason)
  open[pid] = nil
  stocked[pid] = nil
end
