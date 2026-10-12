-- BasicRP's boards: the client half of the admin's /board, /sign and /paint (gamemodes/basicrp.lua, "the boards"). The mode asks
-- where its player looks ("board.look", the page's name); this answers with the point under the crosshair and the way the surface
-- faces there (GetLookTarget), or "none" when the player looks at nothing a board could hang on - the sky, a player, a horse.
-- A script the server sends runs in the sandbox: https://docs.kcd-mp.com/lua/client/getting-started/

local HANG_ON = { static = true, object = true, terrain = true, vegetation = true }   -- a wall, a door or a chest, a rock, a tree

-- this file's event; the rest go on to what the scripts before it defined
local nextEvent = OnServerEvent

function OnServerEvent(name, payload)
  if name ~= "board.look" then
    if nextEvent then return nextEvent(name, payload) end
    return
  end
  local t = GetLookTarget(8)
  if t and t.normal and HANG_ON[t.kind] then
    SendServerEvent("board.spot", string.format("%s %.3f %.3f %.3f %.4f %.4f %.4f", payload,
      t.x, t.y, t.z, t.normal.x, t.normal.y, t.normal.z))
  else
    SendServerEvent("board.spot", payload .. " none")
  end
end
