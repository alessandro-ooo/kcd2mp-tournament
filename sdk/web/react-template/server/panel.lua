-- The game mode's half of the template's panel: /panel shows it with the mouse, the page's buttons come back as events.
-- Copy it as your mode's file (gamemodes/myui/myui.lua, its interface in gamemodes/myui/ui/), or take the calls into your own mode.

local function show(pid)
  ShowPlayerWebFrame(pid, "panel")
  SetPlayerWebFocus(pid, "panel", false, true)   -- the mouse, not the keyboard
  SendClientEvent(pid, "panel.hello", { text = "Hello, " .. GetPlayerName(pid) .. "!", items = { "longSwordDuel", "bread", "apple" } })
end

function OnGameModeInit()
  RegisterCommand("panel", function(pid) show(pid) end, { help = "Show the React panel" })
end

-- what the page sends: check it like any input from a player
function OnClientEvent(pid, name, payload, source)
  if source ~= "panel" then return end
  if name == "panel.close" then
    HidePlayerWebFrame(pid, "panel")
  elseif name == "panel.ping" then
    local data = JsonDecode(payload)
    local clicks = type(data) == "table" and tonumber(data.clicks) or 0
    SendClientMessage(pid, COLOR_SERVER, "The panel says hello (" .. clicks .. ").")
  end
end
