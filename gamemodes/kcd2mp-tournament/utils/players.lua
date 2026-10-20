local player = {}
local data = require("data")

---@param pid number
---@return Player
function player.add(pid)
  local playerData = player.get(pid)
  if playerData then
    return playerData
  end

  playerData = {
    pid = pid,
    name = GetPlayerName(pid),
    playerUI = {
      requestingUI = "",
    },
    playerDuels = {
      elo = 100,
      lost = 0,
      won = 0,
    },
  }
  table.insert(data.players, playerData)
  return playerData
end

---@param pid number
function player.get(pid)
  for _, playerData in pairs(data.players) do
    if playerData.pid == pid then
      return playerData;
    end
  end
end

---@param pid number
function player.getRequestingUI(pid)
  for _, playerData in pairs(data.players) do
    if playerData.pid == pid then
      return playerData.playerUI.requestingUI;
    end
  end
end

---@param pid number
---@param uiName string
function player.setRequestingUI(pid, uiName)
  for _, playerData in pairs(data.players) do
    if playerData.pid == pid then
      playerData.playerUI.requestingUI = uiName;
      return 
    end
  end
end


return player;