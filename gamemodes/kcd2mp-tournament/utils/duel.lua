local data = require("data")
local utils = require("utils.utils")

local duel = {}

function duel.validateSettings(settings)
  if type(settings) ~= "table" then
    return false, "Invalid settings payload."
  end

  if not utils.isIntegerInRange(settings.time, 1, 3600) then
    return false, "Invalid duel time."
  end

  if not utils.isIntegerInRange(settings.numberOfRounds, 1, 3) then
    return false, "Invalid number of rounds."
  end

  if type(settings.useOwnWeapons) ~= "boolean"
      or type(settings.isRanked) ~= "boolean" then
    return false, "Invalid duel options."
  end

  local player = settings.selectedPlayer
  if type(player) ~= "table"
      or not utils.isIntegerInRange(player.pid, 0, math.huge)
      or type(player.name) ~= "string" then
    return false, "Invalid selected player."
  end

  return settings
end

function duel.isShieldItem(info)
  return info and (
    info.category == "Shield"
    or (type(info.name) == "string" and info.name:lower():find("shield", 1, true) ~= nil)
  )
end

function duel.isPlayerInDuel(pid)
  for _, duelData in pairs(data.duels) do
    if duelData.playerOne == pid or duelData.playerTwo == pid then
      return duelData
    end
  end
  return false
end

function duel.add(playerOne, playerTwo, numberOfRounds, time, useOwnWeapons, isRanked, weaponId, shieldId)
  ---@type Duel
  local newDuel = {
    playerOne = playerOne,
    playerTwo = playerTwo,
    status = "pending",
    currentRound = 0,
    playerOneRoundsWon = 0,
    playerTwoRoundsWon = 0,
    settings = {
      time = time,
      useOwnWeapons = useOwnWeapons,
      weaponId = weaponId,
      shieldId = shieldId,
      isRanked = isRanked,
      numberOfRounds = numberOfRounds,
    },
  }

  table.insert(data.duels, newDuel)
  return newDuel
end

function duel.remove(duelToRemove)
  for i, currentDuel in ipairs(data.duels) do
    if currentDuel == duelToRemove then
      table.remove(data.duels, i)
      return true
    end
  end

  return false
end


---@param pid number
---@return Duel|nil
function duel.findByPlayer(pid)
  for _, duelData in pairs(data.duels) do
    if duelData.playerOne == pid or duelData.playerTwo == pid then
      return duelData
    end
  end
  return nil
end


function duel.changeStatus(duelData, newStatus)
  -- Available status are: ( TO BE EDITED )
    -- creating: user had just /duel and it's setting up the options.
    -- pending: user sent an invite to anotherp player, and the invited has to accept or decline
    -- fighting: they're fighting
  if duelData then
    duelData.status = newStatus
  end
end

function duel.getData(pid)
  -- this to feed the ui duel
  local x, y, z = GetPlayerPos(pid)
  if x == nil or y == nil or z == nil then
    SendClientMessage(pid, COLOR_RED, "Could not find your position to look for nearby players.")
    return
  end

  local nearbyPlayers = {}
  for _, nearbyPid in ipairs(GetPlayersInRange(x, y, z, 20, GetPlayerVirtualWorld(pid))) do
    if nearbyPid ~= pid then
      nearbyPlayers[#nearbyPlayers + 1] = {
        pid = nearbyPid,
        name = GetPlayerName(nearbyPid),
        elo = 100,
      }
    end
  end

  return {    
    name = GetPlayerName(pid),
    elo = 100,
    nearbyPlayers = nearbyPlayers
  }
end

return duel;
