-- The client half of the checkpoint run (gamemodes/marker/marker.lua): the server sends this file to
-- every player when they join, and their game runs it in the KCD:MP sandbox - the game's own drawing,
-- entities, timers and the client API are here; files, the console, the browser and the saves are not.
-- It draws the checkpoint the server named with the distance to it, and tells the server when the
-- player is close. The server checks the distance itself before it counts.

local marker            -- {x=, y=, z=} or nil while there is none
local reported = false  -- told the server about this one already

-- the mode's SendClientEvent(pid, "marker", "x,y,z") lands here
function OnServerEvent(name, payload)
  if name ~= "marker" then return end
  local x, y, z = payload:match("^([^,]+),([^,]+),(.+)$")
  x, y, z = tonumber(x), tonumber(y), tonumber(z)
  -- the mark stands on the ground this game sees (the server's height may be a guess: -1 = "on the terrain")
  local ground = System.GetTerrainElevation({x = x, y = y, z = 0})
  if type(ground) == "number" and ground > 0 then z = ground end
  marker = {x = x, y = y, z = z}
  reported = false
  print(string.format("checkpoint at %.1f %.1f %.1f", x, y, z))   -- print goes to the client log
end

-- The drawing functions show for one frame, so the mark is drawn every frame from OnFrame (a timer
-- would blink). The distance check rides along; a timer would do for that alone.
function OnFrame(dt)
  if not (marker and player) then return end
  local p = player:GetWorldPos()
  local d = math.sqrt((p.x - marker.x) ^ 2 + (p.y - marker.y) ^ 2)
  -- the label floats above the point; the line stands on it
  System.DrawLabel({x = marker.x, y = marker.y, z = marker.z + 1.6}, 1.4, string.format("%.0f m", d), 1, 0.85, 0.3, 1)
  System.DrawLine({x = marker.x, y = marker.y, z = marker.z}, {x = marker.x, y = marker.y, z = marker.z + 1.4}, 1, 0.85, 0.3, 1)
  if d < 2 and not reported then
    reported = true
    SendServerEvent("marker_reached", "")
  end
end
