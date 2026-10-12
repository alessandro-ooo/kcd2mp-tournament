local data = require("data")

local duel = {}

function duel.isPlayerInDuel(pid)
  for _, duelData in pairs(data.duels) do
    if duelData.playerOne == pid or duelData.playerTwo == pid then
      return true
    end
  end
  return false
end

function duel.add(playerOne, playerTwo)
  local newDuel = {
    playerOne = playerOne,
    playerTwo = playerTwo,
    status = "pending"
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


function duel.findByPlayer(pid)
  for _, duelData in pairs(data.duels) do
    if duelData.playerOne == pid or duelData.playerTwo == pid then
      return duelData
    end
  end
  return nil
end


function duel.changeStatus(duelData, newStatus)
  if duelData then
    duelData.status = newStatus
  end
end

return duel;