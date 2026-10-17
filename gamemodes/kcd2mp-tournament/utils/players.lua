local player = {}
local data = require("data")

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