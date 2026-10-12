-- KCD:MP example game mode: building plots.
--
-- Admins mark plots on the level: `/plot create <radius>` makes one around where they stand - one of the server's map areas, kept with
-- the map like everything an admin builds. A player claims the plot they stand on with `/plot claim` and builds on it with the in-game
-- editor (`/plot build`): the game's meshes picked from its panel, placed, moved, turned, scaled - their own objects only, at most
-- PLOT.max_objects of them, and nothing outside their plot (OnMapEdit says no). What they build goes onto a map layer of the plot's name,
-- so an admin can hide a whole plot at once (`/map layer plot_3 off`). `/plot done` closes the editor, `/plot release` gives the plot up
-- (and takes its objects away), `/plot` alone lists the plots.
--
-- The server keeps it all: the plots are areas with their owner in an area property, the objects are the map's own. Run with
-- `--gamemode gamemodes/plots.lua` (or `[gamemode] script` in server.toml) on a server with a map (`[world] map`). The owner here is
-- the player's name - a real server keys it to its own accounts ([gamemode.database]). Admins come from the KCDMP_ADMINS environment
-- variable ("Henry,Hans"), as in freeroam.

SetGameModeText("plots")

local PLOT = {
  max_objects = 60,     -- objects a player may have on their plot
  height = 25,          -- metres a plot reaches up from the ground (and 5 down)
  max_radius = 40,      -- the largest plot an admin may mark
}

local admins = {}
for name in (os.getenv("KCDMP_ADMINS") or ""):gmatch("[^,%s]+") do admins[name:lower()] = true end

local function fmt(...) return string.format(...) end
local function say(pid, text, bad) SendClientMessage(pid, bad and COLOR_RED or COLOR_SERVER, text) end
local function owner_of(plot) return GetAreaProperty(plot, "owner") or "" end
local function is_plot(name) return name:match("^plot_%d+$") ~= nil end

-- the plot a player stands on, and the one they own
local function plot_at(pid)
  for _, name in ipairs(GetPlayerAreas(pid)) do
    if is_plot(name) then return name end
  end
  return nil
end

local function plot_of(pid)
  local me = GetPlayerName(pid)
  for _, a in ipairs(GetAreas()) do
    if is_plot(a.name) and owner_of(a.name) == me then return a.name end
  end
  return nil
end

local function next_plot_name()
  local n = 0
  for _, a in ipairs(GetAreas()) do
    local i = tonumber(a.name:match("^plot_(%d+)$"))
    if i and i > n then n = i end
  end
  return "plot_" .. (n + 1)
end

function OnPlayerConnect(pid)
  if admins[GetPlayerName(pid):lower()] then SetPlayerAdmin(pid, true) end
end

function OnPlayerSpawn(pid)
  local mine = plot_of(pid)
  GameText(pid, mine and ("Your plot: " .. mine .. " - /plot build") or "/plot lists the plots, /plot claim takes the one you stand on", 4000)
end

-- the editor's every edit of a plot builder: only on their own plot (an admin's /editor is not asked here - its scope is the admin's)
function OnMapEdit(pid, edit)
  local scope = GetPlayerEditor(pid)
  if not scope or not scope.layer or not is_plot(scope.layer) then return true end
  local plot = scope.layer
  for _, p in ipairs(edit.places or {}) do
    local inside = false
    for _, name in ipairs(GetAreasAt(p.x, p.y, p.z)) do
      if name == plot then inside = true break end
    end
    if not inside then
      say(pid, "Build on your plot only.", true)
      return false
    end
  end
  return true
end

local function plot_command(pid, args)
  local verb, rest = args:match("^(%S*)%s*(.-)$")
  verb = verb:lower()
  if verb == "" then
    local any = false
    for _, a in ipairs(GetAreas()) do
      if is_plot(a.name) then
        any = true
        local owner = owner_of(a.name)
        say(pid, fmt("%s at %.0f %.0f, %.0f m across: %s", a.name, a.x or 0, a.y or 0, (a.radius or 0) * 2, owner ~= "" and owner or "free"))
      end
    end
    if not any then say(pid, "No plots yet" .. (IsPlayerAdmin(pid) and " - /plot create <radius> marks one where you stand" or ".")) end
  elseif verb == "create" then
    if not IsPlayerAdmin(pid) then return say(pid, "Admins only.", true) end
    local radius = tonumber(rest)
    if not radius or radius < 3 or radius > PLOT.max_radius then return say(pid, fmt("/plot create <radius> - 3 to %d metres", PLOT.max_radius), true) end
    local x, y, z = GetPlayerPos(pid)
    local name = next_plot_name()
    local id, why = CreateArea(name, "cylinder", {x = x, y = y, radius = radius, zmin = z - 5, zmax = z + PLOT.height, label = "Plot " .. name:match("%d+"),
                                                  color = 0x60C060})
    if not id then return say(pid, "Not made: " .. tostring(why), true) end
    SetAreaProperty(name, "owner", "")
    say(pid, fmt("%s marked, %.0f m across.", name, radius * 2))
  elseif verb == "delete" then
    if not IsPlayerAdmin(pid) then return say(pid, "Admins only.", true) end
    local name = rest ~= "" and rest or plot_at(pid)
    if not name or not is_plot(name) then return say(pid, "/plot delete <plot_n> (or stand on it)", true) end
    local ok, why = DeleteArea(name)
    say(pid, ok and (name .. " deleted (what was built on it stays - /map layer " .. name .. " off hides it)") or ("Not deleted: " .. tostring(why)), not ok)
  elseif verb == "claim" then
    if plot_of(pid) then return say(pid, "You have a plot already: " .. plot_of(pid), true) end
    local name = plot_at(pid)
    if not name then return say(pid, "Stand on a plot first (/plot lists them).", true) end
    if owner_of(name) ~= "" then return say(pid, name .. " is " .. owner_of(name) .. "'s.", true) end
    SetAreaProperty(name, "owner", GetPlayerName(pid))
    say(pid, name .. " is yours - /plot build opens the editor.")
  elseif verb == "build" then
    local name = plot_of(pid)
    if not name then return say(pid, "You have no plot (/plot claim on a free one).", true) end
    -- their own objects only, on their plot's layer, at most PLOT.max_objects; OnMapEdit keeps them inside the plot
    local ok, why = SetPlayerEditor(pid, {place = true, changeOthers = false, delete = true, removeLevel = false, layers = false, areas = false,
                                          maxObjects = PLOT.max_objects, layer = name})
    if not ok then return say(pid, "The editor did not open: " .. tostring(why), true) end
    say(pid, fmt("Building on %s: at most %d objects. /plot done when you are finished.", name, PLOT.max_objects))
  elseif verb == "done" then
    SetPlayerEditor(pid, nil)
  elseif verb == "release" then
    local name = plot_of(pid)
    if not name then return say(pid, "You have no plot.", true) end
    SetPlayerEditor(pid, nil)
    local a = GetArea(name)
    local removed = 0
    for _, o in ipairs(a and GetMapObjectsNear(a.x, a.y, ((a.zmin or 0) + (a.zmax or 0)) / 2, (a.radius or 0) + PLOT.height) or {}) do
      if o.layer == name and DeleteMapObject(o.id) then removed = removed + 1 end
    end
    SetAreaProperty(name, "owner", "")
    say(pid, fmt("%s is free again (%d object(s) taken away).", name, removed))
  else
    say(pid, "/plot [create <radius> | delete [plot] | claim | build | done | release]", true)
  end
end

function OnGameModeInit()
  RegisterCommand("plot", plot_command, {help = "building plots: claim one, build on it with the editor", params = "[claim | build | done | release]"})
  local count = 0
  for _, a in ipairs(GetAreas()) do if is_plot(a.name) then count = count + 1 end end
  local info = GetMapInfo()
  Log(fmt("plots: %d plot(s) on the map%s", count, (info.folder or "") ~= "" and "" or " - this server keeps no map ([world] map in server.toml)"))
end
