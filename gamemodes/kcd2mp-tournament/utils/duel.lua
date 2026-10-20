local data = require("data")
local utils = require("utils.utils")

local duel = {}

---This function checks the type of the data received from the frontend.
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

---Function to check if a player is in a duel.
---@param pid number
function duel.isPlayerInDuel(pid)
  for _, duelData in pairs(data.duels) do
    if duelData.playerOne == pid or duelData.playerTwo == pid then
      return duelData
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

---A function to create an duel data.
---@param playerOne number
---@param playerTwo number
---@param numberOfRounds number
---@param time number
---@param useOwnWeapons boolean
---@param isRanked boolean
---@param weaponId string
---@param shieldId string
---@return Duel
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

---Function to remove the duel completely.
---For now, it does not stop anything.
---@param duelToRemove Duel
function duel.remove(duelToRemove)
  for i, currentDuel in ipairs(data.duels) do
    if currentDuel == duelToRemove then
      table.remove(data.duels, i)
      return true
    end
  end

  return false
end

---This function changes the status of the duel.
---@param duelData Duel
---@param newStatus string
function duel.changeStatus(duelData, newStatus)
  -- Available status are: ( TO BE EDITED )
    -- creating: user had just /duel and it's setting up the options.
    -- pending: user sent an invite to anotherp player, and the invited has to accept or decline
    -- fighting: they're fighting
  if duelData then
    duelData.status = newStatus
  end
end

---This function gets the data duel based on the playerid.
---@param pid number
---@return Duel?
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

---Function to give the player a weapond and shield.
---@param pid number
---@param weaponId string
---@param shieldId string
function duel.giveEquipment(pid, weaponId, shieldId) 

  local items = {}
  if weaponId and weaponId ~= "" and weaponId ~= "fist" then
    items[#items + 1] = {
      class = weaponId,
      amount = 1,
      health = 100,
      worn = true,
    }
  end

  if shieldId and shieldId ~= "" and shieldId ~= "fist" then
    items[#items + 1] = {
      class = shieldId,
      amount = 1,
      health = 100,
      worn = true,
    }
  end

  return SetPlayerInventory(pid, items)
end

---This function initiates the duel.
---@param duelData Duel
function duel.initiate(duelData) 
  duel.changeStatus(duelData, "fighting")
  duel.giveEquipment(duelData.playerOne, duelData.settings.weaponId, duelData.settings.shieldId)
  duel.giveEquipment(duelData.playerTwo, duelData.settings.weaponId, duelData.settings.shieldId)
end

return duel;
