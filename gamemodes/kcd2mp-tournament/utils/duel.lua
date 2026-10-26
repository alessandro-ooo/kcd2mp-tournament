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

  if not utils.isIntegerInRange(settings.numberOfRounds, 1, 4) then
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
  TogglePlayerControllable(duelToRemove.playerOne, true)
  TogglePlayerControllable(duelToRemove.playerTwo, true)
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
  local ui = require("utils.ui")
  local player = require("utils.players")
  player.setRequestingUI(duelData.playerOne, ui.UI_LIST.timer)
  player.setRequestingUI(duelData.playerTwo, ui.UI_LIST.timer)
  ui.show(duelData.playerOne, false, false, false)
  ui.show(duelData.playerTwo, false, false, false)
  SetSpawnInfo(duelData.playerOne, 876.9, 799.2, 66, 325)
  SetSpawnInfo(duelData.playerTwo, 2884.6, 810, 66, 144)
  duel.beginRound(duelData)
end

---@param duelData Duel
function duel.beginRound(duelData)
  duelData.currentRound = duelData.currentRound + 1
  duelData.status = "fighting"
  SetPlayerPos(duelData.playerOne, 2876.9, 799.2, 66, 325)
  SetPlayerPos(duelData.playerTwo, 2884.6, 810, 66, 144)
  duel.giveEquipment(duelData.playerOne, duelData.settings.weaponId, duelData.settings.shieldId)
  duel.giveEquipment(duelData.playerTwo, duelData.settings.weaponId, duelData.settings.shieldId)
  HealPlayer(duelData.playerOne)
  HealPlayer(duelData.playerTwo)

    TogglePlayerControllable(duelData.playerOne, false)
  TogglePlayerControllable(duelData.playerTwo, false)

      GameText(duelData.playerOne, "Be ready! The round is about to start." , 5000)
    GameText(duelData.playerTwo, "Be ready! The round is about to start.", 5000)



  SetTimer(function() 
    GameText(duelData.playerOne, "Fight!" , 1500)
    GameText(duelData.playerTwo, "Fight!", 1500)
    TogglePlayerControllable(duelData.playerOne, true)
    TogglePlayerControllable(duelData.playerTwo, true)
    SendClientEvent(duelData.playerOne, "panel.frontend.timer.send", {
        settings = duelData.settings,
    })

    SendClientEvent(duelData.playerTwo, "panel.frontend.timer.send", {
        settings = duelData.settings,
    })
   end, 5500)
end

---@param duelData Duel
---@param winner number
---@param loser number
function duel.processRound(duelData, winner, loser)
  local ui = require("utils.ui")
  if duelData.status ~= "fighting" then
    return false
  end

  local isTie = winner == -1 and loser == -1
  local isValidResult = (winner == duelData.playerOne and loser == duelData.playerTwo)
      or (winner == duelData.playerTwo and loser == duelData.playerOne)
  if not isTie and not isValidResult then
    return false
  end

  duelData.status = "roundResolved"

  if isTie then
    TogglePlayerControllable(duelData.playerOne, false)
    TogglePlayerControllable(duelData.playerTwo, false)
    SendClientMessageToAll(COLOR_RED, "TIE")
    duelData.currentRound = duelData.currentRound - 1
    SetTimer(function()
      duel.beginRound(duelData)
    end, 5000)
    return true
  end
  local roundsWonField = winner == duelData.playerOne
      and "playerOneRoundsWon"
      or "playerTwoRoundsWon"
  duelData[roundsWonField] = duelData[roundsWonField] + 1

  if duelData.currentRound < duelData.settings.numberOfRounds then
    SendClientEvent(winner, ui.EMITS_NAMES.roundResult, {
      outcome = "roundWon",
      round = duelData.currentRound,
    })
    SendClientEvent(loser, ui.EMITS_NAMES.roundResult, {
      outcome = "roundLost",
      round = duelData.currentRound,
    })
    return true
  end

  local playerOneWon = duelData.playerOneRoundsWon
  local playerTwoWon = duelData.playerTwoRoundsWon
  if playerOneWon == playerTwoWon then
    local drawResult = {
      outcome = "matchDraw",
      round = duelData.currentRound,
    }
    SendClientEvent(duelData.playerOne, ui.EMITS_NAMES.roundResult, drawResult)
    SendClientEvent(duelData.playerTwo, ui.EMITS_NAMES.roundResult, drawResult)
  else
    local matchWinner = assert(playerOneWon > playerTwoWon and duelData.playerOne or duelData.playerTwo)
    local matchLoser = matchWinner == duelData.playerOne and duelData.playerTwo or duelData.playerOne
    

    SendClientEvent(matchLoser, ui.EMITS_NAMES.roundResult, {
      outcome = "matchLost",
      round = duelData.currentRound,
    })
    SendClientEvent(matchWinner, ui.EMITS_NAMES.roundResult, {
      outcome = "matchWon",
      round = duelData.currentRound,
    })
  end

  SetTimer(function()
    ui.hide(duelData.playerOne)
    ui.hide(duelData.playerTwo)
    duel.remove(duelData)
  end, 5000)
  return true
end

return duel;
