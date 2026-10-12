-- The notice-board example's client half: where the player is looking, for /board and /sign. The mode asks with "board.look"
-- (the payload is the page's name); the answer is the point under the crosshair and the way the surface faces there
-- (GetLookTarget), or "none" when the player looks at nothing a board could hang on - the sky, a player, a horse.
local HANG_ON = { static = true, object = true, terrain = true, vegetation = true }   -- a wall, a door or a chest, a rock, a tree

function OnServerEvent(name, payload)
  if name ~= "board.look" then return end
  local t = GetLookTarget(8)
  if t and t.normal and HANG_ON[t.kind] then
    SendServerEvent("board.spot", string.format("%s %.3f %.3f %.3f %.4f %.4f %.4f", payload,
      t.x, t.y, t.z, t.normal.x, t.normal.y, t.normal.z))
  else
    SendServerEvent("board.spot", payload .. " none")
  end
end
